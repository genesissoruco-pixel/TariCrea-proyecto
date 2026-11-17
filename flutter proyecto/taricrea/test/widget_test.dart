import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taricrea/main.dart';
import 'package:taricrea/models/photo.dart';
import 'package:taricrea/providers/session.dart';
import 'package:taricrea/services/api.dart';
import 'package:taricrea/services/product_queue.dart';

http.Response envelope(
  Object? data, {
  int status = 200,
  String message = 'OK',
}) => http.Response(
  jsonEncode({'success': status < 400, 'message': message, 'data': data}),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

String jwt() {
  final body = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'exp':
                DateTime.now()
                    .add(const Duration(hours: 2))
                    .millisecondsSinceEpoch ~/
                1000,
          }),
        ),
      )
      .replaceAll('=', '');
  return 'header.$body.signature';
}

const account = {'id': 17, 'nombre': 'Ana', 'correo': 'ana@example.com'};
const business = {
  'id': 3,
  'nombre': 'Taller Sur',
  'categoriaId': 1,
  'categoria': 'Artesanías',
  'descripcion': 'Cerámica local',
  'telefono': '70000000',
  'direccionReferencia': 'Zona Central',
  'horarioAtencion': '09:00 a 17:00',
  'latitud': -21.5355,
  'longitud': -64.7296,
  'publicado': true,
};
const categories = [
  {'id': 1, 'nombre': 'Artesanías'},
];

