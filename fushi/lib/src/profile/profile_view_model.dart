import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fushi_core/fushi_core.dart';
import 'package:fushi/src/media/sources/reader_fushi_source.dart';
import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/profile/profile_repository.dart';

/// Serializes Profile application: one change runs at a time, in call order,
/// so a second change never observes an AppModel the first left half applied.
class ProfileDraftCoordinator {
  Future<void> _tail = Future<void>.value();

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final Future<void> previous = _tail;
    final Completer<void> release = Completer<void>();
    _tail = release.future;

    return (() async {
      await previous;
      try {
        return await action();
      } finally {
        release.complete();
      }
    })();
  }

  Future<T> runProfileChange<T>(Future<T> Function() action) =>
      _exclusive(action);
}

class ProfileUiState {
  const ProfileUiState({
    this.profiles = const [],
    this.activeProfileId = -1,
    this.mediaTypeBindings = const {},
    this.languageBindings = const {},
    this.isLoading = false,
  });
  final List<ProfileRow> profiles;
  final int activeProfileId;
  final Map<String, int> mediaTypeBindings;

  /// 语言绑定：key = 归一化语言标签（`ja` / `zh-Hant`），value = profileId。
  /// 与 [mediaTypeBindings] 不同，它是**开放值域**——没有固定枚举可以铺死，UI 只
  /// 能列出已有绑定 + 一个添加入口。
  final Map<String, int> languageBindings;
  final bool isLoading;

  ProfileRow? get activeProfile {
    for (final p in profiles) {
      if (p.id == activeProfileId) return p;
    }
    return profiles.isNotEmpty ? profiles.first : null;
  }

  ProfileUiState copyWith({
    List<ProfileRow>? profiles,
    int? activeProfileId,
    Map<String, int>? mediaTypeBindings,
    Map<String, int>? languageBindings,
    bool? isLoading,
  }) =>
      ProfileUiState(
        profiles: profiles ?? this.profiles,
        activeProfileId: activeProfileId ?? this.activeProfileId,
        mediaTypeBindings: mediaTypeBindings ?? this.mediaTypeBindings,
        languageBindings: languageBindings ?? this.languageBindings,
        isLoading: isLoading ?? this.isLoading,
      );
}

class ProfileViewModel extends StateNotifier<ProfileUiState> {
  ProfileViewModel(
    this._repo,
    this._onProfileApplied,
    this._profileDraftCoordinator,
  ) : super(const ProfileUiState()) {
    _load();
  }

  @override
  void dispose() {
    _repo.snapshotCurrentSettings(state.activeProfileId).catchError((Object e) {
      debugPrint('[profile] snapshot on dispose failed: $e');
    });
    super.dispose();
  }

  final ProfileRepository _repo;
  final Future<void> Function() _onProfileApplied;
  final ProfileDraftCoordinator _profileDraftCoordinator;

  Future<T> _whileInvalidatingProfileDrafts<T>(
    Future<T> Function() action,
  ) =>
      _profileDraftCoordinator.runProfileChange(action);

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    await _repo.ensureDefaultProfile();
    final profiles = await _repo.getAllProfiles();
    final activeId = await _repo.getActiveProfileId();
    final bindings = await _repo.getAllMediaTypeBindings();
    final languageBindings = await _repo.getAllLanguageBindings();
    state = ProfileUiState(
      profiles: profiles,
      activeProfileId: activeId,
      mediaTypeBindings: bindings,
      languageBindings: languageBindings,
    );
  }

  /// TODO-2936：解析绑定（book 级 > 语言级 > 媒体类型级 > 当前激活）并在结果与当前激活
  /// 不同时切换。各媒体入口（阅读器 / 视频 / 漫画开页、gal launch/attach、浏览
  /// 器扩展查词）共用的非致命入口：失败只记日志，绝不打断调用方的加载/查词链。
  /// [languageTag]：该条目的**内容语言**原始串（`EpubBooks.language` /
  /// `VideoBooks.language` / `Galgames.language` 等列的值），由 repository 归一。
  /// 拿不到就不传——绝不要拿全局默认内容语言来填（理由见 [ProfileRepository.
  /// resolveProfileId] 的文档）。
  Future<void> autoApplyBinding({
    String? bookUid,
    String? languageTag,
    required ProfileMediaKind mediaType,
  }) async {
    try {
      final int resolvedId = await _repo.resolveProfileId(
        bookUid: bookUid,
        languageTag: languageTag,
        mediaType: mediaType,
      );
      final int currentActiveId = await _repo.getActiveProfileId();
      if (resolvedId != currentActiveId) {
        await switchProfile(resolvedId);
      }
    } catch (e, st) {
      debugPrint('[profile] auto-apply "${mediaType.dbValue}" binding failed '
          '(non-fatal): $e\n$st');
    }
  }

  Future<void> switchProfile(int profileId) =>
      _whileInvalidatingProfileDrafts(() async {
        await _repo.snapshotCurrentSettings(state.activeProfileId);
        await _repo.setActiveProfileId(profileId);
        await _repo.applyProfile(profileId);
        state = state.copyWith(activeProfileId: profileId);
        await _onProfileApplied();
      });

}

final fushiDatabaseProvider = Provider<FushiDatabase>((ref) {
  final appModel = ref.watch(appProvider);
  return appModel.database;
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final db = ref.watch(fushiDatabaseProvider);
  return ProfileRepository(
    db,
    // BUG-1994：回插被旧 prune 删掉的词典行时，「装没装」只认磁盘目录。
    isDictionaryInstalled: ref.read(appProvider).isDictionaryInstalledOnDisk,
  );
});

/// 临时 UI 草稿所绑定的 Profile 应用代次。
///
/// 它刻意独立于 [ProfileViewModel] 的异步初始加载：首次加载期间
/// `activeProfileId` 会从 -1 变成真实 id，但 AppModel 并未切换 Profile，
/// 因而不应误杀用户刚输入的草稿。只有真正应用/替换 Profile 的操作才轮换
/// 这个对象。它还串行化 Profile 应用与草稿保存，封住单次 scope guard 后的
/// 异步交叉写入窗口。
final profileDraftCoordinatorProvider = Provider<ProfileDraftCoordinator>(
  (ref) => ProfileDraftCoordinator(),
);

final profileViewModelProvider =
    StateNotifierProvider<ProfileViewModel, ProfileUiState>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  final ProfileDraftCoordinator profileDraftCoordinator =
      ref.watch(profileDraftCoordinatorProvider);
  Future<void> onApplied() async {
    final appModel = ref.read(appProvider);
    await appModel.refreshPrefCache();
    await ReaderFushiSource.readerSettings?.refreshFromDb();
  }

  return ProfileViewModel(repo, onApplied, profileDraftCoordinator);
});
