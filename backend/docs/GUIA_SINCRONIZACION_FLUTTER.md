# Guía de sincronización sin internet para Flutter

**Optativa IV · Android**

El flujo offline del proyecto cubre **altas de productos** de emprendedores previamente autenticados que ya tienen una ficha registrada. El apartado 4.3 del lineamiento pide explicar dónde se guardan los datos sin conexión, cómo se reanuda el envío y cómo se integran fotos y coordenadas. Aquí la foto pertenece al producto y viaja en su alta. Las coordenadas y la foto del lugar corresponden a la ficha del emprendimiento, cuyo contrato está en la [guía rápida](Guia_Rapida_API_Flutter_Actualizada.pdf).

El backend implementa la recepción multipart, la confirmación y la idempotencia. Los ejemplos siguientes muestran cómo implementar la cola en Flutter. Su ejecución y la demostración en Android quedan a cargo de la integración móvil.

## 1. Guardar productos sin conexión

Usa `sqflite` para la cola, `path_provider` para ubicar el directorio privado persistente, `path` para componer rutas y `uuid` para generar el identificador del alta. `image_picker` puede proporcionar el archivo de cámara. Copia sus bytes desde la ruta temporal antes de confirmar el guardado al usuario. Para HTTP usa `http` y `http_parser`. Conserva el token en almacenamiento seguro, por ejemplo con `flutter_secure_storage`, y el ID de la última cuenta autenticada en el contexto local de sesión.

Abre SQLite una vez y usa una tabla con clave `(cuenta_id, cliente_uuid)`. Guarda el JSON original, el nombre relativo de la foto y su MIME, el estado, el ID remoto y el último error. Si hay compresión, hazla una sola vez antes de encolar y usa la extensión y el MIME del archivo resultante. El formulario debe validar nombre no blanco de hasta 150 caracteres, descripción no blanca, precio numérico de 0 a 99999999.99 con hasta dos decimales, un booleano explícito y foto válida. El ejemplo recibe el precio ya convertido a centavos enteros para evitar acumulación de errores de redondeo.

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

Future<Database> abrirCola() async {
  final ruta = p.join(await getDatabasesPath(), 'optativa_cola.db');
  return openDatabase(ruta, version: 1, onCreate: (db, _) async {
    await db.execute("""
      CREATE TABLE cola_producto (
        cuenta_id INTEGER NOT NULL,
        cliente_uuid TEXT NOT NULL,
        datos TEXT NOT NULL,
        foto TEXT NOT NULL,
        mime TEXT NOT NULL,
        estado TEXT NOT NULL,
        id_servidor INTEGER,
        ultimo_error TEXT,
        PRIMARY KEY (cuenta_id, cliente_uuid)
      )
    """);
  });
}

Future<Directory> directorioFotos() async {
  final base = await getApplicationSupportDirectory();
  return Directory(p.join(base.path, 'fotos_pendientes'))
      .create(recursive: true);
}

