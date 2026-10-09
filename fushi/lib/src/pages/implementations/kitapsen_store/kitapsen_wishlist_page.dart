/// The reader's wishlist on kitapsen.com.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_store_widgets.dart';
import 'package:fushi/src/sync/kitapsen_store.dart';
import 'package:fushi/utils.dart';

class KitapsenWishlistPage extends ConsumerStatefulWidget {
  const KitapsenWishlistPage({super.key});

  @override
  ConsumerState<KitapsenWishlistPage> createState() =>
      _KitapsenWishlistPageState();
}

class _KitapsenWishlistPageState extends ConsumerState<KitapsenWishlistPage> {
  late Future<List<StoreBook>> _load = _fetch();

  Future<List<StoreBook>> _fetch() async =>
      (await KitapsenStore.open(ref.read(appProvider).database)).wishlist();

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return FushiPageScaffold(
      title: t.kitapsen_wishlist_title,
      body: FutureBuilder<List<StoreBook>>(
        future: _load,
        builder: (BuildContext context, AsyncSnapshot<List<StoreBook>> s) {
          if (s.hasError) {
            return StoreLoadError(
              onRetry: () => setState(() => _load = _fetch()),
            );
          }
          final List<StoreBook>? books = s.data;
          if (books == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (books.isEmpty) {
            return Center(
              child: FushiPlaceholderMessage(
                icon: Icons.favorite_border,
                message: t.kitapsen_wishlist_empty,
              ),
            );
          }
          return GridView.builder(
            padding: withBottomSafeInset(
              context,
              EdgeInsets.all(tokens.spacing.page),
            ),
            gridDelegate: storeGridDelegate(context),
            itemCount: books.length,
            itemBuilder: (_, int i) => StoreBookCard(book: books[i]),
          );
        },
      ),
    );
  }
}
