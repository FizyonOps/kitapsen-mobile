/// One chapter of a serialized story (Markdown), with previous / next.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_store_widgets.dart';
import 'package:fushi/src/sync/kitapsen_store.dart';
import 'package:fushi/utils.dart';

class KitapsenChapterPage extends StatefulWidget {
  const KitapsenChapterPage({
    super.key,
    required this.store,
    required this.bookId,
    required this.bookTitle,
    required this.chapters,
    required this.index,
  });

  final KitapsenStore store;
  final int bookId;
  final String bookTitle;
  final List<StoreChapter> chapters;
  final int index;

  @override
  State<KitapsenChapterPage> createState() => _KitapsenChapterPageState();
}

class _KitapsenChapterPageState extends State<KitapsenChapterPage> {
  late int _index = widget.index;
  late Future<StoreChapter> _load = _fetch();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<StoreChapter> _fetch() async {
    final StoreChapter summary = widget.chapters[_index];
    final StoreChapter chapter = await widget.store.chapter(
      widget.bookId,
      summary.id,
    );
    unawaited(
      widget.store
          .recordChapterRead(widget.bookId, summary.id)
          .catchError(
            (Object e, StackTrace stack) => ErrorLogService.instance.log(
              'KitapsenChapterPage.read',
              e,
              stack,
            ),
          ),
    );
    return chapter;
  }

  void _go(int index) {
    setState(() {
      _index = index;
      _load = _fetch();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final StoreChapter summary = widget.chapters[_index];
    return FushiPageScaffold(
      title: '${summary.number}. ${summary.title}',
      subtitle: widget.bookTitle,
      body: FutureBuilder<StoreChapter>(
        future: _load,
        builder: (BuildContext context, AsyncSnapshot<StoreChapter> s) {
          if (s.hasError) {
            return StoreLoadError(
              onRetry: () => setState(() => _load = _fetch()),
            );
          }
          final StoreChapter? chapter = s.data;
          if (chapter == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            controller: _scroll,
            padding: withBottomSafeInset(
              context,
              EdgeInsets.all(tokens.spacing.page),
            ),
            children: <Widget>[
              MarkdownBody(
                data: chapter.content ?? '',
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                    .copyWith(
                      p: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.6),
                    ),
              ),
              SizedBox(height: tokens.spacing.section),
              Row(
                children: <Widget>[
                  if (_index > 0)
                    OutlinedButton.icon(
                      onPressed: () => _go(_index - 1),
                      icon: const Icon(Icons.chevron_left),
                      label: Text(t.kitapsen_story_previous),
                    ),
                  const Spacer(),
                  if (_index < widget.chapters.length - 1)
                    FilledButton.icon(
                      onPressed: () => _go(_index + 1),
                      icon: const Icon(Icons.chevron_right),
                      label: Text(t.kitapsen_story_next),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