class EmptyQueue extends ProductQueue {
  @override
  Future<List<QueueEntry>> entries(String scope) async => [];
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('Explora, abre una ficha y muestra todas las ubicaciones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <Uri>[];
    final api = Api(
      client: MockClient((request) async {
        requests.add(request.url);
        return switch (request.url.path) {
          '/api/public/categorias' => envelope(categories),
          '/api/public/emprendimientos'
              when request.url.queryParameters['page'] == '1' =>
            envelope({
              'items': [
                {
                  ...business,
                  'id': 4,
                  'nombre': 'Taller Norte',
                  'latitud': -21.5155,
                },
              ],
              'page': 1,
              'totalPages': 2,
            }),
          '/api/public/emprendimientos' => envelope({
            'items': [business],
            'page': 0,
            'totalPages': 2,
          }),
          '/api/public/emprendimientos/3' => envelope(business),
          '/api/public/emprendimientos/3/productos' => envelope({
            'items': [],
            'page': 0,
            'totalPages': 0,
          }),
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
      }),
    );
    final session = Session(api, ProductQueue());
    addTearDown(session.dispose);
    await tester.pumpWidget(TariCreaApp(session: session));
    await tester.pumpAndSettle();
    expect(find.text('Taller Sur'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'taller');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
      requests.any((uri) => uri.queryParameters['nombre'] == 'taller'),
      isTrue,
    );
    await tester.tap(find.text('Taller Sur'));
    await tester.pumpAndSettle();
    expect(find.text('70000000'), findsOneWidget);
    expect(find.text('Catálogo de productos'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Descubre emprendimientos'), findsOneWidget);
    await tester.tap(find.text('Ubicación'));
    await tester.pumpAndSettle();
    expect(find.text('Ubicaciones de emprendimientos'), findsOneWidget);
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      hasLength(2),
    );
    expect(find.byTooltip('Taller Sur'), findsOneWidget);
    expect(find.byTooltip('Taller Norte'), findsOneWidget);
    await tester.tap(find.byTooltip('Taller Norte'));
    await tester.pumpAndSettle();
    expect(find.text('Taller Norte'), findsOneWidget);
    expect(
      requests.any(
        (uri) =>
            uri.queryParameters['page'] == '1' &&
            !uri.queryParameters.containsKey('nombre'),
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('El primer inicio de sesión abre el alta del emprendimiento', (
    tester,
  ) async {
    final token = jwt();
    final requests = <String>[];
    final api = Api(
      client: MockClient((request) async {
        requests.add(request.url.path);
        if (request.url.path == '/api/auth/me' ||
            request.url.path == '/api/emprendimientos/mio') {
          expect(request.headers['authorization'], 'Bearer $token');
        }
        return switch (request.url.path) {
          '/api/public/categorias' => envelope(categories),
          '/api/public/emprendimientos' => envelope({
            'items': [],
            'page': 0,
            'totalPages': 0,
          }),
          '/api/auth/login' => envelope({'token': token, 'usuario': account}),
          '/api/auth/me' => envelope(account),
          '/api/emprendimientos/mio' => envelope(
            null,
            status: 404,
            message: 'Aún no tiene un emprendimiento.',
          ),
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
      }),
    );
    final session = Session(api, ProductQueue());
    addTearDown(session.dispose);
    await tester.pumpWidget(TariCreaApp(session: session));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gestionar'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'ana@example.com');
    await tester.enterText(fields.at(1), 'contraseña de prueba');
    await tester.ensureVisible(find.text('Iniciar sesión'));
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(
      requests,
      containsAllInOrder([
        '/api/auth/login',
        '/api/auth/me',
        '/api/emprendimientos/mio',
      ]),
    );
    expect(find.text('Registrar emprendimiento'), findsOneWidget);
    expect(session.hasBusiness, isFalse);
    expect(tester.takeException(), isNull);
    await session.signOut();
    await tester.pumpAndSettle();
  });

  testWidgets('Registro, panel y pantallas de productos y sincronización', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final token = jwt();
    final requests = <String>[];
    final api = Api(
      client: MockClient((request) async {
        requests.add(request.url.path);
        return switch (request.url.path) {
          '/api/public/categorias' => envelope(categories),
          '/api/public/emprendimientos' ||
          '/api/emprendimientos/mio/productos' => envelope({
            'items': [],
            'page': 0,
            'totalPages': 0,
          }),
          '/api/auth/registro' => envelope(account, status: 201),
          '/api/auth/login' => envelope({'token': token, 'usuario': account}),
          '/api/auth/me' => envelope(account),
          '/api/emprendimientos/mio' => envelope(business),
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
      }),
    );
    final session = Session(api, EmptyQueue());
    addTearDown(session.dispose);
    await tester.pumpWidget(TariCreaApp(session: session));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    const values = [
      'Ana',
      'Rojas',
      'Vargas',
      '70000000',
      'ana@example.com',
      'contraseña de prueba',
    ];
    for (var index = 0; index < values.length; index++) {
      await tester.ensureVisible(fields.at(index));
      await tester.enterText(fields.at(index), values[index]);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Crear cuenta'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Acceso del emprendedor'), findsOneWidget);
    expect(requests, contains('/api/auth/registro'));
    expect(requests, isNot(contains('/api/auth/login')));
    expect(session.account, isNull);
    await tester.enterText(fields.at(1), values.last);
    await tester.ensureVisible(find.text('Iniciar sesión'));
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('¡Bienvenido a TariCrea!'), findsOneWidget);
    await tester.tap(find.text('Mis productos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar producto'));
    await tester.pumpAndSettle();
    expect(find.text('Registrar producto'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver sincronización'));
    await tester.pumpAndSettle();
    expect(
      find.text('No hay altas guardadas en este dispositivo.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await session.signOut();
    await tester.pumpAndSettle();
  });

  test('El alta envía multipart y reusa UUID y fotografía ante confirmación idempotente', () async {
    const uuid = '10c7ec33-b4ad-4aae-a3fd-31c17e3f5730';
    final bodies = <List<int>>[];
    final api = Api(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/emprendimientos/mio/productos');
        expect(request.headers['authorization'], 'Bearer example');
        final multipart = utf8.decode(request.bodyBytes);
        expect(multipart, contains('name="datos"'));
        expect(multipart, contains('content-type: application/json'));
        expect(multipart, contains('"cliente_uuid":"$uuid"'));
        expect(multipart, contains('name="foto"; filename="foto.png"'));
        expect(multipart, contains('content-type: image/png'));
        bodies.add(request.bodyBytes);
        return envelope({'id': 51}, status: bodies.length == 1 ? 201 : 200);
      }),
    );
    final photo = UploadPhoto(Uint8List.fromList([1, 2, 3]), 'image/png');
    final data = {
      'cliente_uuid': uuid,
      'nombre': 'Taza',
      'descripcion': 'Cerámica',
      'precio': 0,
      'publicado': true,
    };
    expect(await api.createProduct('example', data, photo), 51);
    expect(await api.createProduct('example', data, photo), 51);
    expect(bodies, hasLength(2));
  });
}
