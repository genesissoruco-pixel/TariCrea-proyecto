import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/catalog.dart';
import '../models/photo.dart';
import '../services/api.dart';
import '../services/product_queue.dart';

class Session extends ChangeNotifier {
  Session(this.api, this.queue);

  final Api api;
  final ProductQueue queue;
  static const _storage = FlutterSecureStorage();
  String? _token;
  Account? _account;
  Timer? _expiry;
  bool _hasBusiness = false;
  bool syncing = false;
  bool restored = false;
  VoidCallback? onExpired;

  Account? get account => _account;
  bool get hasBusiness => _hasBusiness;
  String get scope => '${api.base.origin}:${_account!.id}';
  String get _key => 'taricrea.session.${api.base.origin}';

  Future<void> restore() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw != null) {
        final json = jsonDecode(raw) as Json;
        final token = json['token'] as String;
        if (_expiration(token).isAfter(DateTime.now())) {
          _activate(
            token,
            Account.fromJson(json['account'] as Json),
            json['hasBusiness'] == true,
          );
          try {
            await refreshBusiness();
          } on ApiFailure {
            // A validated prior session can still queue a product during an outage.
          }
        } else {
          await _storage.delete(key: _key);
        }
      }
    } catch (_) {
      // Public browsing remains available if local session storage is unavailable.
    } finally {
      restored = true;
      notifyListeners();
    }
  }

  DateTime _expiration(String token) {
    final payload = token.split('.');
    if (payload.length != 3) throw const FormatException('JWT inválido');
    final json = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(payload[1]))),
    ) as Json;
    return DateTime.fromMillisecondsSinceEpoch(
      (json['exp'] as num).toInt() * 1000,
    );
  }

  void _activate(String token, Account account, bool hasBusiness) {
    _expiry?.cancel();
    _token = token;
    _account = account;
    _hasBusiness = hasBusiness;
    _expiry = Timer(_expiration(token).difference(DateTime.now()), () {
      unawaited(_clearAndNotify(token));
    });
  }

  Future<void> _clearAndNotify(String token) async {
    if (_token != token) return;
    try {
      await signOut();
    } catch (_) {
      // The in-memory session is already cleared.
    } finally {
      onExpired?.call();
    }
  }

  Future<void> _persist(String token, Account account, bool hasBusiness) =>
      _storage.write(
        key: _key,
        value: jsonEncode({
          'token': token,
          'account': account.toJson(),
          'hasBusiness': hasBusiness,
        }),
      );

  Future<Business?> signIn(Json credentials) async {
    final (token, identity) = await api.login(credentials);
    final verified = await api.me(token);
    if (identity.id != verified.id ||
        !_expiration(token).isAfter(DateTime.now())) {
      throw const ApiFailure('El servidor no confirmó una sesión válida.');
    }
    final business = await api.ownBusiness(token);
    await _persist(token, verified, business != null);
    _activate(token, verified, business != null);
    notifyListeners();
    return business;
  }

  Future<void> signOut() async {
    _expiry?.cancel();
    _token = null;
    _account = null;
    _hasBusiness = false;
    try {
      await _storage.delete(key: _key);
    } finally {
      notifyListeners();
    }
  }

  Future<T> authorized<T>(Future<T> Function(String) operation) async {
    final token = _token;
    if (token == null) {
      throw const ApiFailure('Inicia sesión para continuar.', status: 401);
    }
    if (!_expiration(token).isAfter(DateTime.now())) {
      await _clearAndNotify(token);
      throw const ApiFailure(
        'Tu sesión venció. Vuelve a iniciar sesión.',
        status: 401,
      );
    }
    try {
      return await operation(token);
    } on ApiFailure catch (error) {
      if (error.status == 401) await _clearAndNotify(token);
      rethrow;
    }
  }

  Future<Business?> refreshBusiness() => authorized((token) async {
    final identity = await api.me(token);
    if (identity.id != account?.id) {
      throw const ApiFailure(
        'La cuenta activa cambió. Vuelve a iniciar sesión.',
        status: 401,
      );
    }
    final business = await api.ownBusiness(token);
    await _setBusiness(token, business != null);
    return business;
  });

  Future<void> _setBusiness(String token, bool value) async {
    final current = _account;
    if (token != _token || current == null) return;
    if (_hasBusiness != value) {
      await _persist(token, current, value);
      if (token != _token) return;
      _hasBusiness = value;
      notifyListeners();
    }
  }

  Future<Business> saveBusiness(
    Json body,
    UploadPhoto? photo, {
    required bool editing,
  }) => authorized((token) async {
    final business = await api.saveBusiness(
      token,
      body,
      photo,
      editing: editing,
    );
    await _setBusiness(token, true);
    return business;
  });

  Map<String, String> imageHeaders(Uri uri) =>
      uri.path.startsWith('/api/imagenes-privadas/') && _token != null
      ? {'Authorization': 'Bearer $_token'}
      : const {};

  Future<QueueEntry> addProduct(
    Json body,
    UploadPhoto photo, {
    String? correction,
  }) => authorized((_) {
    if (!hasBusiness) {
      throw const ApiFailure('Registra tu emprendimiento primero.');
    }
    return queue.enqueue(scope, body, photo, correction: correction);
  });

  Future<void> sync({String? only}) async {
    if (syncing) return;
    final owner = account;
    if (owner == null) {
      throw const ApiFailure('Inicia sesión para sincronizar.');
    }
    final ownerScope = scope;
    syncing = true;
    notifyListeners();
    try {
      await authorized((token) async {
        final verified = await api.me(token);
        if (verified.id != owner.id) {
          throw const ApiFailure(
            'Vuelve a iniciar sesión con la cuenta original.',
            status: 401,
          );
        }
        if (await api.ownBusiness(token) == null) {
          await _setBusiness(token, false);
          throw const ApiFailure(
            'La cuenta necesita un emprendimiento registrado.',
          );
        }
        for (final entry in await queue.entries(ownerScope)) {
          if (_token != token ||
              (only != null && entry.uuid != only) ||
              entry.status != QueueStatus.pending) {
            continue;
          }
          if (!await queue.begin(ownerScope, entry.uuid)) continue;
          notifyListeners();
          try {
            final photo = await queue.photo(ownerScope, entry);
            if (_token != token ||
                !_expiration(token).isAfter(DateTime.now())) {
              throw const ApiFailure(
                'Inicia sesión para sincronizar.',
                status: 401,
              );
            }
            final id = await api.createProduct(token, entry.body, photo);
            await queue.finish(
              ownerScope,
              entry.uuid,
              QueueStatus.synced,
              remoteId: id,
            );
          } on ApiFailure catch (error) {
            final pending = error.retryable || error.status == 401;
            await queue.finish(
              ownerScope,
              entry.uuid,
              pending ? QueueStatus.pending : QueueStatus.error,
              error: error.message,
              fields: error.fields,
              status: error.status,
            );
            if (pending) rethrow;
          } on FormatException catch (error) {
            await queue.finish(
              ownerScope,
              entry.uuid,
              QueueStatus.error,
              error: error.message,
            );
          } catch (_) {
            await queue.finish(
              ownerScope,
              entry.uuid,
              QueueStatus.pending,
              error: 'No se pudo actualizar el estado local. Vuelve a sincronizar.',
            );
            rethrow;
          }
          notifyListeners();
        }
      });
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }
}
