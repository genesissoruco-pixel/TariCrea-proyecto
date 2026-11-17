# Reporte de implementación del backend de Optativa IV

La aplicación usa el paquete `com.optativa.backend`, Java 21, Spring Boot 4.0.6 y el PostgreSQL local confirmado, con base **optativa**. El esquema suministrado se usó como referencia y se verificó con consultas de metadatos. La base principal tiene cuatro tablas, 33 columnas y las restricciones esperadas. No se ejecutó el SQL de creación ni se modificaron datos o tablas de esa base.

## Cambios

- Retirados **371 archivos** del proyecto, verificados como ausentes tras la limpieza. El inventario exacto se encuentra en [archivos-eliminados.txt](archivos-eliminados.txt). Incluye código y pruebas VIPRO, manuales y SQL comerciales, proyectos auxiliares y la configuración local heredada de secretos.
- Modificados `pom.xml`, `src/main/resources/application.properties`, `.gitignore` y `README.md`. El POM conserva Web MVC, JPA, PostgreSQL, Bean Validation, Spring Security, BCrypt, JWT y soporte local de WebP. Se retiraron Cloudinary, PDFBox, POI y DevTools. Se eliminó la configuración de Neon y Nvidia.
- Las entidades usan las cuatro tablas provistas, con claves `BIGINT IDENTITY`, coordenadas `NUMERIC(10,7)`, precio `NUMERIC(10,2)`, `UUID` y fechas `TIMESTAMPTZ`. Las migraciones de VIPRO no se usan. Se conserva una copia del esquema solo bajo recursos de prueba.
- Las operaciones de escritura derivan el dueño del JWT. La fila del emprendimiento serializa las altas del negocio. El UUID y la huella original distinguen reintentos idénticos de cambios. La restricción única existente conserva la integridad en PostgreSQL.
- Las fotos se guardan como PNG normalizado con nombres generados, por tipo de recurso. Se compensan nuevas escrituras al revertir la transacción y se retira la foto anterior después del commit. Si el estado del commit es indeterminado, se preservan los archivos para evitar perder una foto posiblemente confirmada.

## Endpoints implementados

El [contrato para Flutter](api-flutter.md) detalla los **14 endpoints**, sus accesos, los campos de JSON y multipart, paginación y errores. El login responde con `data.token` y `data.usuario`. Los datos de formulario viajan como JSON en la parte `datos`. La parte `foto` se requiere en las altas y es opcional en las ediciones. `publicado` se envía de forma explícita. La sincronización usa el mismo POST del catálogo propio.

## Verificación ejecutada

| Verificación | Resultado |
|---|---|
| Compilación con Java 21 y Maven Wrapper | Correcta. |
| Pruebas unitarias | 2 correctas. Huella canónica, separación de campos y cambios de imagen o estado. |
| Integración con PostgreSQL 15 aislado | 10 correctas. Registro, correo único, BCrypt, JWT inválido/vencido, cuenta inactiva, negocio único, GPS y categorías, edición propia y ajena, precio, fotos, catálogo, paginación y restricciones SQL. |
| Idempotencia | `201` inicial y `200` con el mismo ID tras reenvío. `409` con datos o foto distintos. Dos altas concurrentes dejaron una fila y un archivo. El reintento conservó el ID después de editar el producto. |
| Imágenes | JPEG, PNG y WebP reales, salida PNG por HTTP, reemplazo, rechazo de archivo inválido y rutas arbitrarias, límite de dimensiones y limpieza de archivo al revertir. |
| Empaquetado Spring Boot | Correcto. JAR ejecutable en `target/backend-1.0.0-SNAPSHOT.jar`. |
| Arranque con el PostgreSQL principal | Correcto con conexión de solo lectura a `localhost:5432/optativa`, `ddl-auto=validate` e inicialización SQL desactivada. Categorías activas: 4. Listado público: `200`. Perfil sin JWT: `401`. |

La ejecución final registró **12 pruebas, 0 fallos, 0 errores y 0 omitidas**. Los informes están en `target/surefire-reports/`. La instancia aislada usó `optativa_test` en el puerto 55440. Se detuvieron la instancia aislada y el proceso temporal de verificación HTTP.

