import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/catalog.dart';
import '../models/photo.dart';

const _public = '/api/public';
const _mine = '/api/emprendimientos/mio';
const _products = '$_mine/productos';

class ApiFailure implements Exception {
  const ApiFailure(
    this.message, {
    this.status,
    this.fields = const {},
    this.retryable = false,
  });

  final String message;
  final int? status;
  final Map<String, String> fields;
  final bool retryable;

  @override
  String toString() => message;
}

class Api {
  Api({http.Client? client, Uri? base})
    : _client = client ?? http.Client(),
      base =
          base ??
          Uri.parse(
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://10.0.2.2:8080',
            ),
          );

  final http.Client _client;
  final Uri base;

  Future<T> _request<T>(
    String method,
    String path,
    T Function(dynamic) decode, {
    String? token,
    Json? body,
    UploadPhoto? photo,
    bool multipart = false,
    Map<String, String>? query,
    Set<int> statuses = const {200},
  }) async {
    final uri = base.resolve(path).replace(queryParameters: query);
    final http.BaseRequest request;
    if (multipart) {
      final upload = http.MultipartRequest(method, uri);
      final data = utf8.encode(jsonEncode(body));
      if (data.length + (photo?.bytes.length ?? 0) + 2048 > 6 * 1024 * 1024) {
        throw const ApiFailure(
          'La solicitud puede pesar hasta 6 MB.',
          status: 413,
        );
      }
      upload.files.add(
        http.MultipartFile.fromBytes(
          'datos',
          data,
          contentType: MediaType('application', 'json'),
        ),
      );
      if (photo != null) {
        upload.files.add(
          http.MultipartFile.fromBytes(
            'foto',
            photo.bytes,
            filename: photo.filename,
            contentType: MediaType.parse(photo.mime),
          ),
        );
      }
      request = upload;
    } else {
      final jsonRequest = http.Request(method, uri);
      if (body != null) {
        jsonRequest.headers['Content-Type'] = 'application/json; charset=utf-8';
        jsonRequest.bodyBytes = utf8.encode(jsonEncode(body));
      }
      request = jsonRequest;
    }
    request.followRedirects = false;
    request.headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    final http.Response response;
    try {
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 18));
    } on TimeoutException {
      throw const ApiFailure(
        'El servidor tardó demasiado en responder.',
        retryable: true,
      );
    } on http.ClientException {
      throw const ApiFailure(
        'No se pudo conectar con el servidor.',
        retryable: true,
      );
    }
    final status = response.statusCode;
    Json? envelope;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Json) envelope = decoded;
    } on FormatException {
      // Error pages from a proxy can be HTML.
    }
    if (!statuses.contains(status) || envelope?['success'] != true) {
      final data = envelope?['data'];
      final message = envelope?['message'];
      final retryAfter = response.headers['retry-after'];
      throw ApiFailure(
        status == 429 && retryAfter != null
            ? 'Demasiados intentos. Espera ${retryAfter.trim()} segundos.'
            : message is String &&
                  message.isNotEmpty &&
                  envelope?['success'] == false
            ? message
            : 'El servidor devolvió una respuesta inesperada (HTTP $status).',
        status: status,
        fields: data is Json
            ? data.map((k, v) => MapEntry(k, v.toString()))
            : const {},
        retryable:
            status >= 500 || status == 408 || status == 429 || status < 400,
      );
    }
    try {
      return decode(envelope!['data']);
    } on Object {
      throw ApiFailure(
        'La respuesta del servidor está incompleta.',
        status: status,
        retryable: true,
      );
    }
  }

  Future<List<Category>> categories() => _request(
    'GET',
    '$_public/categorias',
    (data) =>
        (data as List).map((item) => Category.fromJson(item as Json)).toList(),
  );

  Future<CatalogPage<Business>> businesses(
    int page,
    String name,
    int? category,
  ) => _request(
    'GET',
    '$_public/emprendimientos',
    (data) => CatalogPage.fromJson(data as Json, Business.fromJson),
    query: {
      'page': '$page',
      if (name.isNotEmpty) 'nombre': name,
      if (category != null) 'categoriaId': '$category',
    },
  );

  Future<Business> business(int id) => _request(
    'GET',
    '$_public/emprendimientos/$id',
    (data) => Business.fromJson(data as Json),
  );

  Future<CatalogPage<Product>> publicProducts(int id, int page) => _request(
    'GET',
    '$_public/emprendimientos/$id/productos',
    (data) => CatalogPage.fromJson(data as Json, Product.fromJson),
    query: {'page': '$page'},
  );

  Future<Account> register(Json body) => _request(
    'POST',
    '/api/auth/registro',
    (data) => Account.fromJson(data as Json),
    body: body,
    statuses: {201},
  );

  Future<(String, Account)> login(Json body) =>
      _request('POST', '/api/auth/login', (data) {
        final json = data as Json;
        final token = json['token'] as String;
        if (token.isEmpty) throw const FormatException('JWT vacío');
        return (token, Account.fromJson(json['usuario'] as Json));
      }, body: body);

  Future<Account> me(String token) => _request(
    'GET',
    '/api/auth/me',
    (data) => Account.fromJson(data as Json),
    token: token,
  );

  Future<Business?> ownBusiness(String token) async {
    try {
      return await _request(
        'GET',
        _mine,
        (data) => Business.fromJson(data as Json),
        token: token,
      );
    } on ApiFailure catch (error) {
      if (error.status == 404 &&
          error.message == 'Aún no tiene un emprendimiento.') {
        return null;
      }
      rethrow;
    }
  }

  Future<Business> saveBusiness(
    String token,
    Json body,
    UploadPhoto? photo, {
    required bool editing,
  }) => _request(
    editing ? 'PUT' : 'POST',
    editing ? _mine : '/api/emprendimientos',
    (data) => Business.fromJson(data as Json),
    token: token,
    body: body,
    photo: photo,
    multipart: true,
    statuses: editing ? {200} : {201},
  );

  Future<CatalogPage<Product>> ownProducts(String token, int page) => _request(
    'GET',
    _products,
    (data) => CatalogPage.fromJson(data as Json, Product.fromJson),
    token: token,
    query: {'page': '$page'},
  );

  Future<int> createProduct(String token, Json body, UploadPhoto photo) =>
      _request(
        'POST',
        _products,
        (data) => readId(data as Json),
        token: token,
        body: body,
        photo: photo,
        multipart: true,
        statuses: {200, 201},
      );

  Future<Product> updateProduct(
    String token,
    int id,
    Json body, [
    UploadPhoto? photo,
  ]) => _request(
    'PUT',
    '$_products/$id',
    (data) => Product.fromJson(data as Json),
    token: token,
    body: body,
    photo: photo,
    multipart: true,
  );

  Uri? photoUri(String? path) {
    if (path == null) return null;
    final uri = base.resolve(path);
    if ((uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.origin != base.origin ||
        !(uri.path.startsWith('/api/imagenes/') ||
            uri.path.startsWith('/api/imagenes-privadas/'))) {
      return null;
    }
    return uri;
  }
}
