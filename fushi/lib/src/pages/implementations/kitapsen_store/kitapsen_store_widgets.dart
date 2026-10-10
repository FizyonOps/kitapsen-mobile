/// Building blocks of the Kitapsen store screens, styled after kitapsen.com
/// (gray card tiles, bold section headers, crimson accents), plus the shared
/// navigation helpers.
library;

import 'package:flutter/material.dart';

import 'package:fushi/src/models/kitapsen_edition.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_book_page.dart';
import 'package:fushi/src/settings/settings_detail_page.dart';
import 'package:fushi/src/settings/settings_schema_services.dart'
    show buildServicesDestination;
import 'package:fushi/src/sync/kitapsen_store.dart';
import 'package:fushi/src/utils/net/app_http_image.dart';
import 'package:fushi/utils.dart';

/// Cover aspect ratio of store cards (2:3, the usual book jacket).
const double kStoreCoverAspect = 2 / 3;

/// The website's palette (Tailwind gray / green / blue scales plus the brand
/// crimson), with dark-mode stand-ins taken from the app's color scheme.
class StoreColors {
  const StoreColors._({
    required this.accent,
    required this.onAccent,
    required this.ink,
    required this.body,
    required this.muted,
    required this.tile,
    required this.border,
    required this.hero,
    required this.navy,
    required this.green,
    required this.greenText,
    required this.blueText,
    required this.avatar,
  });

  factory StoreColors.of(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    if (theme.brightness == Brightness.dark) {
      return StoreColors._(
        accent: kKitapsenBrandColorDark,
        onAccent: cs.onPrimary,
        ink: cs.onSurface,
        body: cs.onSurfaceVariant,
        muted: cs.onSurfaceVariant,
        tile: cs.surfaceContainerHigh,
        border: cs.outlineVariant,
        hero: cs.surfaceContainer,
        navy: const Color(0xFF0B1A2E),
        green: const Color(0xFF16A34A),
        greenText: const Color(0xFF4ADE80),
        blueText: const Color(0xFF60A5FA),
        avatar: cs.surfaceContainerHighest,
      );
    }
    return const StoreColors._(
      accent: kKitapsenBrandColor,
      onAccent: Colors.white,
      ink: Color(0xFF111827),
      body: Color(0xFF4B5563),
      muted: Color(0xFF6B7280),
      tile: Color(0xFFF3F4F6),
      border: Color(0xFFE5E7EB),
      hero: Color(0xFFEEF2F6),
      navy: Color(0xFF0B1A2E),
      green: Color(0xFF16A34A),
      greenText: Color(0xFF15803D),
      blueText: Color(0xFF1D4ED8),
      avatar: Color(0xFFFDF2F3),
    );
  }

  final Color accent;

  /// Text on an [accent] fill (white on crimson; dark on the light dark-mode
  /// pink).
  final Color onAccent;
  final Color ink;
  final Color body;
  final Color muted;
  final Color tile;
  final Color border;
  final Color hero;
  final Color navy;
  final Color green;
  final Color greenText;
  final Color blueText;
  final Color avatar;
}

/// The website's serif display face (Georgia), for hero and author titles.
const String kStoreSerif = 'serif';
const List<String> kStoreSerifFallback = <String>['Georgia', 'Noto Serif'];

Future<void> openStoreBook(BuildContext context, int bookId) =>
    Navigator.of(context).push(
      adaptivePageRoute<void>(
        context: context,
        builder: (_) => KitapsenBookPage(bookId: bookId),
      ),
    );

/// Settings › Kitapsen account, the one place sign-in lives.
Future<void> openKitapsenSignIn(BuildContext context) =>
    Navigator.of(context).push(
      adaptivePageRoute<void>(
        context: context,
        builder: (_) =>
            SettingsDetailPage(destination: buildServicesDestination()),
      ),
    );

class StoreCover extends StatelessWidget {
  const StoreCover({
    super.key,
    required this.url,
    this.borderRadius = 4,
    this.shadow = false,
  });

  final String? url;
  final double borderRadius;

