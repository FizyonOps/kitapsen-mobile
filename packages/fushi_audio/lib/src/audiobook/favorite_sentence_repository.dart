import 'dart:convert';

import 'package:fushi_core/fushi_core.dart';

/// 收藏句子的来源标识。与制卡/收藏单词统计的 `kStatSourceBook`/`kStatSourceVideo`/
/// `kStatSourceGame` 口径对齐：统计分桶分「书籍 / 视频 / 游戏」三桶——
/// [kFavoriteSentenceSourceVideo] 归视频统计、[kFavoriteSentenceSourceGame] 归游戏
/// 统计，其余（书内 / 有声书 / 歌词）都归阅读（书籍）统计。收藏夹页展示时仍可按这
/// 五个细分值各自标注来源。
const String kFavoriteSentenceSourceBook = 'book';
const String kFavoriteSentenceSourceVideo = 'video';

/// galgame hook 会话期间的收藏句 / 制卡句（`mined_sentences.source` 也用本值域）。
/// 与 `kStatSourceGame` 逐字节同值，故统计分桶可直接对照。
///
/// ⚠️ 刻意**没有**加进 [SentenceSourceKind]：那个枚举被 collections_page 的四处穷尽
/// switch 消费，加值会让它们编译不过；在这些展示分支补齐 game（图标 / 标签 / 跳转
/// 模块）之前，`'game'` 经 [sentenceSourceKindOf] 宽松解析回退 [SentenceSourceKind.book]，
/// 收藏夹里按书来源展示（这些行本来就无定位锚点、不可跳转，行为无退化）。统计分桶
/// **不**经这个枚举（走 `StatSourceKind` + 本常量的字符串比较），故不受影响。
const String kFavoriteSentenceSourceGame = 'game';

/// 收藏句删除传播墓碑的 mediaType（与收藏词 `'favoriteword'` 并列）。存进统一表
/// [FushiDatabase.writeSyncDeletionTombstone]，供 aggregate 并集抑制复活 + orchestrator
/// 逐条确认删对端两条通道共用。
const String kFavoriteSentenceTombstoneType = 'favoritesentence';

class FavoriteSentence {
  factory FavoriteSentence.fromJson(Map<String, dynamic> json) =>
      FavoriteSentence(
        id: json['id'] as String?,
        text: json['text'] as String,
        bookTitle: json['bookTitle'] as String,
        chapterLabel: json['chapterLabel'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        bookKey: json['bookKey'] as String?,
        sectionIndex: json['sectionIndex'] as int?,
        normCharOffset: json['normCharOffset'] as int?,
        normCharLength: json['normCharLength'] as int?,
        color: json['color'] as String?,
        // 向后兼容：旧条目无 source → 默认书籍；无 dateKey → 留空（不计入按日统计）。
        source: (json['source'] as String?) ?? kFavoriteSentenceSourceBook,
        dateKey: json['dateKey'] as String?,
        expression: json['expression'] as String?,
        reading: json['reading'] as String?,
      );
  FavoriteSentence({
    required this.text,
    required this.bookTitle,
    required this.createdAt,
    this.chapterLabel,
    this.bookKey,
    this.sectionIndex,
    this.normCharOffset,
    this.normCharLength,
    this.color,
    String? id,
    String? source,
    this.dateKey,
    this.expression,
    this.reading,
  })  : id = id ?? _generateFavoriteId(),
        source = source ?? kFavoriteSentenceSourceBook;

  final String id;
  final String text;
  final String bookTitle;
  final String? chapterLabel;
  final DateTime createdAt;
  final String? bookKey;
  final int? sectionIndex;
  final int? normCharOffset;
  final int? normCharLength;
  final String? color;

  /// 收藏来源（[kFavoriteSentenceSourceBook]/`Video`/`Audiobook`/`Lyrics`）。旧条目
  /// 反序列化时默认 [kFavoriteSentenceSourceBook]，保证既有书内收藏行为不变。
  final String source;

  /// 收藏日期键（形如 `2026-06-10`，与制卡/收藏单词统计的 `statDateKey` 同格式）。
  /// 旧条目无此字段 → null，按日统计时归为「未分类」，不参与分桶（不会崩）。
  final String? dateKey;

  /// 从查词弹窗顶栏 ★ 收藏这句时，当时查的那个词（顶层结果的首个词头）与读音。
  /// 收藏夹在句子旁显示它、批量制卡时以它为词条。划选 / 右键菜单收藏的句子没有
  /// 查词对象，为 null；旧条目无此字段同为 null。
  final String? expression;
  final String? reading;

  // BUG-494 (TODO-1053 Bug C)：id 生成必须无碰撞。旧 'hl_<microsecondsSinceEpoch>' 在同一
  // 微秒内连续 new 两条（快速连续收藏 / 测试）会撞出相同 id → id 身份键坍缩（add 按 id 去重
  // 误判重复丢第二条、removeById 连坐）。加进程内单调计数器后缀，保证同微秒也唯一。
  static int _idCounter = 0;
  static String _generateFavoriteId() =>
      'hl_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'bookTitle': bookTitle,
        if (chapterLabel != null) 'chapterLabel': chapterLabel,
        'createdAt': createdAt.toIso8601String(),
        if (bookKey != null) 'bookKey': bookKey,
        if (sectionIndex != null) 'sectionIndex': sectionIndex,
        if (normCharOffset != null) 'normCharOffset': normCharOffset,
        if (normCharLength != null) 'normCharLength': normCharLength,
        if (color != null) 'color': color,
        'source': source,
        if (dateKey != null) 'dateKey': dateKey,
        if (expression != null) 'expression': expression,
        if (reading != null) 'reading': reading,
      };
}

