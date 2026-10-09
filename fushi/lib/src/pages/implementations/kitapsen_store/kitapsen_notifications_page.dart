/// kitapsen.com notifications (orders, reviews, followers, price alerts).
/// A notification about a book opens that book's store page.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_store_widgets.dart';
import 'package:fushi/src/sync/kitapsen_store.dart';
import 'package:fushi/utils.dart';

class KitapsenNotificationsPage extends ConsumerStatefulWidget {
  const KitapsenNotificationsPage({super.key});

  @override
  ConsumerState<KitapsenNotificationsPage> createState() =>
      _KitapsenNotificationsPageState();
}

class _KitapsenNotificationsPageState
    extends ConsumerState<KitapsenNotificationsPage> {
  KitapsenStore? _store;
  final List<StoreNotification> _items = <StoreNotification>[];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMore());
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_loading || (!reset && !_hasMore)) return;
    setState(() {
      _loading = true;
      _failed = false;
      if (reset) {
        _items.clear();
        _page = 0;
      }
    });
    try {
      final KitapsenStore store = _store ??= await KitapsenStore.open(
        ref.read(appProvider).database,
      );
      final ({List<StoreNotification> items, bool hasMore}) page = await store
          .notifications(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _hasMore = page.hasMore && page.items.isNotEmpty;
        _page++;
      });
    } catch (e, stack) {
      ErrorLogService.instance.log('KitapsenNotificationsPage.load', e, stack);
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(StoreNotification n) async {
    final KitapsenStore? store = _store;
    if (store != null && !n.isRead) {
      try {
        await store.markNotificationRead(n.id);
        if (!mounted) return;
        setState(() {
          final int i = _items.indexOf(n);
          if (i >= 0) {
            _items[i] = StoreNotification(
              id: n.id,
              title: n.title,
              message: n.message,
              isRead: true,
              createdAt: n.createdAt,
              bookId: n.bookId,
            );
          }
        });
      } catch (e, stack) {
        ErrorLogService.instance.log(
          'KitapsenNotificationsPage.read',
          e,
          stack,
        );
      }
    }
    final int? bookId = n.bookId;
    if (bookId != null && mounted) await openStoreBook(context, bookId);
  }

  Future<void> _markAll() async {
    final KitapsenStore? store = _store;
    if (store == null) return;
    try {
      await store.markAllNotificationsRead();
      await _loadMore(reset: true);
    } catch (e, stack) {
      ErrorLogService.instance.log(
        'KitapsenNotificationsPage.readAll',
        e,
        stack,
      );
      FushiToast.show(
        msg: t.kitapsen_book_action_failed,
        severity: ToastSeverity.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final Widget body;
    if (_items.isEmpty && _failed) {
      body = StoreLoadError(onRetry: () => unawaited(_loadMore(reset: true)));
    } else if (_items.isEmpty && _loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_items.isEmpty) {
      body = Center(
        child: FushiPlaceholderMessage(
          icon: Icons.notifications_none,
          message: t.kitapsen_notifications_empty,
        ),
      );
    } else {
      body = NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification n) {
          if (n.metrics.extentAfter < 400) unawaited(_loadMore());
          return false;
        },
        child: ListView.separated(
          padding: withBottomSafeInset(context, EdgeInsets.zero),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, int i) {
            final StoreNotification n = _items[i];
            final DateTime? at = n.createdAt?.toLocal();
            return ListTile(
              leading: Icon(
                n.isRead
                    ? Icons.notifications_none
                    : Icons.notifications_active,
                color: n.isRead ? tokens.surfaces.onVariant : null,
              ),
              title: Text(
                n.title,
                style: n.isRead
                    ? null
                    : const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                <String>[
                  if (n.message.isNotEmpty) n.message,
                  if (at != null)
                    '${at.day.toString().padLeft(2, '0')}.${at.month.toString().padLeft(2, '0')}.${at.year}',
                ].join('\n'),
              ),
              trailing: n.bookId == null
                  ? null
                  : const Icon(Icons.chevron_right),
              onTap: () => _open(n),
            );
          },
        ),
      );
    }
    return FushiPageScaffold(
      title: t.kitapsen_notifications_title,
      actions: <Widget>[
        FushiIconButton(
          key: const ValueKey<String>('kitapsen-notifications-read-all'),
          icon: Icons.done_all,
          tooltip: t.kitapsen_notifications_mark_all,
          onTap: _markAll,
        ),
      ],
      body: body,
    );
  }
}