  /// The lifted look of the website's covers.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final StoreColors c = StoreColors.of(context);
    final Widget placeholder = ColoredBox(
      color: c.tile,
      child: Center(child: Icon(Icons.menu_book_outlined, color: c.muted)),
    );
    final String? src = url;
    final Widget image = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: AspectRatio(
        aspectRatio: kStoreCoverAspect,
        child: src == null
            ? placeholder
            : Image(
                image: AppCachedHttpImage(src),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => placeholder,
                frameBuilder: (_, Widget child, int? frame, bool sync) =>
                    sync || frame != null ? child : placeholder,
              ),
      ),
    );
    if (!shadow) return image;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: image,
    );
  }
}

/// Corner tag on a card tile ("Ücretsiz", "Yeni").
class StoreBadge {
  const StoreBadge(this.label, this.color);
  final String label;
  final Color color;
}

class StoreBookCard extends StatelessWidget {
  const StoreBookCard({super.key, required this.book, this.width, this.badge});

  final StoreBook book;

  /// Fixed card width (shelves). Without it the card fills its grid cell.
  final double? width;

  /// Shown in the tile's corner; a free book gets "Ücretsiz" by default.
  final StoreBadge? badge;

  static const double _tilePadding = 12;

  /// Height of everything under the tile, at the current text scale.
  static double textHeight(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(84) + 8;

  /// Height of a whole card of width [w].
  static double heightFor(BuildContext context, double w) =>
      (w - 2 * _tilePadding) / kStoreCoverAspect +
      2 * _tilePadding +
      textHeight(context);

  @override
  Widget build(BuildContext context) {
    final StoreColors c = StoreColors.of(context);
    final StoreBadge? tag =
        badge ??
        (book.isFree == true
            ? StoreBadge(t.kitapsen_store_badge_free, c.greenText)
            : null);
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openStoreBook(context, book.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.tile,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(_tilePadding),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Center(child: StoreCover(url: book.coverUrl, shadow: true)),
                    if (tag != null)
                      Positioned(
                        top: -4,
                        left: -4,
                        child: _BadgeChip(tag: tag),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.ink,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            if (book.authorName != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                book.authorName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.muted, fontSize: 13),
              ),
            ],
            if (book.isFree == true) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                t.kitapsen_store_badge_free,
                style: TextStyle(
                  color: c.greenText,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.tag});

  final StoreBadge tag;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(6),
      boxShadow: const <BoxShadow>[
        BoxShadow(color: Color(0x1A000000), blurRadius: 3),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Text(
        tag.label,
        style: TextStyle(
          color: tag.color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

/// Website section header: bold title, a chevron when it leads somewhere.
class StoreSectionHeader extends StatelessWidget {
  const StoreSectionHeader({
    super.key,
    required this.title,
    this.onTap,
    this.trailing,
  });

  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final StoreColors c = StoreColors.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: c.ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onTap != null && trailing == null) ...<Widget>[
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: c.ink),
                  ],
                ],
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// The website's crimson "Tümünü Gör" link.
class StoreSeeAll extends StatelessWidget {
  const StoreSeeAll({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: StoreColors.of(context).accent,
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    child: Text(t.kitapsen_store_see_all),
  );
}

/// A titled horizontal row of books, as on the website home page.
class StoreShelf extends StatelessWidget {
  const StoreShelf({
    super.key,
    required this.title,
    required this.books,
    this.onSeeAll,
    this.badge,
  });

  final String title;
  final List<StoreBook> books;
  final VoidCallback? onSeeAll;

  /// Corner tag on every card (e.g. "Yeni" on new arrivals).
  final StoreBadge? badge;

  static const double cardWidth = 150;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return const SizedBox.shrink();
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.section * 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.page),
            child: StoreSectionHeader(title: title, onTap: onSeeAll),
          ),
          const SizedBox(height: 12),
          StoreBookRow(books: books, badge: badge),
        ],
      ),
    );
  }
}

