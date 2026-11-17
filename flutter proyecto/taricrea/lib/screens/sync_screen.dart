import 'package:flutter/material.dart';

import '../providers/session.dart';
import '../services/api.dart';
import '../services/product_queue.dart';
import '../theme/taricrea_theme.dart';
import '../widgets/common.dart';
import 'product_editor.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen(this.session, {super.key});
  final Session session;

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  late final String scope = widget.session.scope;
  late Future<List<QueueEntry>> entries;
  String? failure;

  @override
  void initState() {
    super.initState();
    entries = widget.session.queue.entries(scope);
    widget.session.addListener(update);
  }

  void update() {
    if (mounted) refresh();
  }

  Future<void> refresh() async {
    final refreshed = widget.session.queue.entries(scope);
    setState(() {
      entries = refreshed;
    });
    try {
      await refreshed;
    } catch (_) {
      /* Rendered by FutureBuilder. */
    }
  }

  Future<void> synchronize() async {
    setState(() => failure = null);
    try {
      await widget.session.sync();
      if (!mounted) return;
      final current = await widget.session.queue.entries(scope);
      if (!mounted) return;
      if (current.any((entry) => entry.status == QueueStatus.error)) {
        notice(context, 'Revisa las altas rechazadas.');
      } else if (!current.any((entry) => entry.status == QueueStatus.pending)) {
        notice(context, 'Sincronización completada.');
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => failure = error is ApiFailure
              ? error.message
              : readableError(error),
        );
      }
    }
  }

  Future<void> correct(QueueEntry entry) async {
    try {
      final photo = await widget.session.queue.photo(scope, entry);
      if (!mounted ||
          widget.session.account == null ||
          widget.session.scope != scope) {
        return;
      }
      await Navigator.push<ProductSaveResult>(
        context,
        MaterialPageRoute(
          builder: (_) => ProductEditor(
            widget.session,
            correction: entry,
            originalPhoto: photo,
          ),
        ),
      );
      if (mounted) await refresh();
    } catch (error) {
      if (mounted) notice(context, readableError(error));
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InnerScreen(
    child: FutureBuilder<List<QueueEntry>>(
      future: entries,
      builder: (context, snapshot) {
        final records = snapshot.data ?? const <QueueEntry>[];
        final count = records
            .where(
              (item) =>
                  item.status == QueueStatus.pending ||
                  item.status == QueueStatus.sending,
            )
            .length;
        final sending = widget.session.syncing;
        return Content(
          onRefresh: refresh,
          children: [
            const Heading(
              'Sincronización',
              subtitle: 'Envía los productos guardados sin internet.',
            ),
            Panel(
              tint: mint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Productos pendientes'),
                  const SizedBox(height: 5),
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (sending) const LinearProgressIndicator(),
            if (snapshot.hasError)
              LoadError('No se pudo leer la cola local.', retry: refresh)
            else if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData)
              const Busy()
            else if (records.isEmpty)
              const Panel(
                child: Text('No hay altas guardadas en este dispositivo.'),
              )
            else
              ...records.map(row),
            if (failure != null) LoadError(failure!),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: sending || count == 0 ? null : synchronize,
              icon: const Icon(Icons.sync),
              label: Text(sending ? 'Enviando…' : 'Sincronizar ahora'),
            ),
          ],
        );
      },
    ),
  );

  Widget row(QueueEntry entry) {
    final status = switch (entry.status) {
      QueueStatus.pending => 'Pendiente',
      QueueStatus.sending => 'En envío',
      QueueStatus.synced => 'Sincronizado',
      QueueStatus.error => 'Error',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(switch (entry.status) {
              QueueStatus.pending => Icons.cloud_upload_outlined,
              QueueStatus.sending => Icons.sync,
              QueueStatus.synced => Icons.cloud_done_outlined,
              QueueStatus.error => Icons.error_outline,
            }, color: ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(priceLabel(entry.price)),
                  Text(status, style: const TextStyle(color: secondary)),
                  if (entry.error != null) Text(entry.error!),
                  if (entry.canCorrect && entry.status == QueueStatus.error)
                    TextButton(
                      onPressed: widget.session.syncing
                          ? null
                          : () => correct(entry),
                      child: const Text('Corregir alta'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
