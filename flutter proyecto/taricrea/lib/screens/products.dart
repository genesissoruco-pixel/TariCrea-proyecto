import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../providers/session.dart';
import '../services/api.dart';
import '../theme/taricrea_theme.dart';
import '../widgets/common.dart';
import '../widgets/paged_items.dart';
import 'product_editor.dart';
import 'sync_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen(this.session, {super.key});
  final Session session;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  int revision = 0;
  final updating = <int>{};

  Future<void> refresh() async {
    if (mounted) setState(() => revision++);
  }

  Future<void> edit([Product? product]) async {
    final result = await Navigator.push<ProductSaveResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductEditor(widget.session, product: product),
      ),
    );
    if (!mounted || widget.session.account == null) return;
    if (result == ProductSaveResult.queued) {
      await openSync();
    } else if (result == ProductSaveResult.saved) {
      await refresh();
    }
  }

  Future<void> openSync() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => SyncScreen(widget.session)),
    );
    await refresh();
  }

  Future<void> toggle(Product product) async {
    if (updating.contains(product.id)) return;
    setState(() => updating.add(product.id));
    try {
      final saved = await widget.session.authorized(
        (token) => widget.session.api.updateProduct(
          token,
          product.id,
          product.toUpdate(published: !product.published),
        ),
      );
      if (!mounted) return;
      notice(
        context,
        saved.published ? 'Producto publicado.' : 'Producto oculto.',
      );
      await refresh();
    } catch (error) {
      if (mounted) {
        notice(
          context,
          error is ApiFailure ? error.message : readableError(error),
        );
      }
    } finally {
      if (mounted) setState(() => updating.remove(product.id));
    }
  }

  @override
  Widget build(BuildContext context) => InnerScreen(
    child: Content(
      onRefresh: refresh,
      children: [
        const Heading(
          'Mis productos',
          subtitle: 'Gestiona lo que publicas en el catálogo.',
        ),
        PagedItems<Product>(
          key: ValueKey(revision),
          empty: 'Todavía no tienes productos en tu catálogo.',
          load: (page) => widget.session.authorized(
            (token) => widget.session.api.ownProducts(token, page),
          ),
          builder: row,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: edit,
          icon: const Icon(Icons.add),
          label: const Text('Agregar producto'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: openSync,
          icon: const Icon(Icons.sync),
          label: const Text('Ver sincronización'),
        ),
        const SizedBox(height: 16),
        const Text(
          'Los productos ocultos se conservan en tu catálogo personal.',
          style: TextStyle(color: secondary),
        ),
      ],
    ),
  );

  Widget row(Product product) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Panel(
      child: Row(
        children: [
          RemotePhoto(
            widget.session,
            product.photo,
            width: 62,
            height: 66,
            icon: Icons.inventory_2_outlined,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(priceLabel(product.price)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      backgroundColor: product.published ? ink : mint,
                      foregroundColor: product.published ? Colors.white : ink,
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: updating.contains(product.id)
                        ? null
                        : () => toggle(product),
                    child: Text(
                      updating.contains(product.id)
                          ? 'Actualizando…'
                          : product.published
                          ? 'Publicado'
                          : 'Oculto',
                      semanticsLabel: product.published
                          ? 'Publicado. Toca para ocultar'
                          : 'Oculto. Toca para publicar',
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar ${product.name}',
            onPressed: updating.contains(product.id)
                ? null
                : () => edit(product),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    ),
  );
}
