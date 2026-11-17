# Guía rápida de la API para Flutter

## Conexión y formato común

- **URL base.** Spring Boot usa el puerto `8080` por defecto. En el emulador Android usa `http://10.0.2.2:8080`. En un teléfono físico usa `http://<IP-de-la-PC>:8080` y conecta ambos equipos a la misma red. Si el backend usa otro `SERVER_PORT`, ajusta el puerto. Añade la ruta completa, que ya empieza con `/api`.
- **JWT.** Guarda `data.token` al iniciar sesión y envía `Authorization: Bearer <token>` en las operaciones privadas. Si la sesión vence y una ruta privada devuelve `401`, inicia sesión otra vez con la misma cuenta.
- **Respuestas JSON.** Lee `success`, `message` y `data`. Si falla la petición, muestra `message`. En errores de campos, `data` puede contener los mensajes por campo. Los ejemplos de ficha y producto muestran el contenido de `data`.
- **Paginación.** Los listados paginados aceptan `page` desde 0 y `size` de 1 a 50. Por defecto usan `page=0&size=12`. Devuelven `data` con `items`, `page`, `size`, `total` y `totalPages`.
- **Envío de fotos.** Usa `multipart/form-data`. Agrega `datos` como parte con el JSON y tipo `application/json`. Agrega `foto` como parte binaria con nombre de archivo y MIME correspondiente. Se aceptan JPG/JPEG, PNG y WebP de hasta 5 MB por foto y 6 MB por solicitud. Deja que el cliente HTTP genere el boundary. En edición, omite la parte `foto` para conservar la anterior.
- **Descarga de fotos.** Resuelve `fotoUrl` contra la URL base y usa `GET`. Las rutas `/api/imagenes/…` son públicas. Para `/api/imagenes-privadas/…`, adjunta el Bearer del dueño, también si usas `Image.network` con `headers`. La descarga exitosa devuelve un archivo `image/png`. Después de editar, usa la nueva `fotoUrl` de la respuesta.

## 1. Explorar emprendimientos

Lista negocios publicados y permite buscar por nombre o filtrar por categoría. **Sin JWT.**

| Operación | Enviar | Recibir y usar |
|---|---|---|
| `GET /api/public/emprendimientos` | Parámetros opcionales `nombre`, `categoriaId`, `page`, `size`. Sin cuerpo. | `200` con una página de fichas como la de la pantalla 3. Muestra `nombre`, `categoria` y `fotoUrl`. Usa `id` para abrir el detalle. Si `items` está vacío, muestra el estado sin resultados. |
| `GET /api/public/categorias` | Sin parámetros ni cuerpo. | `200` con `data` como lista de categorías activas. Muestra `nombre` y envía su `id` como `categoriaId`. |

Ejemplo de búsqueda: `GET /api/public/emprendimientos?nombre=taller&categoriaId=1&page=0&size=12`.

```json
{"success":true,"message":"Categorías activas.","data":[{"id":1,"nombre":"Artesanías"}]}
```

## 2. Acceso de emprendedor

Crea una cuenta, inicia sesión y recupera el perfil.

| Operación | JWT | Enviar | Recibir y usar |
|---|---|---|---|
| `POST /api/auth/registro` | No | JSON con `nombre`, `correo`, `contrasena`. | `201`, `data: {id, nombre, correo}`. Luego inicia sesión. Correo duplicado devuelve `409`. |
| `POST /api/auth/login` | No | JSON con `correo`, `contrasena`. | `200`, `data: {token, usuario: {id, nombre, correo}}`. Guarda el token. Credenciales inválidas devuelven `401`. |
| `GET /api/auth/me` | Sí | Sin cuerpo ni parámetros. | `200`, `data: {id, nombre, correo}`. Úsalo para recuperar la cuenta de la sesión. |

Envía los dos POST con `Content-Type: application/json`. La contraseña de registro requiere al menos 8 caracteres y hasta 72 bytes UTF-8. Si recibes `429`, espera los segundos de `Retry-After`.

## 3. Registrar emprendimiento

Crea o edita la ficha propia. **Todas las operaciones requieren JWT.**

| Operación | Enviar | Recibir y usar |
|---|---|---|
| `GET /api/emprendimientos/mio` | Sin cuerpo ni parámetros. | `200` con la ficha para precargar el formulario. `404` si la cuenta aún no tiene negocio. |
| `POST /api/emprendimientos` | Multipart con `datos` de la ficha y `foto` obligatoria. | `201` con la ficha creada. Una segunda ficha para la misma cuenta devuelve `409`. |
| `PUT /api/emprendimientos/mio` | Multipart con la ficha completa en `datos` y `foto` opcional. | `200` con la ficha actualizada. Refresca el formulario y la imagen con esa respuesta. |