Future<String> guardarProducto(
  Database db, {
  required int cuentaId,
  required String nombre,
  required String descripcion,
  required int precioCentavos,
  required bool publicado,
  required File fotoCapturada,
}) async {
  final extension = p.extension(fotoCapturada.path).toLowerCase();
  const tipos = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.webp': 'image/webp',
  };
  final mime = tipos[extension];
  final bytes = await fotoCapturada.readAsBytes();
  if (mime == null || bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
    throw const FormatException('Selecciona una foto JPG, PNG o WebP de hasta 5 MB.');
  }

  final uuid = Uuid().v4();
  final archivo = '${cuentaId}_$uuid$extension';
  final dir = await directorioFotos();
  final destino = File(p.join(dir.path, archivo));
  try {
    await destino.writeAsBytes(bytes, flush: true);
    await db.insert('cola_producto', {
      'cuenta_id': cuentaId,
      'cliente_uuid': uuid,
      'datos': jsonEncode({
        'cliente_uuid': uuid,
        'nombre': nombre,
        'descripcion': descripcion,
        'precio': precioCentavos / 100,
        'publicado': publicado,
      }),
      'foto': archivo,
      'mime': mime,
      'estado': 'PENDIENTE',
    });
  } catch (_) {
    if (await destino.exists()) await destino.delete();
    rethrow;
  }
  return uuid;
}
```

Deshabilita «Guardar» mientras se ejecuta el alta local. Muestra el pendiente solo tras guardar la foto y la fila. Si el proceso se interrumpe entre ambos pasos, puede quedar una foto huérfana. Limpia esos archivos al iniciar, comparándolos con la tabla antes de aceptar nuevas capturas. Al reabrir, consulta por el ID de cuenta y muestra los registros en la pantalla de sincronización. No uses el correo ni el token como clave del pendiente.

## 2. Enviar cuando el servidor sea alcanzable

1. En «Sincronizar ahora», al volver a primer plano o ante un cambio de red, comprueba el servidor con un GET real y timeout. Wi-Fi o datos activos por sí solos no confirman que Spring Boot esté disponible. En Android físico, configura la IP alcanzable del servidor y el puerto. En el emulador, el host suele ser `10.0.2.2`.
2. Llama a `GET /api/auth/me` con el token actual y compara `data.id` con la cuenta de la cola. Luego llama a `GET /api/emprendimientos/mio`. Con `200` puedes continuar. Con `404`, conserva la cola y muestra que falta la ficha. Estos GET verifican los prerrequisitos del envío.
3. Lee los `PENDIENTE` de esa cuenta. Usa una sola ejecución de sincronización y reclama cada fila con un `UPDATE` condicionado al estado `PENDIENTE`. Si actualiza cero filas, otro envío ya la tomó o cambió su estado.
4. Para cada alta usa exclusivamente `POST /api/emprendimientos/mio/productos`. El Bearer va en el encabezado. El multipart incluye `datos` con `Content-Type: application/json` y `foto` con los bytes persistidos. La parte JSON solo contiene `cliente_uuid`, `nombre`, `descripcion`, `precio` y `publicado`.
5. Con `200` o `201` y un `data.id` válido, guarda el ID y cambia el estado a `SINCRONIZADO` en una misma operación SQLite. Elimina la copia de la foto únicamente si la confirmación local quedó guardada y la interfaz ya dispone de una fuente para mostrar la imagen.

El ejemplo continúa con los imports de la sección anterior. El controlador de pantalla debe capturar las excepciones de red y `RechazoApi` del chequeo previo, informar el motivo y mantener la cola.

```dart
class RechazoApi implements Exception {
  RechazoApi(this.respuesta);
  final http.Response respuesta;
}

Map<String, dynamic> datosOk(http.Response respuesta) {
  final cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes));
  if (cuerpo is! Map<String, dynamic> ||
      cuerpo['success'] != true ||
      cuerpo['data'] is! Map<String, dynamic>) {
    throw const FormatException('Confirmación de la API inválida');
  }
  return cuerpo['data'] as Map<String, dynamic>;
}

Future<void> comprobarSesionYFicha(
  Uri base, String token, int cuentaId,
) async {
  Future<http.Response> consultar(String ruta) async {
    final respuesta = await http.get(
      base.resolve(ruta),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 12));
    if (respuesta.statusCode != 200) throw RechazoApi(respuesta);
    return respuesta;
  }

  final perfil = datosOk(await consultar('/api/auth/me'));
  if (perfil['id'] != cuentaId) {
    throw StateError('La sesión no pertenece a la cuenta de la cola');
  }
  datosOk(await consultar('/api/emprendimientos/mio'));
}

