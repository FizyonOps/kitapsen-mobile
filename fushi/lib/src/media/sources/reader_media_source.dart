
import 'package:fushi/media.dart';

/// A source for the [ReaderMediaType], which handles primarily text-based
/// media.
abstract class ReaderMediaSource extends MediaSource {
  /// Initialise a media source.
  ReaderMediaSource({
    required super.uniqueKey,
    required super.sourceName,
    required super.description,
    required super.icon,
    required super.implementsSearch,
    required super.implementsHistory,
    super.overridesAutoImage = false,
    super.overridesAutoAudio = false,
  }) : super(
          mediaType: ReaderMediaType.instance,
        );

  /// BUG-1317：EPUB / 漫画 / PDF 是**同一本书**的三种 `EpubBooks.format`，共享
  /// `hoshi://book/<bookKey>` 身份，而 `mediaSourceIdentifier` 由**当前** format
  /// 现算（转化后会变）。override 书名 / 封面必须跟着**书**走，不跟着阅读器走，
  /// 所以三源统一存进 EPUB 源的偏好命名空间。
  @override
  MediaSource get overrideStore => ReaderFushiSource.instance;

  /// BUG-1317 读取期回退：存量 override 按写入时的 format 散落在三个源各自的
  /// `src:<sourceId>:` 命名空间里，三个都要试。
  @override
  List<MediaSource> get legacyOverrideStores => <MediaSource>[
        ReaderFushiSource.instance,
        ReaderPdfSource.instance,
      ];

}