Durante la verificación se resolvieron un error de compilación del código de pruebas y el fallo de confianza TLS del JDK al descargar dependencias del plugin de empaquetado. Para este último, Maven pudo usar los certificados de confianza de Windows con `-Djavax.net.ssl.trustStore=NONE -Djavax.net.ssl.trustStoreType=Windows-ROOT` en `MAVEN_OPTS`.

## Ejecución y alcance de la verificación

Configura `JAVA_HOME`, `DB_USERNAME`, `DB_PASSWORD` y `JWT_SECRET` como indica el [README](../README.md). La base predeterminada es `optativa`, en el puerto 5432. `UPLOADS_DIR` permite elegir la carpeta persistente de imágenes. La contraseña de PostgreSQL y la clave JWT se suministran por entorno.

La API y la persistencia se verificaron con la suite de backend y el arranque del JAR. Queda pendiente la integración en un dispositivo Flutter real, incluida la gestión local de la cola y la confirmación del GPS desde el teléfono.

## Archivos fuente y documentación añadidos


~~~text
docs/api-flutter.md
docs/archivos-eliminados.txt
docs/reporte-implementacion.md
src/main/java/com/optativa/backend/BackendApplication.java
src/main/java/com/optativa/backend/config/GlobalExceptionHandler.java
src/main/java/com/optativa/backend/config/SecurityConfig.java
src/main/java/com/optativa/backend/controller/AuthController.java
src/main/java/com/optativa/backend/controller/CatalogoController.java
src/main/java/com/optativa/backend/controller/EmprendimientoController.java
src/main/java/com/optativa/backend/controller/ImagenController.java
src/main/java/com/optativa/backend/controller/ProductoController.java
src/main/java/com/optativa/backend/dto/request/EmprendimientoRequest.java
src/main/java/com/optativa/backend/dto/request/LoginRequest.java
src/main/java/com/optativa/backend/dto/request/ProductoCrearRequest.java
src/main/java/com/optativa/backend/dto/request/ProductoEditarRequest.java
src/main/java/com/optativa/backend/dto/request/RegistroRequest.java
src/main/java/com/optativa/backend/dto/response/ApiResponse.java
src/main/java/com/optativa/backend/dto/response/EmprendimientoResponse.java
src/main/java/com/optativa/backend/dto/response/PaginaResponse.java
src/main/java/com/optativa/backend/dto/response/ProductoPublicoResponse.java
src/main/java/com/optativa/backend/dto/response/ProductoResponse.java
src/main/java/com/optativa/backend/dto/response/UsuarioResponse.java
src/main/java/com/optativa/backend/exception/ApiException.java
src/main/java/com/optativa/backend/model/Categoria.java
src/main/java/com/optativa/backend/model/Emprendimiento.java
src/main/java/com/optativa/backend/model/Producto.java
src/main/java/com/optativa/backend/model/Usuario.java
src/main/java/com/optativa/backend/repository/CategoriaRepository.java
src/main/java/com/optativa/backend/repository/EmprendimientoRepository.java
src/main/java/com/optativa/backend/repository/ProductoRepository.java
src/main/java/com/optativa/backend/repository/UsuarioRepository.java
src/main/java/com/optativa/backend/security/JwtFilter.java
src/main/java/com/optativa/backend/security/JwtService.java
src/main/java/com/optativa/backend/security/UsuarioActual.java
src/main/java/com/optativa/backend/service/AuthService.java
src/main/java/com/optativa/backend/service/CatalogoService.java
src/main/java/com/optativa/backend/service/EmprendimientoService.java
src/main/java/com/optativa/backend/service/HuellaAlta.java
src/main/java/com/optativa/backend/service/ImagenService.java
src/main/java/com/optativa/backend/service/impl/AuthServiceImpl.java
src/main/java/com/optativa/backend/service/impl/CatalogoServiceImpl.java
src/main/java/com/optativa/backend/service/impl/EmprendimientoServiceImpl.java
src/main/java/com/optativa/backend/service/impl/ProductoServiceImpl.java
src/main/java/com/optativa/backend/service/ProductoService.java
src/main/java/com/optativa/backend/validation/ContrasenaValida.java
src/main/java/com/optativa/backend/validation/ContrasenaValidator.java
src/main/java/com/optativa/backend/validation/Paginacion.java
src/test/java/com/optativa/backend/BackendIntegrationTest.java
src/test/java/com/optativa/backend/HuellaAltaTest.java
src/test/resources/application-test.properties
src/test/resources/schema-optativa.sql
~~~
