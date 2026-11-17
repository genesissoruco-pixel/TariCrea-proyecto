# API REST para Flutter

Todas las rutas están bajo el servidor configurado en Flutter. Las respuestas JSON usan `{"success":true,"message":"…","data":…}`. Los errores de validación pueden incluir un objeto con errores por campo en `data`. Las fotos se devuelven como `image/png`.

## Rutas

| Método | Ruta | Acceso | Operación |
|---|---|---|---|
| POST | `/api/auth/registro` | Público | Crear cuenta por correo. Responde 201. |
| POST | `/api/auth/login` | Público | Iniciar sesión. Responde 200 con `token` y `usuario`. |
| GET | `/api/auth/me` | Bearer | Recuperar la cuenta autenticada. |
| GET | `/api/public/categorias` | Público | Listar categorías activas. |
| GET | `/api/emprendimientos/mio` | Bearer | Recuperar mi ficha. 404 si aún no existe. |
| POST | `/api/emprendimientos` | Bearer | Crear mi ficha con foto. 201 o 409 si ya existe. |
| PUT | `/api/emprendimientos/mio` | Bearer | Actualizar mi ficha, coordenadas y, opcionalmente, foto. |
| GET | `/api/emprendimientos/mio/productos` | Bearer | Listar productos propios, incluidos los ocultos. |
| POST | `/api/emprendimientos/mio/productos` | Bearer | Crear o reintentar un alta de producto con foto y UUID. |
| PUT | `/api/emprendimientos/mio/productos/{id}` | Bearer | Actualizar un producto propio. |
| GET | `/api/public/emprendimientos` | Público | Listar publicados. Acepta `nombre` y `categoriaId`. |
| GET | `/api/public/emprendimientos/{id}` | Público | Ficha con coordenadas y foto del lugar. |
| GET | `/api/public/emprendimientos/{id}/productos` | Público | Productos publicados del negocio publicado. |
| GET | `/api/imagenes/{grupo}/{nombre}` | Público | Leer un PNG referenciado por un recurso publicado. |
| GET | `/api/imagenes-privadas/{grupo}/{nombre}` | Bearer del propietario | Leer un PNG asociado a un producto o emprendimiento propio, incluso oculto. |

En rutas privadas agrega `Authorization: Bearer <token>`. Cuando venza, vuelve a autenticar al usuario y conserva los pendientes con su UUID y foto originales.

Los tres listados paginados aceptan `page` desde 0 y `size` entre 1 y 50. Los valores predeterminados son 0 y 12. En `data` devuelven `items`, `page`, `size`, `total` y `totalPages`. La búsqueda por nombre es parcial, sin distinción de mayúsculas y con los caracteres de patrón tratados como texto.

## Autenticación

Registro con `Content-Type: application/json`:

```json
{"nombre":"Ana","correo":"ana@example.com","contrasena":"una-frase-segura"}
```

El correo se guarda en minúsculas. La contraseña requiere al menos 8 caracteres y un máximo de 72 bytes UTF-8. El login recibe `correo` y `contrasena`. Ejemplo de respuesta:

```json
{"success":true,"message":"Sesión iniciada.","data":{"token":"<JWT>","usuario":{"id":7,"nombre":"Ana","correo":"ana@example.com"}}}
```

Cada instancia permite **20 solicitudes de login y 10 de registro por IP en cada ventana de 60 segundos**. Cuentan las solicitudes exitosas y fallidas. Un `429` incluye `Retry-After` en segundos. Flutter puede volver a intentar cuando transcurra ese plazo. El servidor usa la IP de la conexión y conserva hasta 10 000 IP por operación y ventana. Si se llena el cupo, responde `429` a nuevas IP hasta la siguiente ventana.

## Emprendimiento y fotos

Envía `multipart/form-data` con una parte **datos** de tipo **application/json** y una parte **foto** binaria. No establezcas el boundary manualmente. Envía el punto solo después de que el emprendedor lo confirme en Flutter.

```json
{
  "categoriaId": 1,
  "nombre": "Taller Sur",
  "descripcion": "Cerámica local",
  "telefono": "70000000",
  "latitud": -21.5355000,
  "longitud": -64.7296000,
  "publicado": true
}
```

El teléfono es opcional. Las coordenadas admiten hasta 7 decimales, dentro de los rangos GPS. En edición, envía la ficha completa y omite `foto` si la anterior debe conservarse. Con `publicado: false`, el detalle y el catálogo de ese negocio dejan de aparecer para visitantes.

La respuesta incluye el ID, los datos guardados, `fotoUrl`, `creadoEn` y `actualizadoEn`. Resuelve `fotoUrl` contra la URL base del servidor. Si empieza con `/api/imagenes-privadas/`, adjunta el Bearer del propietario al descargarla. La ruta pública sirve fotos del negocio publicado y de sus productos publicados. Las fotos ocultas o reemplazadas devuelven `404` en la ruta pública. La ruta privada devuelve `401` sin sesión válida y `404` para una foto inexistente o ajena.

## Productos y sincronización

Alta con el mismo formato multipart:

```json
{
  "cliente_uuid": "10c7ec33-b4ad-4aae-a3fd-31c17e3f5730",
  "nombre": "Taza",
  "descripcion": "Cerámica",
  "precio": 0.00,
  "publicado": true
}
```

`precio` es un número de 0 a 99999999.99 con hasta dos decimales. `publicado` es explícito en las altas y ediciones. Para edición envía nombre, descripción, precio y publicado. Omite `cliente_uuid` y omite `foto` si no se reemplaza. Los DTO rechazan campos desconocidos, incluidos identificadores de dueño y campos administrativos.

Conserva el UUID, los datos del alta y los bytes de la fotografía en la cola de Flutter. Si recibes 201 o 200, vincula el pendiente a `data.id`. Una respuesta 200 de reintento devuelve el ID original con los datos actuales del producto, incluso si ya se editó. Un 409 indica que el UUID se usó con datos originales distintos. Reintentar una operación después de perder la respuesta conserva el UUID original.

Se aceptan JPG/JPEG, PNG y WebP, hasta 5 MB de archivo y 6 MB de solicitud, con un máximo de 8192 píxeles por dimensión y 20 millones en total. La aplicación decodifica, vuelve a codificar en PNG sin los metadatos del archivo fuente y almacena una ruta relativa bajo `emprendimientos/` o `productos/`.

## Estados de error

| Estado | Significado |
|---|---|
| 400 | Datos, coordenadas, formato de imagen o parámetros inválidos. |
| 401 | Credenciales incorrectas, token inválido o vencido, o cuenta inactiva. |
| 404 | Ficha, producto o imagen inexistente o no disponible. La edición de un producto ajeno devuelve el mismo `404` que un ID inexistente. |
| 409 | Correo duplicado, segundo emprendimiento o reutilización incompatible del UUID. |
| 413 | Límite de tamaño multipart excedido. |
| 415 | Tipo de contenido incompatible. La parte `datos` requiere `application/json`. |
| 429 | Límite de solicitudes de login o registro. Consultar `Retry-After`. |
| 503 | Problema transitorio de base de datos, decodificador o escritura local. |

