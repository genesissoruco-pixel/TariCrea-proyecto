import 'package:flutter/material.dart';

import '../providers/session.dart';
import '../theme/taricrea_theme.dart';

class Brand extends StatelessWidget {
  const Brand({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        'assets/brand/mark.png',
        width: 31,
        height: 31,
        excludeFromSemantics: true,
      ),
      const SizedBox(width: 5),
      const Text(
        'TariCrea',
        style: TextStyle(
          color: ink,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -.7,
        ),
      ),
    ],
  );
}

PreferredSizeWidget brandBar() => AppBar(
  title: const Brand(),
  centerTitle: false,
  titleSpacing: 14,
  backgroundColor: Colors.white,
  foregroundColor: ink,
  surfaceTintColor: Colors.white,
  bottom: const PreferredSize(
    preferredSize: Size.fromHeight(2),
    child: ColoredBox(
      color: accent,
      child: SizedBox(height: 2, width: double.infinity),
    ),
  ),
);

class InnerScreen extends StatelessWidget {
  const InnerScreen({required this.child, this.action, super.key});
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: brandBar(),
    body: SafeArea(top: false, child: child),
    floatingActionButton: action,
  );
}

class Content extends StatelessWidget {
  const Content({
    required this.children,
    this.onRefresh,
    this.maxWidth = 640,
    super.key,
  });
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
    return onRefresh == null
        ? list
        : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

class Heading extends StatelessWidget {
  const Heading(this.title, {this.subtitle, super.key});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: ink,
            height: 1.2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: const TextStyle(color: secondary)),
        ],
      ],
    ),
  );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
  );
}

class Panel extends StatelessWidget {
  const Panel({
    required this.child,
    this.tint = Colors.white,
    this.padding = const EdgeInsets.all(12),
    super.key,
  });
  final Widget child;
  final Color tint;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Material(
    color: tint,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: line),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class RemotePhoto extends StatelessWidget {
  const RemotePhoto(
    this.session,
    this.path, {
    required this.height,
    this.width = double.infinity,
    this.icon = Icons.storefront_outlined,
    super.key,
  });
  final Session session;
  final String? path;
  final double height, width;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final uri = session.api.photoUri(path);
    final fallback = ColoredBox(
      color: mint,
      child: Center(
        child: Icon(icon, color: ink, size: height > 100 ? 40 : 25),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: width,
        height: height,
        child: uri == null
            ? fallback
            : Image.network(
                uri.toString(),
                headers: session.imageHeaders(uri),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
                frameBuilder: (_, child, frame, immediate) =>
                    immediate || frame != null ? child : fallback,
              ),
      ),
    );
  }
}

class LoadError extends StatelessWidget {
  const LoadError(this.message, {this.retry, super.key});
  final String message;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      children: [
        Icon(Icons.info_outline, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (retry != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(onPressed: retry, child: const Text('Reintentar')),
        ],
      ],
    ),
  );
}

class Busy extends StatelessWidget {
  const Busy({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Center(child: CircularProgressIndicator()),
  );
}

void notice(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String priceLabel(num price) =>
    'Bs ${price.toStringAsFixed(2).replaceAll('.', ',')}';

String readableError(Object error) {
  if (error is FormatException) return error.message;
  return 'No se pudo completar la operación. Vuelve a intentarlo.';
}