Future<http.Response> enviarProducto(
  Uri base, String token, Map<String, Object?> fila,
) async {
  final dir = await directorioFotos();
  final archivo = fila['foto'] as String;
  final solicitud = http.MultipartRequest(
    'POST', base.resolve('/api/emprendimientos/mio/productos'),
  )
    ..headers['Authorization'] = 'Bearer $token'
    ..files.add(http.MultipartFile.fromString(
      'datos', fila['datos'] as String,
      contentType: MediaType('application', 'json', {'charset': 'utf-8'}),
    ));
  solicitud.files.add(await http.MultipartFile.fromPath(
    'foto', p.join(dir.path, archivo),
    filename: archivo,
    contentType: MediaType.parse(fila['mime'] as String),
  ));

  final cliente = http.Client();
  try {
    Future<http.Response> intercambio() async {
      final respuesta = await cliente.send(solicitud);
      return http.Response.fromStream(respuesta);
    }
    return await intercambio().timeout(const Duration(seconds: 30));
  } finally {
    cliente.close();
  }
}
```

Ejemplo de reclamación y actualización de la fila. Llama a esta función desde un bucle secuencial después de `comprobarSesionYFicha`. La pantalla debe detener el lote si hay un resultado transitorio o un `401`, y gestionar las excepciones de almacenamiento local sin borrar la foto ni regenerar el UUID. Usa el cuerpo de `RechazoApi.respuesta` para mostrar `message` y, si existe, el mapa de errores en `data`.

```dart
Future<void> sincronizarFila(
  Database db, Uri base, String token, int cuentaId,
  Map<String, Object?> fila,
) async {
  if (fila['cuenta_id'] != cuentaId) {
    throw StateError('Pendiente de otra cuenta');
  }

  const clave = 'cuenta_id = ? AND cliente_uuid = ?';
  final argumentos = [cuentaId, fila['cliente_uuid']];
  final tomada = await db.update(
    'cola_producto', {'estado': 'EN_ENVIO', 'ultimo_error': null},
    where: "$clave AND estado = 'PENDIENTE'", whereArgs: argumentos,
  );
  if (tomada == 0) return;

  Future<void> guardarEstado(String estado, {int? id, String? error}) async {
    await db.update(
      'cola_producto',
      {'estado': estado, 'id_servidor': id, 'ultimo_error': error},
      where: "$clave AND estado = 'EN_ENVIO'", whereArgs: argumentos,
    );
  }

  late http.Response respuesta;
  try {
    respuesta = await enviarProducto(base, token, fila);
  } on TimeoutException {
    await guardarEstado('PENDIENTE', error: 'Tiempo agotado');
    rethrow;
  } on SocketException {
    await guardarEstado('PENDIENTE', error: 'Sin conexión al servidor');
    rethrow;
  } on http.ClientException {
    await guardarEstado('PENDIENTE', error: 'Falló la comunicación');
    rethrow;
  } on FileSystemException {
    await guardarEstado('ERROR', error: 'Foto local no disponible');
    rethrow;
  }

  final codigo = respuesta.statusCode;
  if (codigo == 200 || codigo == 201) {
    int id;
    try {
      final recibido = datosOk(respuesta)['id'];
      if (recibido is! int || recibido <= 0) {
        throw const FormatException('ID de producto inválido');
      }
      id = recibido;
    } on FormatException {
      await guardarEstado('PENDIENTE', error: 'Confirmación ilegible');
      rethrow;
    }
    await guardarEstado('SINCRONIZADO', id: id);
    return;
  }

  final transitorio = codigo == 401 || codigo == 500 || codigo == 503;
  await guardarEstado(transitorio ? 'PENDIENTE' : 'ERROR', error: 'HTTP $codigo');
  throw RechazoApi(respuesta);
}
```

El cliente HTTP genera el boundary. Un timeout limita la espera local y deja incierto el resultado del servidor. Programa la recuperación con espera creciente y un máximo razonable, junto con un botón de reintento manual. Evita un bucle que reintente en cada cambio de conectividad.

## 3. Interpretar las respuestas

| Resultado | Acción en Flutter |
|---|---|
| `201 Created` | Alta nueva. Valida y guarda `data.id` y marca `SINCRONIZADO`. |
| `200 OK` en el POST | Alta ya confirmada. Guarda el mismo `data.id` y marca `SINCRONIZADO`. El cuerpo representa el producto actual, incluso si hubo ediciones posteriores. |
| `400 Bad Request` | Conserva el pendiente en `ERROR`. Muestra `message` y los errores por campo de `data` cuando existan. |
| `401 Unauthorized` | Conserva el pendiente, pausa el lote y solicita login con la misma cuenta. |
| `404 Not Found` en consulta propia o alta | Conserva la cola. Comprueba que la cuenta tenga una ficha registrada antes de reanudar. |
| `409 Conflict` | Conserva en `ERROR` y muestra el conflicto. Un caso previsto es el mismo UUID con otros datos o bytes. |
| `413 Payload Too Large` / `415 Unsupported Media Type` | Conserva en `ERROR`. Revisa tamaño y contrato multipart antes de volver a intentar. |
| `429 Too Many Requests` en login o registro | Espera los segundos de `Retry-After`. El filtro del backend aplica a esos dos POST. El alta de productos carece de ese límite en la implementación actual. |
| Error de red o timeout | Conserva en `PENDIENTE`. Reintenta con el mismo UUID, JSON y foto. |
| `503 Service Unavailable` / `500 Internal Server Error` | Conserva el pendiente. Para `503`, aplica espera progresiva. Para `500`, limita los reintentos y muestra el error si persiste. |

Si un envío tiene resultado desconocido, mantén intacta la operación original hasta conciliarla. Para un rechazo de validación inequívoco, una corrección del contenido puede guardarse como una nueva alta local, conservando la anterior hasta que el usuario decida descartarla. Ante un conflicto, revisa el producto y la operación antes de emitir otra alta.

## 4. Evitar duplicados

El UUID identifica una intención de alta. Genéralo una vez y conserva el JSON original y exactamente los mismos bytes de la fotografía. En cada intento crea un multipart nuevo desde la fila y su archivo. El backend calcula `alta_hash` con SHA-256 sobre el UUID, los campos normalizados y los bytes originales. Flutter omite `alta_hash` de la solicitud.

PostgreSQL usa una restricción única sobre `(emprendimiento_id, cliente_uuid)` y el servicio bloquea la ficha durante el alta. Para el mismo UUID y contenido equivalente, devuelve `200` con el ID existente. Si cambia el contenido, devuelve `409`. Otro UUID representa otra operación. Si se perdió la respuesta tras confirmarse la transacción, el reenvío recupera el ID existente y evita crear otra fila y otra foto.

## 5. Estados de la cola

| Estado | Cuándo se asigna | Qué mostrar y qué acción ofrecer |
|---|---|---|
| `PENDIENTE` | Captura guardada, fallo transitorio, sesión por recuperar o envío interrumpido | «Pendiente» y el último motivo si existe. Ofrece «Sincronizar ahora» cuando se cumplan los prerrequisitos. |
| `EN_ENVIO` | La ejecución de sincronización reclamó la fila | «Enviando». Deshabilita un segundo envío para esa fila. |
| `SINCRONIZADO` | Respuesta válida `200` o `201` e ID remoto guardado | «Sincronizado» y acceso al producto remoto. |
| `ERROR` | Validación, conflicto, archivo ausente u otro error que requiere intervención | Muestra el motivo y ofrece revisar el problema. Reintenta la misma operación si el contenido se conserva y el problema se resolvió. |

En el arranque en frío, antes de lanzar cualquier worker, pasa los `EN_ENVIO` abandonados a `PENDIENTE` con motivo «Resultado desconocido». Mantén UUID, JSON y foto. Haz esa recuperación una sola vez en el arranque y evita ejecutarla mientras haya un envío activo. Para este alcance, centraliza el envío en un coordinador de primer plano y usa la actualización condicional de SQLite para proteger cada fila.


Ejemplos de consulta y recuperación al abrir la app. Si el usuario resuelve un error de una fila, cambia solo su estado de `ERROR` a `PENDIENTE` mediante una actualización condicionada al ID de la cuenta, el UUID y el estado anterior.

```dart
Future<List<Map<String, Object?>>> pendientes(
  Database db, int cuentaId,
) => db.query(
  'cola_producto',
  where: "cuenta_id = ? AND estado = 'PENDIENTE'",
  whereArgs: [cuentaId],
  orderBy: 'rowid',
);

