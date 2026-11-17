# Backend de Optativa IV

API REST para registrar y promocionar emprendimientos locales con ubicación y catálogo. Usa Java 21, Spring Boot 4.0.6, Spring Security, JPA y PostgreSQL. El código está en `com.optativa.backend`.

## Iniciar en Windows

Se requiere JDK 21 y PostgreSQL local con el esquema que ya está instalado en la base **optativa**. Hibernate valida el esquema al arrancar. El backend nunca carga el SQL de pruebas ni siembra categorías.

En PowerShell, desde esta carpeta:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-21.0.11'
$env:DB_HOST = 'localhost'
$env:DB_PORT = '5432'
$env:DB_NAME = 'optativa'
$env:DB_USERNAME = 'postgres'
$env:DB_PASSWORD = Read-Host 'Contraseña de PostgreSQL' -MaskInput
$env:JWT_SECRET = Read-Host 'Clave JWT privada de al menos 32 bytes UTF-8' -MaskInput
.\mvnw.cmd spring-boot:run
```

Para reutilizar tus credenciales locales, puedes definir `DB_USERNAME` y `DB_PASSWORD` en `application-secrets.properties` en la raíz del backend y omitir esas dos variables en PowerShell. Git ignora ese archivo.

Para generar una clave aleatoria en PowerShell 7, usa `[Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48))` y guárdala en un lugar privado. Si cambia entre reinicios, los tokens anteriores dejan de ser válidos. El token de acceso dura dos horas.

La API escucha en el puerto `8080` por defecto. Puedes ajustar `SERVER_PORT`. `UPLOADS_DIR` permite configurar una carpeta persistente y escribible. Su valor por defecto es `./uploads`, relativo al directorio donde se inicia Java. Mantén una copia de esa carpeta junto con el respaldo de la BD, porque PostgreSQL solo almacena las rutas relativas.

```powershell
Invoke-RestMethod http://localhost:8080/api/public/categorias
```

Para construir un JAR, ejecuta `.\mvnw.cmd package`. Inícialo con `& "$env:JAVA_HOME\bin\java.exe" -jar target/backend-1.0.0-SNAPSHOT.jar` desde la raíz y con las mismas variables. Desde un emulador Android estándar, la dirección habitual de la PC es `10.0.2.2`. Desde un dispositivo físico, usa la IP de la PC en la red local y el puerto del backend. En despliegue utiliza HTTPS.

## Pruebas

`.\mvnw.cmd test` ejecuta las pruebas unitarias. Las pruebas de integración requieren una base de pruebas separada, llamada exactamente `optativa_test`, en una instancia local. Aplica `src/test/resources/schema-optativa.sql` **una sola vez y solo en una base de pruebas vacía**. Las pruebas vacían las tablas de datos de esa base entre casos.

Ejemplo con PostgreSQL de pruebas en el puerto 55440:

```powershell
psql -h 127.0.0.1 -p 55440 -U optativa_test -d optativa_test -v ON_ERROR_STOP=1 -f src/test/resources/schema-optativa.sql
$env:TEST_DB_URL = 'jdbc:postgresql://127.0.0.1:55440/optativa_test'
$env:TEST_DB_USERNAME = 'optativa_test'
# Si la instancia requiere contraseña, define TEST_DB_PASSWORD en el entorno.
.\mvnw.cmd test
```

La suite verifica que está en `optativa_test` antes de limpiar datos y guarda fotos de prueba en `target/test-uploads`.

- [Contrato de API para Flutter](docs/api-flutter.md)
- [Reporte de implementación y verificación](docs/reporte-implementacion.md)
- [Inventario de archivos retirados](docs/archivos-eliminados.txt)

