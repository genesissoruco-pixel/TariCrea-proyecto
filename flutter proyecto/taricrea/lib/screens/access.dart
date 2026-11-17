import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../providers/session.dart';
import '../theme/taricrea_theme.dart';
import '../widgets/common.dart';
import '../widgets/forms.dart';

const _email = FieldSpec(
  'correo',
  'Correo electrónico',
  max: 254,
  hint: 'correo@ejemplo.com',
  keyboard: TextInputType.emailAddress,
  check: emailCheck,
);

class LoginScreen extends StatefulWidget {
  const LoginScreen(this.session, {required this.onLogin, super.key});
  final Session session;
  final ValueChanged<Business?> onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with ValidatedForm<LoginScreen> {
  static const fields = [
    _email,
    FieldSpec('contrasena', 'Contraseña', max: 128, secret: true),
  ];

  @override
  void initState() {
    super.initState();
    configure(fields);
  }

  Future<void> register() async {
    final email = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => RegistrationScreen(widget.session)),
    );
    if (!mounted || email == null) return;
    controllers['correo']!.text = email;
    controllers['contrasena']!.clear();
    setState(() {
      globalError = null;
      fieldErrors = {};
    });
    notice(context, 'Cuenta creada. Inicia sesión para continuar.');
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Content(
      maxWidth: 480,
      children: [
        const SizedBox(height: 28),
        const Heading(
          'Acceso del emprendedor',
          subtitle: 'Ingresa para gestionar tu negocio.',
        ),
        ...inputs(fields),
        ...feedback(),
        const SizedBox(height: 6),
        FilledButton(
          onPressed: working
              ? null
              : () => submit(() async {
                  final business = await widget.session.signIn({
                    for (final field in fields) field.key: read(field),
                  });
                  if (mounted) widget.onLogin(business);
                }),
          child: const Text('Iniciar sesión'),
        ),
        const SizedBox(height: 20),
        const Text(
          '¿Todavía no tienes cuenta?',
          textAlign: TextAlign.center,
          style: TextStyle(color: secondary),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: working ? null : register,
          child: const Text('Crear cuenta'),
        ),
      ],
    ),
  );
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen(this.session, {super.key});
  final Session session;
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with ValidatedForm<RegistrationScreen> {
  static const fields = [
    FieldSpec('nombre', 'Nombre', max: 120),
    FieldSpec('apellidoPaterno', 'Apellido paterno', max: 100),
    FieldSpec('apellidoMaterno', 'Apellido materno', max: 100),
    FieldSpec('telefono', 'Teléfono', max: 20, keyboard: TextInputType.phone),
    _email,
    FieldSpec(
      'contrasena',
      'Contraseña',
      secret: true,
      hint: 'Mínimo 8 caracteres',
      check: passwordCheck,
    ),
  ];

  @override
  void initState() {
    super.initState();
    configure(fields);
  }

  @override
  Widget build(BuildContext context) => InnerScreen(
    child: Form(
      key: form,
      child: Content(
        maxWidth: 480,
        children: [
          const Heading(
            'Crear cuenta',
            subtitle: 'Registra tu información como emprendedor.',
          ),
          ...inputs(fields),
          ...feedback(),
          FilledButton(
            onPressed: working
                ? null
                : () => submit(() async {
                    final account = await widget.session.api.register({
                      for (final field in fields) field.key: read(field),
                    });
                    if (context.mounted) Navigator.pop(context, account.email);
                  }),
            child: const Text('Crear cuenta'),
          ),
          const SizedBox(height: 18),
          const Text(
            'Los datos personales no se muestran en el catálogo público.',
            textAlign: TextAlign.center,
            style: TextStyle(color: secondary),
          ),
        ],
      ),
    ),
  );
}