Future<int> recuperarEnviosInterrumpidos(Database db) => db.update(
  'cola_producto',
  {'estado': 'PENDIENTE', 'ultimo_error': 'Resultado desconocido'},
  where: "estado = 'EN_ENVIO'",
);
```

## 6. JWT vencido

El token tiene una vigencia configurada de dos horas. Ante `401` durante la verificación o el envío, conserva el pendiente y solicita `POST /api/auth/login` con correo y contraseña. El backend devuelve `data.token` y `data.usuario.id`. Comprueba ese ID frente a `cuenta_id` y reanuda únicamente la cola de esa cuenta tras confirmar la ficha. Si el usuario entra con otra cuenta, la cola anterior permanece separada. La API actual carece de ruta de renovación.

## 7. Ejemplo con una torta de chocolate

1. Con una sesión previa y una ficha existente, activa el modo avión. Captura la foto y completa «Torta de chocolate», «Torta casera con cobertura de chocolate», Bs 85 y el estado de publicación.
2. Flutter genera un UUID, escribe la foto persistente y guarda la fila en SQLite como `PENDIENTE`. Cierra y reabre la app. Comprueba que la torta y su foto siguen visibles.
3. Recupera la red y presiona «Sincronizar ahora». Flutter verifica cuenta y ficha, cambia la fila a `EN_ENVIO` y envía el multipart con `precio: 85`.
4. Spring Boot registra el producto, PostgreSQL asigna el ID y Flutter recibe `201`. Guarda `data.id` y cambia el estado a `SINCRONIZADO`.
5. Variante de respuesta perdida. El servidor confirma, pero Flutter experimenta un timeout. Mantén la fila pendiente. Reenvía el multipart con el UUID, el JSON y la foto originales. El servidor devuelve `200` con el mismo ID generado en el primer envío.

## 8. Evidencia para el docente

| Prueba en Android | Evidencia |
|---|---|
| Capturar sin conexión y reabrir | Capturas en modo avión, fila `PENDIENTE` y foto visible tras cerrar y volver a abrir. |
| Recuperar la red y sincronizar | Pantallas de estados, registro de `201` y `data.id`, y producto visible en «Mis productos». |
| Cortar red durante el envío | Evidencia del error y del pendiente conservado. Reanudar con el mismo UUID. |
| Perder la respuesta tras la confirmación | Interceptar y descartar la primera respuesta en una prueba controlada. Conservar el ID de la primera alta como evidencia del servidor. Mostrar `200` y el mismo ID al reenviar. |
| Verificar ausencia de duplicados | Ejecutar la consulta de solo lectura de abajo. Debe mostrar una fila para el negocio y UUID probados, con el mismo ID de las respuestas. |
| Vencer el JWT | Mostrar el `401` en el GET de comprobación o en el POST, la cola intacta y la confirmación tras iniciar sesión con la misma cuenta. |
| Integrar GPS y foto del lugar | Como prueba de la ficha en línea, mostrar la captura y confirmación del punto en Android y los valores y foto que devuelve la API. |

Consulta de solo lectura para ejecutar en `optativa` tras la demostración. Sustituye el UUID y el ID del emprendimiento por los de la prueba.

```sql
SELECT COUNT(*) AS filas, MIN(id) AS id_producto
FROM producto
WHERE emprendimiento_id = 7
  AND cliente_uuid = '10c7ec33-b4ad-4aae-a3fd-31c17e3f5730'::uuid;
```

En los registros compartidos, oculta tokens y credenciales. La [suite de integración](../src/test/java/com/optativa/backend/BackendIntegrationTest.java) demuestra el reenvío, la concurrencia, el conflicto y el rechazo de un JWT vencido en el backend. Las capturas, los cortes reales y el estado persistente del dispositivo son la evidencia de Android que aún debe producir el equipo.

**Referencias del contrato.** [Controlador de productos](../src/main/java/com/optativa/backend/controller/ProductoController.java), [DTO de alta](../src/main/java/com/optativa/backend/dto/request/ProductoCrearRequest.java), [servicio de productos](../src/main/java/com/optativa/backend/service/impl/ProductoServiceImpl.java), [cálculo de huella](../src/main/java/com/optativa/backend/service/HuellaAlta.java), [manejador de errores](../src/main/java/com/optativa/backend/config/GlobalExceptionHandler.java) y [límite de autenticación](../src/main/java/com/optativa/backend/security/LimiteAutenticacionFilter.java).
