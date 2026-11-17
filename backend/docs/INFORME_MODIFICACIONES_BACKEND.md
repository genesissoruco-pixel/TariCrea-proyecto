# Informe de modificaciones del backend

**Optativa IV · 11 de noviembre de 2026**

## Usuario

| Campo JSON | Columna PostgreSQL | Validación en el registro |
|---|---|---|
| `apellidoPaterno` | `usuario.apellido_paterno VARCHAR(100)` | Obligatorio, no blanco, máximo 100 |
| `apellidoMaterno` | `usuario.apellido_materno VARCHAR(100)` | Obligatorio, no blanco, máximo 100 |
| `telefono` | `usuario.telefono VARCHAR(20)` | Obligatorio, no blanco, máximo 20 |

`RegistroRequest` valida el JSON de `POST /api/auth/registro`. `AuthServiceImpl` recorta los extremos y guarda los valores con JPA a través de `Usuario`. La obligatoriedad se aplica al registrar. El mapeo admite los `NULL` históricos y `UsuarioResponse` los devuelve como `null`.

```json
{
  "nombre": "Ana",
  "apellidoPaterno": "Rojas",
  "apellidoMaterno": "Vargas",
  "telefono": "+59170000000",
  "correo": "ana@example.com",
  "contrasena": "prueba-segura-123"
}
```

Respuesta de registro (`201`).

```json
{
  "success": true,
  "message": "Cuenta registrada.",
  "data": {
    "id": 1,
    "nombre": "Ana",
    "correo": "ana@example.com",
    "apellidoPaterno": "Rojas",
    "apellidoMaterno": "Vargas",
    "telefono": "+59170000000"
  }
}
```

`POST /api/auth/login` recibe correo y contraseña y devuelve el mismo perfil en `data.usuario`, junto a `data.token` (`200`). `GET /api/auth/me` requiere Bearer y devuelve el perfil directamente en `data` (`200`).

## Emprendimiento

| Campo JSON | Columna PostgreSQL | Validación |
|---|---|---|
| `direccionReferencia` | `emprendimiento.direccion_referencia VARCHAR(255)` | Obligatorio en el alta. Máximo 255 y debe contener texto si se envía |
| `horarioAtencion` | `emprendimiento.horario_atencion VARCHAR(255)` | Obligatorio en el alta. Máximo 255 y debe contener texto si se envía |

`POST /api/emprendimientos` y `PUT /api/emprendimientos/mio` requieren Bearer y `multipart/form-data`. Los atributos van en `datos` con tipo `application/json`. `foto` es binaria, obligatoria en el POST y opcional en el PUT. El controlador activa la validación de alta solo en el POST. El servicio aplica `strip()` y guarda los valores en la entidad. En el PUT, si un atributo se omite o llega como `null`, se conserva su valor anterior. Una cadena vacía o con solo espacios se rechaza. El resto de los campos obligatorios de la ficha sigue siendo requerido en el PUT.

Ejemplo de la parte `datos` para alta o edición.

```json
{
  "categoriaId": 1,
  "nombre": "Taller Sur",
  "descripcion": "Cerámica local",
  "direccionReferencia": "Frente a la plaza",
  "horarioAtencion": "Lun a vie, 09:00 a 17:00",
  "latitud": -21.5355,
  "longitud": -64.7296,
  "publicado": true
}
```

`EmprendimientoResponse` incluye ambos campos en el POST (`201`), el PUT y `GET /api/emprendimientos/mio` (`200`). El mismo DTO se usa en cada ficha de `data.items` de `GET /api/public/emprendimientos` y en `data` de `GET /api/public/emprendimientos/{id}`. Los dos GET públicos muestran fichas publicadas. Los atributos históricos pueden llegar como `null`.

## Archivos y verificaciones

Rutas de producción bajo [`src/main/java/com/optativa/backend/`](../src/main/java/com/optativa/backend/).

- Entidades [Usuario.java](../src/main/java/com/optativa/backend/model/Usuario.java) y [Emprendimiento.java](../src/main/java/com/optativa/backend/model/Emprendimiento.java).
- Entradas [RegistroRequest.java](../src/main/java/com/optativa/backend/dto/request/RegistroRequest.java) y [EmprendimientoRequest.java](../src/main/java/com/optativa/backend/dto/request/EmprendimientoRequest.java).
- Salidas [UsuarioResponse.java](../src/main/java/com/optativa/backend/dto/response/UsuarioResponse.java) y [EmprendimientoResponse.java](../src/main/java/com/optativa/backend/dto/response/EmprendimientoResponse.java).
- Servicios [AuthServiceImpl.java](../src/main/java/com/optativa/backend/service/impl/AuthServiceImpl.java) y [EmprendimientoServiceImpl.java](../src/main/java/com/optativa/backend/service/impl/EmprendimientoServiceImpl.java).
- Controlador [EmprendimientoController.java](../src/main/java/com/optativa/backend/controller/EmprendimientoController.java).
- Pruebas [BackendIntegrationTest.java](../src/test/java/com/optativa/backend/BackendIntegrationTest.java) y [esquema exclusivo de pruebas](../src/test/resources/schema-optativa.sql).

La implementación previa registró **compilación exitosa**. Los informes Surefire de esa ejecución, posteriores a los archivos modificados y con los casos que ejercitan los nuevos campos, registran **16 pruebas, 0 fallos, 0 errores y 0 omitidas**. Son 13 de integración con PostgreSQL aislado (`optativa_test`), 2 de huella y 1 del filtro de autenticación. Esta revisión documental consultó los informes y el código existente. La suite no se volvió a ejecutar. [Integración](../target/surefire-reports/com.optativa.backend.BackendIntegrationTest.txt) · [Huella](../target/surefire-reports/com.optativa.backend.HuellaAltaTest.txt) · [Filtro](../target/surefire-reports/com.optativa.backend.security.LimiteAutenticacionFilterTest.txt)

Según el reporte de la implementación previa, Codex no modificó `optativa`. Esta revisión documental no inspeccionó de forma independiente el estado de esa base.

Los contratos de productos, JWT, fotos y reenvío de productos se conservan. La suite cubre alta y edición de productos, JWT vencido en `/api/auth/me`, fotos válidas e inválidas y compensación ante rollback. También verifica `201` inicial, `200` con el mismo ID, `409` por datos o foto distintos y una fila y una foto en un alta concurrente. La captura, cola persistente y recuperación tras cortes reales corresponden a Flutter y quedan pendientes de demostración en Android.
