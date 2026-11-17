# TariCrea

Aplicación Flutter para explorar emprendimientos de Tarija y administrar su catálogo en Android. El catálogo público se puede recorrer sin cuenta. La gestión requiere iniciar sesión y registrar un emprendimiento en el primer acceso.

## Ejecutar en Android

1. Inicia Spring Boot con PostgreSQL y comprueba que responda a `GET /api/public/categorias` en el puerto configurado. Si el registro rechaza `apellidoPaterno`, recompila el JAR desde el código fuente actual del backend.
2. Abre este proyecto en Android Studio, selecciona un dispositivo Android y ejecuta `lib/main.dart`.
3. El emulador usa `http://10.0.2.2:8080` por defecto. En un teléfono de la misma red, indica la IP del equipo donde corre Spring Boot. En Android Studio, agrega el argumento `--dart-define=API_BASE_URL=http://192.168.1.50:8080` a la configuración de ejecución, usando tu IP real.

Desde la terminal:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Si Windows informa que Flutter requiere enlaces simbólicos al instalar los plugins, habilita el modo de desarrollador de Windows y vuelve a ejecutar `flutter pub get`.

HTTP está habilitado en las variantes Android de depuración y perfil para desarrollo local. Para una compilación de distribución, indica la URL HTTPS del servidor:

```powershell
flutter build apk --dart-define=API_BASE_URL=https://api.ejemplo.com
```

## Pruebas

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Para probar la recuperación sin conexión en Android, inicia sesión con un negocio ya registrado. Pon el dispositivo en modo avión, agrega un producto con una fotografía y cierra la aplicación. Al reabrirla, vuelve a la misma cuenta si la sesión venció, comprueba que el alta siga pendiente en **Gestionar → Sincronización**, restablece la conexión y pulsa **Sincronizar ahora**. Comprueba que el catálogo propio tenga un único producto.

La cola de altas se guarda en la base SQLite privada de Android. Conserva la cuenta, la solicitud y los bytes originales hasta confirmar el ID remoto. La sesión se guarda mediante el almacenamiento seguro de la plataforma. El mapa usa los mosaicos de OpenStreetMap. La captura GPS requiere permiso de ubicación en Android.

## Código

- `lib/screens` contiene el catálogo público, acceso, gestión, ubicación y sincronización.
- `lib/services` concentra el cliente REST y la cola local.
- `lib/providers/session.dart` verifica la sesión y coordina los envíos.
- `assets/brand` contiene el símbolo del logo suministrado.