Campos de `datos`. `telefono` es opcional. `publicado` es booleano y se envía siempre. Usa un `categoriaId` de la lista de categorías activas.

```json
{"categoriaId":1,"nombre":"Taller Sur","descripcion":"Cerámica local","telefono":"70000000","latitud":-21.5355,"longitud":-64.7296,"publicado":true}
```

Ejemplo de ficha devuelta en `data` o como elemento de un listado.

```json
{
  "id":7,"categoriaId":1,"categoria":"Artesanías","nombre":"Taller Sur",
  "descripcion":"Cerámica local","telefono":"70000000","latitud":-21.5355,
  "longitud":-64.7296,"fotoUrl":"/api/imagenes/emprendimientos/59c44b93-a548-45bb-a9aa-08d0679f8fa8.png",
  "publicado":true,"creadoEn":"2026-11-11T12:00:00Z","actualizadoEn":"2026-11-11T12:00:00Z"
}
```

## 4. Ubicación del negocio

Captura el GPS, deja que el emprendedor confirme el punto y guárdalo junto con la ficha. **JWT requerido.** Usa `POST /api/emprendimientos` en el alta o `PUT /api/emprendimientos/mio` al editar, con el multipart de la pantalla 3. Envía `latitud` entre −90 y 90 y `longitud` entre −180 y 180, como números con hasta siete decimales. El `201` o `200` devuelve la ficha con ambas coordenadas. Usa las devueltas para mostrar el punto guardado.

## 5. Detalle del emprendimiento

Muestra la ficha pública, el mapa y el catálogo del negocio seleccionado. **Sin JWT.**

| Operación | Enviar | Recibir y usar |
|---|---|---|
| `GET /api/public/emprendimientos/{id}` | `id` del negocio en la ruta. Sin cuerpo. | `200` con la ficha de la pantalla 3. Muestra nombre, categoría, descripción, teléfono si existe, foto y ubicación. `404` si el negocio está oculto o no existe. |
| `GET /api/public/emprendimientos/{id}/productos` | `id` del negocio en la ruta. `page` y `size` opcionales. Sin cuerpo. | `200` con una página de productos publicados. Cada elemento de `items` tiene `id`, `emprendimientoId`, `nombre`, `descripcion`, `precio` y `fotoUrl`. `404` si el negocio está oculto o no existe. |

## 6. Mis productos

Lista y edita productos de la cuenta, incluidos los ocultos. **JWT requerido.**

| Operación | Enviar | Recibir y usar |
|---|---|---|
| `GET /api/emprendimientos/mio/productos` | `page` y `size` opcionales. Sin cuerpo. | `200` con una página del producto de la pantalla 7. Usa `publicado` para mostrar su estado. Si la cuenta carece de negocio, devuelve `404`. |
| `PUT /api/emprendimientos/mio/productos/{id}` | `id` del producto en la ruta. Multipart con `datos` que incluye `nombre`, `descripcion`, `precio` y `publicado`. `foto` opcional. | `200` con el producto actualizado. `404` si es ajeno o no existe. |

## 7. Nuevo producto

Registra un producto en el negocio propio. Usa **`POST /api/emprendimientos/mio/productos` con JWT**. Envía multipart con `foto` obligatoria y los campos de este ejemplo en `datos`. `precio` es numérico, acepta cero y admite hasta dos decimales.

```json
{"cliente_uuid":"10c7ec33-b4ad-4aae-a3fd-31c17e3f5730","nombre":"Taza","descripcion":"Cerámica","precio":35.50,"publicado":true}
```

El alta nueva devuelve `201`. Usa `data.id` como ID del producto en el servidor.

```json
{
  "id":51,"emprendimientoId":7,"cliente_uuid":"10c7ec33-b4ad-4aae-a3fd-31c17e3f5730",
  "nombre":"Taza","descripcion":"Cerámica","precio":35.50,
  "fotoUrl":"/api/imagenes/productos/9747075b-87b9-4f0a-a11c-bbcaa2b2d296.png",
  "publicado":true,"creadoEn":"2026-11-11T12:10:00Z","actualizadoEn":"2026-11-11T12:10:00Z"
}
```

## 8. Sincronización

Envía cada producto pendiente con el mismo **`POST /api/emprendimientos/mio/productos` y JWT** de la pantalla 7. Genera `cliente_uuid` una sola vez al crear el pendiente y guarda localmente ese UUID, los datos del alta y los bytes de la foto. Ante una desconexión o pérdida de respuesta, vuelve a enviar esos mismos datos y archivo.

- **`201`**. Alta nueva. Guarda `data.id` y marca el pendiente como sincronizado.
- **`200`**. Alta ya confirmada. Devuelve el mismo `data.id` y el producto actual. Marca el pendiente como sincronizado.
- **`409` por UUID con contenido distinto**. Conserva el pendiente y muestra el conflicto para revisión.
