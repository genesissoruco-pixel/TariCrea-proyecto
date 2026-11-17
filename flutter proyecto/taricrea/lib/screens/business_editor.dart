import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../models/photo.dart';
import '../providers/session.dart';
import '../services/api.dart';
import '../theme/taricrea_theme.dart';
import '../widgets/common.dart';
import '../widgets/forms.dart';
import 'location_screen.dart';

class BusinessEditor extends StatefulWidget {
  const BusinessEditor(this.session, {this.business, super.key});
  final Session session;
  final Business? business;

  @override
  State<BusinessEditor> createState() => _BusinessEditorState();
}

class _BusinessEditorState extends State<BusinessEditor>
    with ValidatedForm<BusinessEditor> {
  late final List<FieldSpec> fields;
  late Future<List<Category>> categories;
  late Business? initial;
  int? category;
  Coordinates? coordinates;
  UploadPhoto? photo;
  late bool published;
  bool editingFromConflict = false;

  @override
  void initState() {
    super.initState();
    initial = widget.business;
    fields = [
      const FieldSpec('nombre', 'Nombre del emprendimiento', max: 150),
      const FieldSpec('descripcion', 'Descripción', lines: 3),
      const FieldSpec(
        'telefono',
        'Teléfono',
        max: 30,
        required: false,
        keyboard: TextInputType.phone,
      ),
      FieldSpec(
        'direccionReferencia',
        'Dirección de referencia',
        max: 255,
        required: initial == null,
      ),
      FieldSpec(
        'horarioAtencion',
        'Horario de atención',
        max: 255,
        required: initial == null,
      ),
    ];
    configure(fields);
    prefill(initial);
    categories = widget.session.api.categories();
  }

  void prefill(Business? item) {
    controllers['nombre']!.text = item?.name ?? '';
    controllers['descripcion']!.text = item?.description ?? '';
    controllers['telefono']!.text = item?.phone ?? '';
    controllers['direccionReferencia']!.text = item?.address ?? '';
    controllers['horarioAtencion']!.text = item?.hours ?? '';
    category = item?.categoryId;
    coordinates = item?.point;
    published = item?.published ?? true;
  }

  Future<void> choosePoint() async {
    final selected = await Navigator.push<Coordinates>(
      context,
      MaterialPageRoute(
        builder: (_) => InnerScreen(
          child: LocationScreen(pick: true, initial: coordinates),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      coordinates = selected;
      fieldErrors.remove('latitud');
      fieldErrors.remove('longitud');
    });
  }

  Future<void> save() => submit(() async {
    final point = coordinates;
    final image = photo;
    final errors = <String, String>{
      if (point == null) 'latitud': 'Selecciona y confirma un punto.',
      if (initial == null && image == null)
        'foto': 'Selecciona una fotografía del lugar.',
    };
    if (category == null || errors.isNotEmpty) {
      throw ApiFailure(
        'Completa los datos del emprendimiento.',
        fields: errors,
      );
    }
    final body = <String, dynamic>{
      for (final field in fields)
        field.key: read(field).isEmpty && field.key != 'telefono'
            ? null
            : read(field),
      'categoriaId': category,
      'publicado': published,
      ...point!.toJson(),
    };
    try {
      final saved = await widget.session.saveBusiness(
        body,
        image,
        editing: initial != null,
      );
      if (!mounted) return;
      notice(
        context,
        initial == null
            ? 'Emprendimiento registrado.'
            : 'Emprendimiento actualizado.',
      );
      Navigator.pop(context, saved);
    } on ApiFailure catch (error) {
      if (error.status != 409 || initial != null) rethrow;
      final existing = await widget.session.refreshBusiness();
      if (!mounted || existing == null) rethrow;
      setState(() {
        initial = existing;
        editingFromConflict = true;
        prefill(existing);
        photo = null;
      });
      notice(
        context,
        'La cuenta ya tiene un emprendimiento. Se abrió su ficha.',
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final editing = initial != null;
    final textFields = inputs(fields);
    final point = coordinates;
    return InnerScreen(
      child: Form(
        key: form,
        child: Content(
          children: [
            Heading(
              editing ? 'Editar emprendimiento' : 'Registrar emprendimiento',
              subtitle: 'Datos públicos de tu negocio.',
            ),
            textFields.first,
            const Text(
              'Categoría *',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            FutureBuilder<List<Category>>(
              future: categories,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return LoadError(
                    snapshot.error.toString(),
                    retry: working
                        ? null
                        : () {
                            final refreshed = widget.session.api.categories();
                            setState(() {
                              categories = refreshed;
                            });
                          },
                  );
                }
                final available = snapshot.data!;
                final selected = available.any((item) => item.id == category)
                    ? category
                    : null;
                return DropdownButtonFormField<int>(
                  key: ValueKey((selected, editingFromConflict)),
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    hintText: 'Selecciona una categoría',
                  ),
                  forceErrorText: fieldErrors['categoriaId'],
                  items: available
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: working
                      ? null
                      : (value) => setState(() {
                          category = value;
                          fieldErrors.remove('categoriaId');
                        }),
                  validator: (value) =>
                      value == null ? 'Selecciona una categoría activa.' : null,
                );
              },
            ),
            const SizedBox(height: 12),
            ...textFields.skip(1),
            PhotoField(
              label: 'Fotografía del lugar${editing ? '' : ' *'}',
              photo: photo,
              enabled: !working,
              error: fieldErrors['foto'],
              previous: initial?.photo == null
                  ? null
                  : RemotePhoto(widget.session, initial!.photo, height: 125),
              onSelected: (value) => setState(() {
                photo = value;
                fieldErrors.remove('foto');
              }),
            ),
            const Text(
              'Ubicación GPS *',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            OutlinedButton.icon(
              onPressed: working ? null : choosePoint,
              icon: const Icon(Icons.my_location),
              label: Text(
                point == null
                    ? 'Seleccionar y confirmar el punto'
                    : '${point.latitude.toStringAsFixed(7)}, ${point.longitude.toStringAsFixed(7)}',
              ),
            ),
            if (fieldErrors['latitud'] ?? fieldErrors['longitud']
                case final message?)
              Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 12),
            Panel(
              tint: mint,
              padding: EdgeInsets.zero,
              child: SwitchListTile(
                title: Text(published ? 'Publicado' : 'Oculto'),
                subtitle: const Text('Visible en el catálogo público'),
                value: published,
                onChanged: working
                    ? null
                    : (value) => setState(() {
                        published = value;
                        fieldErrors.remove('publicado');
                      }),
              ),
            ),
            const SizedBox(height: 12),
            ...feedback(),
            FilledButton(
              onPressed: working ? null : save,
              child: const Text('Guardar emprendimiento'),
            ),
          ],
        ),
      ),
    );
  }
}
