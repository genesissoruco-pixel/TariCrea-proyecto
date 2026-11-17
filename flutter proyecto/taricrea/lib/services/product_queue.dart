import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/catalog.dart';
import '../models/photo.dart';

enum QueueStatus { pending, sending, synced, error }

class QueueEntry {
  QueueEntry.fromRow(Map<String, Object?> row)
    : uuid = row['uuid'] as String,
      body = jsonDecode(row['body'] as String) as Json,
      status = QueueStatus.values.byName(row['state'] as String),
      mime = row['mime'] as String,
      error = row['error'] as String?,
      fieldErrors = row['field_errors'] == null
          ? const {}
          : (jsonDecode(row['field_errors'] as String) as Json)
                .cast<String, String>(),
      remoteId = row['remote_id'] as int?,
      canCorrect = const {400, 413, 415}.contains(row['http_status']);

  final String uuid, mime;
  final Json body;
  final QueueStatus status;
  final String? error;
  final Map<String, String> fieldErrors;
  final int? remoteId;
  final bool canCorrect;

  String get name => body['nombre'] as String;
  num get price => body['precio'] as num;
}

class ProductQueue {
  late final Future<Database> _database = openDatabase(
    'taricrea_queue.db',
    version: 1,
    onCreate: (db, _) => db.execute('''
      CREATE TABLE product_upload (
        scope TEXT NOT NULL, uuid TEXT NOT NULL, body TEXT NOT NULL,
        photo BLOB, mime TEXT NOT NULL, state TEXT NOT NULL,
        remote_id INTEGER, error TEXT, field_errors TEXT, http_status INTEGER,
        created INTEGER NOT NULL, PRIMARY KEY(scope, uuid)
      )
    '''),
    onOpen: (db) async {
      await db.update(
        'product_upload',
        {'state': QueueStatus.pending.name},
        where: 'state = ?',
        whereArgs: [QueueStatus.sending.name],
      );
    },
  );

  Future<List<QueueEntry>> entries(String scope) async {
    final db = await _database;
    final rows = await db.query(
      'product_upload',
      columns: [
        'uuid',
        'body',
        'state',
        'mime',
        'remote_id',
        'error',
        'field_errors',
        'http_status',
      ],
      where: 'scope = ?',
      whereArgs: [scope],
      orderBy: 'created ASC',
    );
    return rows.map(QueueEntry.fromRow).toList();
  }

  Future<QueueEntry> enqueue(
    String scope,
    Json body,
    UploadPhoto photo, {
    String? correction,
  }) async {
    final db = await _database;
    final uuid = const Uuid().v4();
    final row = <String, Object?>{
      'scope': scope,
      'uuid': uuid,
      'body': jsonEncode({...body, 'cliente_uuid': uuid}),
      'photo': photo.bytes,
      'mime': photo.mime,
      'state': QueueStatus.pending.name,
      'created': DateTime.now().millisecondsSinceEpoch,
    };
    await db.transaction((transaction) async {
      if (correction != null) {
        final removed = await transaction.delete(
          'product_upload',
          where: 'scope = ? AND uuid = ? AND state = ? AND http_status IN (400, 413, 415)',
          whereArgs: [scope, correction, QueueStatus.error.name],
        );
        if (removed != 1) {
          throw StateError('El alta original ya no admite correcciones.');
        }
      }
      await transaction.insert('product_upload', row);
    });
    return QueueEntry.fromRow(row);
  }

  Future<UploadPhoto> photo(String scope, QueueEntry entry) async {
    final db = await _database;
    final bytes = await db.transaction((transaction) async {
      final rows = await transaction.rawQuery(
        'SELECT length(photo) AS size FROM product_upload WHERE scope = ? AND uuid = ?',
        [scope, entry.uuid],
      );
      final size = rows.isEmpty ? null : rows.single['size'] as int?;
      if (size == null || size <= 0) {
        throw const FormatException('No se encontró la fotografía guardada.');
      }
      // Android's SQLite cursor window is smaller than the maximum upload.
      const chunkSize = 256 * 1024;
      final buffer = BytesBuilder(copy: false);
      for (var offset = 1; offset <= size; offset += chunkSize) {
        final chunk = await transaction.rawQuery(
          'SELECT substr(photo, ?, ?) AS chunk FROM product_upload WHERE scope = ? AND uuid = ?',
          [offset, chunkSize, scope, entry.uuid],
        );
        buffer.add(chunk.single['chunk'] as Uint8List);
      }
      return buffer.takeBytes();
    });
    return UploadPhoto(bytes, entry.mime);
  }

  Future<bool> begin(String scope, String uuid) async {
    final db = await _database;
    final count = await db.update(
      'product_upload',
      {'state': QueueStatus.sending.name},
      where: 'scope = ? AND uuid = ? AND state = ?',
      whereArgs: [scope, uuid, QueueStatus.pending.name],
    );
    return count == 1;
  }

  Future<void> finish(
    String scope,
    String uuid,
    QueueStatus state, {
    String? error,
    Map<String, String> fields = const {},
    int? status,
    int? remoteId,
  }) async {
    final db = await _database;
    await db.update(
      'product_upload',
      {
        'state': state.name,
        'error': error,
        'field_errors': fields.isEmpty ? null : jsonEncode(fields),
        'http_status': status,
        'remote_id': remoteId,
        if (state == QueueStatus.synced) 'photo': null,
      },
      where: 'scope = ? AND uuid = ? AND state = ?',
      whereArgs: [scope, uuid, QueueStatus.sending.name],
    );
  }
}
