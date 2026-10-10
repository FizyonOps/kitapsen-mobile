/// Reading goals ("Okuma Hedefleri") and the reading summary, as on the
/// website. The server moves the progress as reading syncs: a book counts
/// when it reaches 100 %, a day counts once per day with reading.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_store_widgets.dart';
import 'package:fushi/src/sync/kitapsen_community.dart';
import 'package:fushi/src/sync/kitapsen_store.dart';
import 'package:fushi/utils.dart';

String _num(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

String _goalUnit(String type, double n) => switch (type) {
  'PAGES' => t.kitapsen_goals_unit_pages(n: _num(n)),
  'HOURS' => t.kitapsen_goals_unit_hours(n: _num(n)),
  'DAYS' => t.kitapsen_goals_unit_days(n: _num(n)),
  _ => t.kitapsen_goals_unit_books(n: _num(n)),
};

class KitapsenGoalsPage extends ConsumerStatefulWidget {
  const KitapsenGoalsPage({super.key});

  @override
  ConsumerState<KitapsenGoalsPage> createState() => _KitapsenGoalsPageState();
}

class _KitapsenGoalsPageState extends ConsumerState<KitapsenGoalsPage> {
  late Future<(KitapsenStore, StoreReadingStats, List<StoreReadingGoal>)>
  _load = _fetch();

  Future<(KitapsenStore, StoreReadingStats, List<StoreReadingGoal>)>
  _fetch() async {
    final KitapsenStore store = await KitapsenStore.open(
      ref.read(appProvider).database,
    );
    final (StoreReadingStats stats, List<StoreReadingGoal> goals) = await (
      store.readingStats(),
      store.readingGoals(),
    ).wait;
    return (store, stats, goals);
  }

  void _reload() => setState(() => _load = _fetch());

  Future<void> _create(KitapsenStore store) async {
    final ({String type, double target, bool year})? r =
        await showAppDialog<({String type, double target, bool year})>(
          context: context,
          builder: (_) => const _GoalDialog(),
        );
    if (r == null) return;
    final DateTime now = DateTime.now();
    final DateTime start = r.year
        ? DateTime(now.year)
        : DateTime(now.year, now.month);
    final DateTime end = r.year
        ? DateTime(now.year, 12, 31)
        : DateTime(now.year, now.month + 1, 0);
    try {
      await store.createReadingGoal(
        type: r.type,
        target: r.target,
        start: start,
        end: end,
      );
      FushiToast.show(
        msg: t.kitapsen_goals_created,
        severity: ToastSeverity.success,
      );
      _reload();
    } catch (e, stack) {
      storeActionFailed(e, stack, 'KitapsenGoalsPage.create');
    }
  }

  Future<void> _delete(KitapsenStore store, StoreReadingGoal g) async {
    if (!await showStoreConfirm(
      context,
      t.kitapsen_goals_delete_confirm,
      action: t.dialog_delete,
      destructive: true,
    )) {
      return;
    }
    try {
      await store.deleteReadingGoal(g.id);
      _reload();
    } catch (e, stack) {
      storeActionFailed(e, stack, 'KitapsenGoalsPage.delete');
    }
  }

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return FutureBuilder<
      (KitapsenStore, StoreReadingStats, List<StoreReadingGoal>)
    >(
      future: _load,
      builder:
          (
            _,
            AsyncSnapshot<
              (KitapsenStore, StoreReadingStats, List<StoreReadingGoal>)
            >
            s,
          ) {
            final KitapsenStore? store = s.data?.$1;
            return FushiPageScaffold(
              title: t.kitapsen_goals_title,
              actions: <Widget>[
                if (store != null)
                  IconButton(
                    key: const ValueKey<String>('kitapsen-goals-new'),
                    tooltip: t.kitapsen_goals_new,
                    icon: const Icon(Icons.add),
                    onPressed: () => _create(store),
                  ),
              ],
              body: storeAsync(
                s,
                onRetry: _reload,
                builder:
                    (
                      (KitapsenStore, StoreReadingStats, List<StoreReadingGoal>)
                      d,
                    ) => ListView(
                      padding: withBottomSafeInset(
                        context,
                        EdgeInsets.all(tokens.spacing.page),
                      ),
                      children: <Widget>[
                        _stats(context, d.$2),
                        const SizedBox(height: 24),
                        if (d.$3.isEmpty)
                          FushiPlaceholderMessage(
                            icon: Icons.flag_outlined,
                            message: t.kitapsen_goals_empty,
                            action: FilledButton.icon(
                              onPressed: () => _create(d.$1),
                              icon: const Icon(Icons.add),
                              label: Text(t.kitapsen_goals_new),
                            ),
                          ),
                        for (final StoreReadingGoal g in d.$3)
                          _goal(context, d.$1, g),
                      ],
                    ),
              ),
            );
          },
    );
  }

  Widget _stats(BuildContext context, StoreReadingStats st) {
    final StoreColors c = StoreColors.of(context);
    Widget cell(String label, int value) => Expanded(
      child: Column(
        children: <Widget>[
          Text(
            '$value',
            style: TextStyle(
              color: c.ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.tile,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: <Widget>[
            cell(t.kitapsen_goals_streak, st.currentStreak),
            cell(t.kitapsen_goals_longest_streak, st.longestStreak),
            cell(t.kitapsen_goals_books_read, st.booksRead),
            cell(t.kitapsen_goals_books_finished, st.booksFinished),
          ],
        ),
      ),
    );
  }

  Widget _goal(BuildContext context, KitapsenStore store, StoreReadingGoal g) {
    final StoreColors c = StoreColors.of(context);
    final double fraction = g.target <= 0
        ? 0
        : (g.progress / g.target).clamp(0, 1).toDouble();
    final bool done = g.completed || fraction >= 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _goalUnit(g.type, g.target),
                      style: TextStyle(
                        color: c.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (done)
                    StoreBadgeChip(
                      label: t.kitapsen_goals_completed,
                      color: c.greenText,
                    ),
                  IconButton(
                    tooltip: t.dialog_delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(store, g),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      t.kitapsen_goals_until(
                        date: storeDate(g.endDate, dateOnly: true),
                      ),
                      style: TextStyle(color: c.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 8,
                        backgroundColor: c.tile,
                        color: done ? c.green : c.accent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_num(g.progress)} / ${_num(g.target)}',
                      style: TextStyle(color: c.body, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog();

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  final TextEditingController _target = TextEditingController(text: '2');
  String _type = 'BOOKS';
  bool _year = false;

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(t.kitapsen_goals_new),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: InputDecoration(labelText: t.kitapsen_goals_type),
          items: <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(
              value: 'BOOKS',
              child: Text(t.kitapsen_goals_type_books),
            ),
            DropdownMenuItem<String>(
              value: 'PAGES',
              child: Text(t.kitapsen_goals_type_pages),
            ),
            DropdownMenuItem<String>(
              value: 'DAYS',
              child: Text(t.kitapsen_goals_type_days),
            ),
          ],
          onChanged: (String? v) => setState(() => _type = v ?? 'BOOKS'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _target,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: t.kitapsen_goals_target),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: <ButtonSegment<bool>>[
            ButtonSegment<bool>(
              value: false,
              label: Text(t.kitapsen_goals_this_month),
            ),
            ButtonSegment<bool>(
              value: true,
              label: Text(t.kitapsen_goals_this_year),
            ),
          ],
          selected: <bool>{_year},
          onSelectionChanged: (Set<bool> v) => setState(() => _year = v.first),
        ),
      ],
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(t.dialog_cancel),
      ),
      FilledButton(
        onPressed: () {
          final double? target = double.tryParse(
            _target.text.trim().replaceAll(',', '.'),
          );
          if (target == null || target <= 0) return;
          Navigator.pop(context, (type: _type, target: target, year: _year));
        },
        child: Text(t.kitapsen_goals_create),
      ),
    ],
  );
}
