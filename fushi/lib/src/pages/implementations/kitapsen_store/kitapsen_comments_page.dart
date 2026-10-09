/// Comments under a review or a story chapter, with a box to add one when
/// signed in.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_store_widgets.dart';
import 'package:fushi/src/sync/kitapsen_store.dart';
import 'package:fushi/utils.dart';

class KitapsenCommentsPage extends StatefulWidget {
  const KitapsenCommentsPage({
    super.key,
    required this.load,
    this.add,
    this.subtitle,
  });

  final Future<List<StoreComment>> Function() load;

  /// Null when signed out: the list is read-only.
  final Future<void> Function(String content)? add;
  final String? subtitle;

  @override
  State<KitapsenCommentsPage> createState() => _KitapsenCommentsPageState();
}

class _KitapsenCommentsPageState extends State<KitapsenCommentsPage> {
  late Future<List<StoreComment>> _comments = widget.load();
  final TextEditingController _input = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final Future<void> Function(String)? add = widget.add;
    final String text = _input.text.trim();
    if (add == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await add(text);
      _input.clear();
      if (mounted) setState(() => _comments = widget.load());
    } catch (e, stack) {
      ErrorLogService.instance.log('KitapsenCommentsPage.add', e, stack);
      FushiToast.show(
        msg: t.kitapsen_book_action_failed,
        severity: ToastSeverity.error,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return FushiPageScaffold(
      title: t.kitapsen_comments_title,
      subtitle: widget.subtitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: FutureBuilder<List<StoreComment>>(
              future: _comments,
              builder: (_, AsyncSnapshot<List<StoreComment>> s) {
                if (s.hasError) {
                  return StoreLoadError(
                    onRetry: () => setState(() => _comments = widget.load()),
                  );
                }
                final List<StoreComment>? comments = s.data;
                if (comments == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (comments.isEmpty) {
                  return Center(
                    child: FushiPlaceholderMessage(
                      icon: Icons.chat_bubble_outline,
                      message: t.kitapsen_comments_empty,
                    ),
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.all(tokens.spacing.page),
                  itemCount: comments.length,
                  separatorBuilder: (_, __) => const Divider(height: 24),
                  itemBuilder: (_, int i) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(comments[i].userName, style: tokens.type.metadata),
                      const SizedBox(height: 2),
                      Text(comments[i].content),
                    ],
                  ),
                );
              },
            ),
          ),
          if (widget.add != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.gap),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        key: const ValueKey<String>('kitapsen-comment-input'),
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: t.kitapsen_comment_hint,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey<String>('kitapsen-comment-send'),
                      tooltip: t.kitapsen_review_submit,
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
