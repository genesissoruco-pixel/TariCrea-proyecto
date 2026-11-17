import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/photo.dart';
import '../services/api.dart';
import '../theme/taricrea_theme.dart';
import 'common.dart';

class FieldSpec {
  const FieldSpec(
    this.key,
    this.label, {
    this.hint,
    this.max,
    this.required = true,
    this.lines = 1,
    this.keyboard,
    this.check,
    this.secret = false,
  });
  final String key, label;
  final String? hint;
  final int? max;
  final bool required, secret;
  final int lines;
  final TextInputType? keyboard;
  final String? Function(String)? check;

  String? validate(String? input) {
    final text = secret ? input ?? '' : (input ?? '').trim();
    if (required && text.trim().isEmpty) return 'Completa este campo.';
    if (max != null && text.length > max!) return 'Máximo $max caracteres.';
    return text.isEmpty ? null : check?.call(text);
  }
}

String? emailCheck(String text) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)
    ? null
    : 'Ingresa un correo válido.';

String? passwordCheck(String text) =>
    text.runes.length < 8 || utf8.encode(text).length > 72
    ? 'Usa al menos 8 caracteres y hasta 72 bytes.'
    : null;

String? priceCheck(String text) =>
    RegExp(r'^\d{1,8}([.,]\d{1,2})?$').hasMatch(text)
    ? null
    : 'Ingresa un precio de 0 a 99999999,99 con hasta 2 decimales.';

class InputField extends StatefulWidget {
  const InputField(
    this.spec, {
    required this.controller,
    this.error,
    this.onChange,
    this.enabled = true,
    super.key,
  });
  final FieldSpec spec;
  final TextEditingController controller;
  final String? error;
  final VoidCallback? onChange;
  final bool enabled;

  @override
  State<InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<InputField> {
  bool visible = false;

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${spec.label}${spec.required ? ' *' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          TextFormField(
            controller: widget.controller,
            enabled: widget.enabled,
            validator: spec.validate,
            forceErrorText: widget.error,
            onChanged: (_) => widget.onChange?.call(),
            keyboardType: spec.keyboard,
            maxLines: spec.lines,
            obscureText: spec.secret && !visible,
            autocorrect: !spec.secret,
            enableSuggestions: !spec.secret,
            decoration: InputDecoration(
              hintText: spec.hint ?? spec.label,
              suffixIcon: spec.secret
                  ? IconButton(
                      tooltip: visible
                          ? 'Ocultar contraseña'
                          : 'Mostrar contraseña',
                      icon: Icon(
                        visible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => setState(() => visible = !visible),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

mixin ValidatedForm<T extends StatefulWidget> on State<T> {
  final form = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  Map<String, String> fieldErrors = {};
  String? globalError;
  bool working = false;

  void configure(
    List<FieldSpec> fields, [
    Map<String, Object?> initial = const {},
  ]) {
    for (final field in fields) {
      controllers[field.key] = TextEditingController(
        text: initial[field.key]?.toString(),
      );
    }
  }

  String read(FieldSpec field) {
    final text = controllers[field.key]!.text;
    return field.secret ? text : text.trim();
  }

  List<Widget> inputs(List<FieldSpec> fields) => fields
      .map(
        (field) => InputField(
          field,
          controller: controllers[field.key]!,
          error: fieldErrors[field.key],
          enabled: !working,
          onChange: () => clear(field.key),
        ),
      )
      .toList();

  void clear(String key) {
    if (fieldErrors.containsKey(key)) setState(() => fieldErrors.remove(key));
  }

  Future<void> submit(Future<void> Function() action) async {
    if (working) return;
    setState(() {
      fieldErrors = {};
      globalError = null;
      working = true;
    });
    try {
      // Rebuild before validating to discard any previously displayed server errors.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !(form.currentState?.validate() ?? false)) return;
      await action();
    } on ApiFailure catch (error) {
      if (mounted) {
        setState(() {
          fieldErrors = Map.of(error.fields);
          globalError = error.message;
        });
      }
    } catch (error) {
      if (mounted) setState(() => globalError = readableError(error));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  List<Widget> feedback() => [
    if (globalError != null)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: LoadError(globalError!),
      ),
    if (working) const LinearProgressIndicator(),
  ];

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

class PhotoField extends StatefulWidget {
  const PhotoField({
    required this.label,
    required this.onSelected,
    this.photo,
    this.previous,
    this.enabled = true,
    this.error,
    super.key,
  });
  final String label;
  final UploadPhoto? photo;
  final Widget? previous;
  final bool enabled;
  final String? error;
  final ValueChanged<UploadPhoto> onSelected;

  @override
  State<PhotoField> createState() => _PhotoFieldState();
}

class _PhotoFieldState extends State<PhotoField> {
  bool picking = false;
  String? error;

  Future<void> pick() async {
    if (picking) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (!mounted || source == null) return;
    setState(() {
      picking = true;
      error = null;
    });
    try {
      final image = await ImagePicker().pickImage(source: source);
      if (image == null) return;
      if (await image.length() > UploadPhoto.maxBytes) {
        throw const FormatException('La fotografía puede pesar hasta 5 MB.');
      }
      final selected = await UploadPhoto.validate(await image.readAsBytes());
      if (mounted) widget.onSelected(selected);
    } catch (problem) {
      if (mounted) setState(() => error = readableError(problem));
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          if (photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(photo.bytes, height: 130, fit: BoxFit.cover),
            )
          else if (widget.previous != null)
            widget.previous!,
          const SizedBox(height: 4),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: mint,
              minimumSize: const Size(0, 64),
            ),
            onPressed: widget.enabled && !picking ? pick : null,
            icon: Icon(
              photo == null && widget.previous == null
                  ? Icons.add_a_photo_outlined
                  : Icons.edit_outlined,
            ),
            label: Text(
              picking
                  ? 'Cargando fotografía…'
                  : photo != null || widget.previous != null
                  ? 'Cambiar fotografía'
                  : 'Tomar o seleccionar fotografía',
            ),
          ),
          if (error ?? widget.error case final message?)
            Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}
