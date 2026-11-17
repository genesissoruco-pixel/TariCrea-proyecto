import 'dart:async';

import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../providers/session.dart';
import '../services/api.dart';
import '../theme/taricrea_theme.dart';
import '../widgets/common.dart';
import '../widgets/paged_items.dart';
import 'location_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen(this.session, {super.key});
  final Session session;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final search = TextEditingController();
  Timer? debounce;
  late Future<List<Category>> categories;
  String name = '';
  int? category;
  int revision = 0;

  @override
  void initState() {
    super.initState();
    categories = widget.session.api.categories();
  }

  void filter(String text, {bool immediate = false}) {
    debounce?.cancel();
    void apply() => setState(() => name = text.trim());
    if (immediate) {
      apply();
    } else {
      debounce = Timer(const Duration(milliseconds: 350), apply);
    }
  }

  Future<void> refresh() async {
    setState(() {
      categories = widget.session.api.categories();
      revision++;
    });
    try {
      await categories;
    } catch (_) {
      /* Rendered by FutureBuilder. */
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Content(
    onRefresh: refresh,
    children: [
      const Heading(
        'Descubre emprendimientos',
        subtitle: 'Conoce los negocios y productos de Tarija.',
      ),
      TextField(
        controller: search,
        textInputAction: TextInputAction.search,
        onChanged: filter,
        onSubmitted: (value) => filter(value, immediate: true),
        decoration: InputDecoration(
          hintText: 'Buscar emprendimientos por nombre',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: name.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpiar búsqueda',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    search.clear();
                    filter('', immediate: true);
                  },
                ),
        ),
      ),
      const SizedBox(height: 18),
      const SectionLabel('Categorías'),
      const SizedBox(height: 7),
      FutureBuilder<List<Category>>(
        future: categories,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator();
          }
          if (snapshot.hasError) {
            return LoadError(
              'No se pudieron cargar las categorías.',
              retry: refresh,
            );
          }
          return Wrap(
            spacing: 7,
            runSpacing: 2,
            children: [
              chip(null, 'Todas'),
              ...snapshot.data!.map((item) => chip(item.id, item.name)),
            ],
          );
        },
      ),
      const SizedBox(height: 16),
      const SectionLabel('Emprendimientos'),
      const SizedBox(height: 8),
      PagedItems<Business>(
        key: ValueKey((name, category, revision)),
        load: (page) => widget.session.api.businesses(page, name, category),
        empty: 'No encontramos emprendimientos con estos filtros.',
        builder: (business) => _BusinessCard(
          widget.session,
          business,
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => BusinessDetail(widget.session, business.id),
              ),
            );
          },
        ),
      ),
    ],
  );

  Widget chip(int? id, String label) {
    final selected = id == category;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: ink,
      backgroundColor: mint,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelStyle: TextStyle(color: selected ? Colors.white : ink),
      onSelected: (_) => setState(() => category = id),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard(this.session, this.business, {required this.onTap});
  final Session session;
  final Business business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              RemotePhoto(session, business.photo, height: 88, width: 92),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      business.category,
                      style: const TextStyle(color: secondary),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Ver emprendimiento ›',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class BusinessDetail extends StatefulWidget {
  const BusinessDetail(this.session, this.id, {super.key});
  final Session session;
  final int id;

  @override
  State<BusinessDetail> createState() => _BusinessDetailState();
}

class _BusinessDetailState extends State<BusinessDetail> {
  late Future<Business> business;
  int revision = 0;

  @override
  void initState() {
    super.initState();
    business = fetch();
  }

  Future<Business> fetch() => widget.session.api.business(widget.id);

  Future<void> refresh() async {
    setState(() {
      business = fetch();
      revision++;
    });
    try {
      await business;
    } catch (_) {
      /* Rendered by FutureBuilder. */
    }
  }

  void unavailable() {
    if (!mounted) return;
    notice(context, 'El emprendimiento ya no está disponible.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => InnerScreen(
    child: FutureBuilder<Business>(
      future: business,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: Busy());
        }
        if (snapshot.hasError) {
          final failure = snapshot.error;
          if (failure is ApiFailure && failure.status == 404) {
            WidgetsBinding.instance.addPostFrameCallback((_) => unavailable());
            return const SizedBox.shrink();
          }
          return Content(
            children: [LoadError(failure.toString(), retry: refresh)],
          );
        }
        final item = snapshot.data!;
        return Content(
          onRefresh: refresh,
          children: [
            RemotePhoto(widget.session, item.photo, height: 210),
            const SizedBox(height: 16),
            Heading(item.name, subtitle: item.category),
            Text(item.description),
            const SizedBox(height: 12),
            const Divider(color: line),
            info('Teléfono de contacto', item.phone, selectable: true),
            info('Dirección de referencia', item.address),
            info('Horario de atención', item.hours),
            OutlinedButton.icon(
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('Ver ubicación'),
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      InnerScreen(child: LocationScreen(business: item)),
                ),
              ),
            ),
            const Divider(height: 28, color: line),
            const SectionLabel('Catálogo de productos'),
            const SizedBox(height: 9),
            PagedItems<Product>(
              key: ValueKey(revision),
              empty: 'Todavía no hay productos publicados.',
              load: (page) => widget.session.api.publicProducts(item.id, page),
              onMissing: unavailable,
              builder: (product) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                  child: Row(
                    children: [
                      RemotePhoto(
                        widget.session,
                        product.photo,
                        width: 68,
                        height: 68,
                        icon: Icons.inventory_2_outlined,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              priceLabel(product.price),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(product.description),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget info(String title, String? value, {bool selectable = false}) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (selectable) SelectableText(value) else Text(value),
        ],
      ),
    );
  }
}