/// Horizontally scrolling cards (shelves, the reading list, an author's
/// books in search).
class StoreBookRow extends StatelessWidget {
  const StoreBookRow({
    super.key,
    required this.books,
    this.badge,
    this.cardWidth = StoreShelf.cardWidth,
    this.padding,
  });

  final List<StoreBook> books;
  final StoreBadge? badge;
  final double cardWidth;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return SizedBox(
      height: StoreBookCard.heightFor(context, cardWidth),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding:
            padding ?? EdgeInsets.symmetric(horizontal: tokens.spacing.page),
        itemCount: books.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, int i) =>
            StoreBookCard(book: books[i], width: cardWidth, badge: badge),
      ),
    );
  }
}

/// Grid delegate shared by every store grid (full-width grids inset by the
/// page padding): two or more columns of website cards, each exactly as tall
/// as its tile and text.
SliverGridDelegate storeGridDelegate(BuildContext context) {
  final FushiDesignTokens tokens = FushiDesignTokens.of(context);
  const double gap = 16;
  final double available =
      MediaQuery.sizeOf(context).width - 2 * tokens.spacing.page;
  final int columns = ((available + gap) / (180 + gap)).ceil().clamp(2, 12);
  final double cellWidth = (available - (columns - 1) * gap) / columns;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    mainAxisSpacing: 20,
    crossAxisSpacing: gap,
    mainAxisExtent: StoreBookCard.heightFor(context, cellWidth),
  );
}

/// The website's pill buttons for categories (dark when selected).
class StorePill extends StatelessWidget {
  const StorePill({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final StoreColors c = StoreColors.of(context);
    return Material(
      color: selected ? c.navy : c.tile,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : c.body,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// The website's round initial avatar (author chips, matched authors).
class StoreInitialAvatar extends StatelessWidget {
  const StoreInitialAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 14,
  });

  final String name;
  final String? imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final StoreColors c = StoreColors.of(context);
    final String? url = imageUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: c.avatar,
      backgroundImage: url == null ? null : AppCachedHttpImage(url),
      child: url == null
          ? Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: TextStyle(
                color: c.accent,
                fontSize: radius * 0.9,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }
}

class StoreLoadError extends StatelessWidget {
  const StoreLoadError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: FushiPlaceholderMessage(
      icon: Icons.cloud_off_outlined,
      message: t.kitapsen_store_load_failed,
      action: FilledButton.tonal(onPressed: onRetry, child: Text(t.retry)),
    ),
  );
}

/// Star row; the website's amber stars with "4.0 (3 değerlendirme)".
class StoreRating extends StatelessWidget {
  const StoreRating({
    super.key,
    required this.rating,
    this.count,
    this.size = 18,
  });

  final double rating;
  final int? count;
  final double size;

  static const Color _star = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final StoreColors c = StoreColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 1; i <= 5; i++)
          Icon(
            rating >= i
                ? Icons.star
                : rating >= i - 0.5
                ? Icons.star_half
                : Icons.star_border,
            size: size,
            color: rating >= i - 0.5 ? _star : c.border,
          ),
        if (count != null) ...<Widget>[
          const SizedBox(width: 8),
          Text(
            '${rating.toStringAsFixed(1)} '
            '(${t.kitapsen_store_rating_count(n: count!)})',
            style: TextStyle(color: c.body, fontSize: 14),
          ),
        ],
      ],
    );
  }
}

/// The usual spinner / error-with-retry / empty states around a store
/// future's result.
Widget storeAsync<T>(
  AsyncSnapshot<T> snapshot, {
  required VoidCallback onRetry,
  required Widget Function(T data) builder,
  bool Function(T data)? isEmpty,
  IconData emptyIcon = Icons.inbox_outlined,
  String? emptyMessage,
}) {
  if (snapshot.hasError) return StoreLoadError(onRetry: onRetry);
  if (!snapshot.hasData) {
    return const Center(child: CircularProgressIndicator());
  }
  final T data = snapshot.data as T;
  if (isEmpty != null && isEmpty(data)) {
    return Center(
      child: FushiPlaceholderMessage(
        icon: emptyIcon,
        message: emptyMessage ?? t.kitapsen_store_no_results,
      ),
    );
  }
  return builder(data);
}

