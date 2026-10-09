/// Building blocks of the Kitapsen store screens: covers, book cards, shelves,
/// grids and the shared navigation helpers.
library;

import 'package:flutter/material.dart';

import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_book_page.dart';
import 'package:fushi/src/settings/settings_detail_page.dart';
import 'package:fushi/src/settings/settings_schema_services.dart'
    show buildServicesDestination;
import 'package:fushi/src/sync/kitapsen_store.dart';
import 'package:fushi/src/utils/net/app_http_image.dart';
import 'package:fushi/utils.dart';

/// Cover aspect ratio of store cards (2:3, the usual book jacket).
const double kStoreCoverAspect = 2 / 3;

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
  const StoreCover({super.key, required this.url, this.borderRadius = 8});

  final String? url;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final Widget placeholder = ColoredBox(
      color: tokens.surfaces.group,
      child: Center(
        child: Icon(Icons.menu_book_outlined, color: tokens.surfaces.onVariant),
      ),
    );
    final String? src = url;
    return ClipRRect(
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
  }
}

class StoreBookCard extends StatelessWidget {
  const StoreBookCard({super.key, required this.book, this.width});

  final StoreBook book;

  /// Fixed card width (shelves). Without it the card fills its grid cell and
  /// the cover shrinks to leave room for the text.
  final double? width;

  /// Title (two lines) + author line under the cover, at the current text
  /// scale.
  static double textHeight(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(58) + 6;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget cover = StoreCover(url: book.coverUrl);
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => openStoreBook(context, book.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (width == null)
              Expanded(
                child: Align(alignment: Alignment.bottomLeft, child: cover),
              )
            else
              cover,
            const SizedBox(height: 6),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            if (book.authorName != null)
              Text(
                book.authorName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: FushiDesignTokens.of(context).surfaces.onVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A titled horizontal row of books with an optional "See all".
class StoreShelf extends StatelessWidget {
  const StoreShelf({
    super.key,
    required this.title,
    required this.books,
    this.onSeeAll,
  });

  final String title;
  final List<StoreBook> books;
  final VoidCallback? onSeeAll;

  static const double _cardWidth = 116;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return const SizedBox.shrink();
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.page),
            child: Row(
              children: <Widget>[
                Expanded(child: Text(title, style: tokens.type.sectionLabel)),
                if (onSeeAll != null)
                  TextButton(
                    onPressed: onSeeAll,
                    child: Text(t.kitapsen_store_see_all),
                  ),
              ],
            ),
          ),
          SizedBox(
            height:
                _cardWidth / kStoreCoverAspect +
                StoreBookCard.textHeight(context),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.page),
              itemCount: books.length,
              separatorBuilder: (_, __) => SizedBox(width: tokens.spacing.gap),
              itemBuilder: (_, int i) =>
                  StoreBookCard(book: books[i], width: _cardWidth),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid delegate shared by every store grid (full-width grids inset by the
/// page padding): cells up to 150 wide, each as tall as a 2:3 cover of the
/// actual cell width plus the text lines, so covers never leave a gap.
SliverGridDelegate storeGridDelegate(BuildContext context) {
  final FushiDesignTokens tokens = FushiDesignTokens.of(context);
  final double gap = tokens.spacing.gap;
  final double available =
      MediaQuery.sizeOf(context).width - 2 * tokens.spacing.page;
  final int columns = ((available + gap) / (150 + gap)).ceil().clamp(2, 12);
  final double cellWidth = (available - (columns - 1) * gap) / columns;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    mainAxisSpacing: gap,
    crossAxisSpacing: gap,
    mainAxisExtent:
        cellWidth / kStoreCoverAspect + StoreBookCard.textHeight(context),
  );
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

class StoreRating extends StatelessWidget {
  const StoreRating({
    super.key,
    required this.rating,
    this.count,
    this.size = 16,
  });

  final double rating;
  final int? count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.primary;
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
            color: color,
          ),
        if (count != null) ...<Widget>[
          const SizedBox(width: 6),
          Text(
            '${rating.toStringAsFixed(1)} ($count)',
            style: FushiDesignTokens.of(context).type.metadata,
          ),
        ],
      ],
    );
  }
}
