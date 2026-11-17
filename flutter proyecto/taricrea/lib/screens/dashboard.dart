import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../providers/session.dart';
import '../services/api.dart';
import '../theme/taricrea_theme.dart';
import '../widgets/common.dart';
import 'business_editor.dart';
import 'products.dart';
import 'sync_screen.dart';

class Dashboard extends StatefulWidget {
  const Dashboard(this.session, {required this.onExplore, super.key});
  final Session session;
  final VoidCallback onExplore;

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  bool loading = false;
  String? failure;

  Future<void> business() async {
    if (loading) return;
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final current = await widget.session.refreshBusiness();
      if (!mounted) return;
      await Navigator.push<Business>(
        context,
        MaterialPageRoute(
          builder: (_) => BusinessEditor(widget.session, business: current),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => failure = error is ApiFailure
              ? error.message
              : readableError(error),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBusiness = widget.session.hasBusiness;
    return Content(
      children: [
        const Heading(
          '¡Bienvenido a TariCrea!',
          subtitle: 'Administra tu emprendimiento y catálogo.',
        ),
        if (failure != null) ...[
          LoadError(failure!, retry: business),
          const SizedBox(height: 10),
        ],
        if (loading) const LinearProgressIndicator(),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < 300
                ? constraints.maxWidth
                : (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                action(
                  width,
                  hasBusiness
                      ? 'Mi emprendimiento'
                      : 'Registrar emprendimiento',
                  Icons.storefront_outlined,
                  loading ? null : business,
                ),
                action(
                  width,
                  'Mis productos',
                  Icons.inventory_2_outlined,
                  hasBusiness
                      ? () => open(ProductsScreen(widget.session))
                      : null,
                ),
                action(
                  width,
                  'Sincronización',
                  Icons.sync,
                  hasBusiness ? () => open(SyncScreen(widget.session)) : null,
                ),
                action(
                  width,
                  'Explorar',
                  Icons.explore_outlined,
                  widget.onExplore,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Panel(
          tint: mint,
          child: Text(
            hasBusiness
                ? 'Actualiza la información de tu emprendimiento y publica tus productos.'
                : 'Registra tu emprendimiento para empezar a publicar productos.',
          ),
        ),
      ],
    );
  }

  void open(Widget screen) =>
      Navigator.push<void>(context, MaterialPageRoute(builder: (_) => screen));

  Widget action(
    double width,
    String title,
    IconData icon,
    VoidCallback? onTap,
  ) => SizedBox(
    width: width,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 102),
        backgroundColor: Colors.white,
        side: const BorderSide(color: line),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      ),
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class AccountPane extends StatelessWidget {
  const AccountPane(this.session, {required this.onSignedOut, super.key});
  final Session session;
  final VoidCallback onSignedOut;

  Future<void> signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          'Las altas pendientes se conservan en este dispositivo para esta cuenta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted || session.account == null) return;
    try {
      await session.signOut();
      onSignedOut();
    } catch (error) {
      if (context.mounted) notice(context, readableError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = session.account;
    if (account == null) return const SizedBox.shrink();
    return Content(
      children: [
        const Heading('Mi cuenta'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.account_circle_outlined, size: 36),
              const SizedBox(height: 8),
              SectionLabel(account.name),
              Text(account.email),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: session.syncing ? null : () => signOut(context),
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
      ],
    );
  }
}