/// One-field (or one field plus an optional second) text dialog; null when
/// cancelled or left empty.
Future<({String text, String? extra})?> showStoreTextDialog(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  String? extraLabel,
  String initialExtra = '',
  bool multiline = false,
}) => showAppDialog<({String text, String? extra})>(
  context: context,
  builder: (_) => _StoreTextDialog(
    title: title,
    label: label,
    initial: initial,
    extraLabel: extraLabel,
    initialExtra: initialExtra,
    multiline: multiline,
  ),
);

class _StoreTextDialog extends StatefulWidget {
  const _StoreTextDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.extraLabel,
    required this.initialExtra,
    required this.multiline,
  });

  final String title;
  final String label;
  final String initial;
  final String? extraLabel;
  final String initialExtra;
  final bool multiline;

  @override
  State<_StoreTextDialog> createState() => _StoreTextDialogState();
}

class _StoreTextDialogState extends State<_StoreTextDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );
  late final TextEditingController _extra = TextEditingController(
    text: widget.initialExtra,
  );

  @override
  void dispose() {
    _text.dispose();
    _extra.dispose();
    super.dispose();
  }

  void _submit() {
    final String text = _text.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, (
      text: text,
      extra: widget.extraLabel == null ? null : _extra.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          controller: _text,
          autofocus: true,
          minLines: widget.multiline ? 3 : 1,
          maxLines: widget.multiline ? 8 : 1,
          decoration: InputDecoration(labelText: widget.label),
          onSubmitted: widget.multiline ? null : (_) => _submit(),
        ),
        if (widget.extraLabel != null) ...<Widget>[
          const SizedBox(height: 8),
          TextField(
            controller: _extra,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(labelText: widget.extraLabel),
          ),
        ],
      ],
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(t.dialog_cancel),
      ),
      FilledButton(onPressed: _submit, child: Text(t.kitapsen_common_save)),
    ],
  );
}

/// Yes / no question; true only when confirmed.
Future<bool> showStoreConfirm(
  BuildContext context,
  String message, {
  required String action,
  bool destructive = false,
}) async =>
    await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.dialog_cancel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    foregroundColor: Theme.of(
                      dialogContext,
                    ).colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    ) ==
    true;

/// A failed store write, as a toast.
void storeActionFailed(Object e, StackTrace stack, String where) {
  ErrorLogService.instance.log(where, e, stack);
  FushiToast.show(
    msg: t.kitapsen_book_action_failed,
    severity: ToastSeverity.error,
  );
}

/// A row in the account hub and settings lists.
class StoreMenuRow extends StatelessWidget {
  const StoreMenuRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final StoreColors c = StoreColors.of(context);
    return ListTile(
      leading: Icon(icon, color: c.ink),
      title: Text(
        title,
        style: TextStyle(color: c.ink, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: TextStyle(color: c.muted)),
      trailing: Icon(Icons.chevron_right, color: c.muted),
      onTap: onTap,
    );
  }
}

/// Section label of the website's menus and settings ("Okuma", "Sosyal").
class StoreSectionLabel extends StatelessWidget {
  const StoreSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.page,
        tokens.spacing.section,
        tokens.spacing.page,
        4,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: StoreColors.of(context).muted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// "2 gün önce"-style relative time is the website's; the app shows the
/// date (and the time for today).
String storeDate(DateTime? d, {bool dateOnly = false}) {
  if (d == null) return '';
  final DateTime l = d.toLocal();
  final DateTime now = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  if (!dateOnly &&
      l.year == now.year &&
      l.month == now.month &&
      l.day == now.day) {
    return '${two(l.hour)}:${two(l.minute)}';
  }
  return '${two(l.day)}.${two(l.month)}.${l.year}';
}

/// A small labelled chip ("Tamamlandı", "Sahip"), the card corner badge's
/// look on its own.
class StoreBadgeChip extends StatelessWidget {
  const StoreBadgeChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      _BadgeChip(tag: StoreBadge(label, color));
}
