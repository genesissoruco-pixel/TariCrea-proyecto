import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../services/api.dart';
import 'common.dart';

class PagedItems<T> extends StatefulWidget {
  const PagedItems({
    required this.load,
    required this.builder,
    required this.empty,
    this.onMissing,
    super.key,
  });

  final Future<CatalogPage<T>> Function(int page) load;
  final Widget Function(T item) builder;
  final String empty;
  final VoidCallback? onMissing;

  @override
  State<PagedItems<T>> createState() => _PagedItemsState<T>();
}

class _PagedItemsState<T> extends State<PagedItems<T>> {
  final items = <T>[];
  bool loading = true;
  int? next = 0;
  String? error;

  @override
  void initState() {
    super.initState();
    fetch();
  }

  Future<void> fetch() async {
    final page = next;
    if (page == null) return;
    try {
      final result = await widget.load(page);
      if (!mounted) return;
      setState(() {
        items.addAll(result.items);
        next = result.hasMore ? result.page + 1 : null;
      });
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      if (failure.status == 404 && widget.onMissing != null) {
        widget.onMissing!();
      } else {
        setState(() => error = failure.message);
      }
    } catch (problem) {
      if (mounted) setState(() => error = readableError(problem));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void more() {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    fetch();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ...items.map(widget.builder),
      if (loading)
        const Busy()
      else if (error != null)
        LoadError(error!, retry: more)
      else if (items.isEmpty)
        Panel(child: Text(widget.empty))
      else if (next != null)
        OutlinedButton(onPressed: more, child: const Text('Ver más')),
    ],
  );
}