class FavoriteSentenceRepository {
  FavoriteSentenceRepository(this._db);

  final FushiDatabase _db;

  static const String _key = 'favorite_sentences';

  /// 跨设备稳定的内容身份键（**唯一真源**：aggregate 去重、删除墓碑 itemKey、接收端删除
  /// 三处共用同一函数，杜绝键分叉）。`收藏句无稳定 id`（本机随机），只能靠内容四元组。
  /// text 长度前缀防分隔符伪造字段边界；可空字段用显式 `<null>` 哨兵，避免 null 与空串/0
  /// 撞键。与 `AggregateMergeService._favoriteSentenceContentKey`（已改为委托本函数）一致。
  static String itemKey({
    required String text,
    required String? bookKey,
    required int? sectionIndex,
    required int? normCharOffset,
  }) {
    const String nul = '<null>';
    final String bk = bookKey ?? nul;
    final String section = sectionIndex == null ? nul : sectionIndex.toString();
    final String offset =
        normCharOffset == null ? nul : normCharOffset.toString();
    return '${text.length}:$text|$bk|$section|$offset';
  }

  /// [itemKey] 的便捷重载：直接从一条收藏句取内容键。
  static String itemKeyOf(FavoriteSentence s) => itemKey(
        text: s.text,
        bookKey: s.bookKey,
        sectionIndex: s.sectionIndex,
        normCharOffset: s.normCharOffset,
      );

  /// 写删除墓碑（取消收藏 → 传播删除）。
  Future<void> _writeTombstone(FavoriteSentence s) =>
      _db.writeSyncDeletionTombstone(kFavoriteSentenceTombstoneType,
          itemKeyOf(s), DateTime.now().millisecondsSinceEpoch);

  Future<List<FavoriteSentence>> getAll() async {
    final raw = await _db.getPref(_key);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => FavoriteSentence.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> add(FavoriteSentence sentence) async {
    final sentences = await getAll();
    // BUG-494 (TODO-1053 Bug C)：去重**只按 id**（每条 add 的 FavoriteSentence 自带唯一 id）。
    // 不再按内容键（text+bookKey+section+normCharOffset）去重——那会在 normCharOffset 均 null
    // 时把同章重复短句 collapse 成一条（身份键坍缩，Bug C 的幻影收藏根因）。重复收藏同一句
    // 由调用方（reader 的 _currentSentenceIsFavorited 门控）拦在 add 之前，不靠这里内容去重。
    if (sentences.any((s) => s.id == sentence.id)) {
      return;
    }
    sentences.insert(0, sentence);
    await _db.setPref(
      _key,
      jsonEncode(sentences.map((s) => s.toJson()).toList()),
    );
    // 重新收藏 → 清除该内容键的删除墓碑；否则墓碑会在 aggregate 并集里把这条刚收藏的句
    // 再次抑制掉（与收藏词 addFavoriteWord 清墓碑同律）。
    await _db.clearSyncDeletionTombstone(
        kFavoriteSentenceTombstoneType, itemKeyOf(sentence));
  }

  /// 查已收藏项：返回**匹配到的条目 id**（未收藏 → null）。id-first——先按内容键（含
  /// normCharOffset）精确匹配，命中即返回该条 id 供 [removeById] 精确删除，杜绝 Bug C
  /// 的身份键坍缩误删/误点亮（同章重复短句 offset 均 null 时，内容键相同也只会命中「某一
  /// 条」，但因 removeById 按返回 id 删，不会连坐删掉另一条同内容记录）。
  Future<String?> matchedFavoriteId({
    required String text,
    required String? bookKey,
    required int? sectionIndex,
    required int? normCharOffset,
  }) async {
    final sentences = await getAll();
    for (final FavoriteSentence s in sentences) {
      if (s.text == text &&
          s.bookKey == bookKey &&
          s.sectionIndex == sectionIndex &&
          s.normCharOffset == normCharOffset) {
        return s.id;
      }
    }
    return null;
  }

  Future<void> removeById(String id, {bool propagateDeletion = true}) async {
    final sentences = await getAll();
    // id 理论唯一，但 BUG-494 前的旧数据可能撞 id；捕获全部被删条目各写一次墓碑（同内容
    // 键幂等）。
    final List<FavoriteSentence> removed =
        sentences.where((s) => s.id == id).toList();
    if (removed.isEmpty) return;
    sentences.removeWhere((s) => s.id == id);
    await _db.setPref(
      _key,
      jsonEncode(sentences.map((s) => s.toJson()).toList()),
    );
    for (final FavoriteSentence s in removed) {
      await _writeTombstone(s);
    }
  }

}
