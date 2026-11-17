import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../models/photo.dart';
import '../providers/session.dart';
import '../services/api.dart';
import '../services/product_queue.dart';
import '../theme/taricrea_theme.dart';
import '../widgets/common.dart';
import '../widgets/forms.dart';

enum ProductSaveResult { saved, queued }

class ProductEditor extends StatefulWidget {
  const ProductEditor(
    this.session, {
    this.product,
    this.correction,
    this.originalPhoto,
    super.key,
  });
  final Session session;
  final Product? product;
  final QueueEntry? correction;
  final UploadPhoto? originalPhoto;

  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor>
    with ValidatedForm<ProductEditor> {
  static const fields = [
    FieldSpec('nombre', 'Nombre del producto', max: 150),
    FieldSpec('descripcion', 'Descripción', lines: 4),
    FieldSpec(
      'precio',
      'Precio en bolivianos (Bs)',
      hint: '0,00',
      keyboard: TextInputType.numberWithOptions(decimal: true),
      check: priceCheck,
    ),
  ];
  late bool published;
  UploadPhoto? photo;
  QueueEntry? rejected;

  @override
  void initState() {
    super.initState();
    final initial =
        widget.product?.toUpdate(published: widget.product!.published) ??
        widget.correction?.body ??
        const <String, dynamic>{};
    configure(fields, initial);
    published = initial['publicado'] as bool? ?? true;
    photo = widget.originalPhoto;
    rejected = widget.correction;
  }

  Future<void> save() => submit(() async {
    final product = widget.product;
    final image = photo;
    final body = <String, dynamic>{
      'nombre': read(fields[0]),
      'descripcion': read(fields[1]),
      'precio': num.parse(read(fields[2]).replaceAll(',', '.')),
      'publicado': published,
    };
    final session = widget.session;
    if (product != null) {
      await session.authorized(
        (token) => session.api.updateProduct(token, product.id, body, image),
      );
      if (mounted) {
        notice(context, 'Producto actualizado.');
        Navigator.pop(context, ProductSaveResult.saved);
      }
      return;
    }
    if (image == null) {
      throw const ApiFailure(
        'Completa los datos del producto.',
        fields: {'foto': 'Selecciona una fotografía del producto.'},
      );
    }
    final scope = session.scope;
    final entry = await session.addProduct(
      body,
      image,
      correction: rejected?.uuid,
    );
    // From this point onward, the persisted operation owns retries.
    String? failure;
    try {
      await session.sync(only: entry.uuid);
    } catch (error) {
      failure = error is ApiFailure ? error.message : readableError(error);
    }
    if (!mounted) return;
    QueueEntry? result;
    try {
      result = (await session.queue.entries(scope))
          .firstWhere((item) => item.uuid == entry.uuid);
    } catch (_) {
      // The entry was persisted. Let the queue surface local read failures.
    }
    if (!mounted) return;
    if (result?.canCorrect == true && result?.status == QueueStatus.error) {
      rejected = result;
      throw ApiFailure(
        result!.error ?? 'Revisa los datos del producto.',
        fields: result.fieldErrors,
      );
    }
    final status = result?.status ?? QueueStatus.pending;
    if (status == QueueStatus.synced) {
      notice(context, 'Producto registrado.');
      Navigator.pop(context, ProductSaveResult.saved);
    } else {
      notice(
        context,
        status == QueueStatus.error
            ? 'El servidor rechazó el alta. Revisa el motivo en Sincronización.'
            : ['Guardado pendiente de sincronización.', ?failure].join(' '),
      );
      Navigator.pop(context, ProductSaveResult.queued);
    }
  });

  @override
  Widget build(BuildContext context) => InnerScreen(
    child: Form(
      key: form,
      child: Content(
        children: [
          Heading(
            widget.product != null
                ? 'Editar producto'
                : widget.correction != null
                ? 'Corregir alta de producto'
                : 'Registrar producto',
            subtitle: 'Completa los datos que verá el cliente.',
          ),
          ...inputs(fields),
          PhotoField(
            label:
                'Fotografía del producto${widget.product == null ? ' *' : ''}',
            photo: photo,
            enabled: !working,
            error: fieldErrors['foto'],
            previous: widget.product?.photo == null
                ? null
                : RemotePhoto(
                    widget.session,
                    widget.product!.photo,
                    height: 125,
                    icon: Icons.inventory_2_outlined,
                  ),
            onSelected: (value) => setState(() {
              photo = value;
              fieldErrors.remove('foto');
            }),
          ),
          Panel(
            tint: mint,
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              title: const Text('Estado del producto'),
              subtitle: Text(
                published
                    ? 'Publicado · Visible para los visitantes'
                    : 'Oculto',
              ),
              onChanged: working
                  ? null
                  : (value) => setState(() => published = value),
              value: published,
            ),
          ),
          const SizedBox(height: 16),
          ...feedback(),
          FilledButton(
            onPressed: working ? null : save,
            child: const Text('Guardar producto'),
          ),
          if (widget.product == null) ...[
            const SizedBox(height: 12),
            const Text(
              'Sin conexión, el alta queda pendiente de sincronización.',
              style: TextStyle(color: secondary),
            ),
          ],
        ],
      ),
    ),
  );
}
