import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fushi/src/utils/misc/error_log_service.dart';
import 'package:share_plus/share_plus.dart';

/// 系统分享面板**在途**的上限。
///
/// share_plus 10 起只剩结果变体：Future 要等面板**关闭**（Android 的
/// `onActivityResult`、iOS 的 completion handler）才完成，所以这是「面板从弹出
/// 到关闭」的余量，不是一次呈现往返。不加这道上限时，平台侧不回包就会把
/// [FushiShare._sharing] 永久钉在 true——那是个 static 字段，一坏就是**全 App**
/// 此后每一次分享都被防重入门静默丢弃（BUG-2542）。
const Duration _kShareSheetTimeout = Duration(minutes: 5);

/// 统一的系统分享入口（TODO-1318 / BUG-608）。
///
/// share_plus 7.x 的结果变体在 Android 侧有个死锁：`ShareSuccessManager` 的
/// `isCalledBack` 标志在上一次面板没回调时（面板被系统方式关闭、Activity 被
/// 重建、目标 App 未回传结果）会**永久卡在 false**，之后每一次分享都抛
/// `Share callback error, prior share-sheet did not call back`，所以这里曾改走
/// 非结果变体 `Share.shareFiles`。share_plus 10 删掉了非结果变体，也修掉了这个
/// 死锁（新的一次分享会先以 `unavailable` 结掉悬着的那次），本类于是改用
/// `Share.share` / `Share.shareXFiles`，并保留进程内**防重入**串行化，避免连点
/// 分享按钮时叠出两个分享面板。
abstract class FushiShare {

  // iOS 分享锚点（BUG-2064）：share_plus 的 iOS 端把 text / uri / files 三条
  // 路径统一汇进 `+share:`（`FPPSharePlusPlugin.m`）。只要
  // `popoverPresentationController != NULL`（iPad 必然成立，iPhone 横屏等场景
  // 也会成立），它就要求锚点 rect **非空**且被 root view 的 frame **完全包含**，
  // 否则直接抛 `PlatformException(error, sharePositionOrigin: argument must be
  // set, {{0, 0}, {0, 0}} must be non-zero and within coordinate space of
  // source view: ...)`——`sharePositionOrigin` 缺省时 rect 就是 `CGRectZero`。
  //
  // 因此锚点不是「调用方可选的美化项」，而是分享入口必须自带的**不变式**：
  // 由本类统一解析当前 view 的逻辑尺寸并给出居中的合法锚点，调用点不需要、
  // 也不应该各自传坐标（分散传参必然漏，漏一处就是一处崩溃）。
  //
  // 平台消费面（BUG-2064 复核实测，别照抄「只有 iOS 读锚点」）：
  // - iOS：见上，缺锚点在 iPad / iPhone 横屏必崩，这是本参数存在的理由。
  // - macOS：**同样消费**。`SharePlusMacosPlugin.originRect()` 在缺参时取
  //   `NSMakeRect(0,0,0,0)`，再交给 `picker.show(relativeTo:of:preferredEdge:)`；
  //   AppKit 约定空 rect 退化成 view 的 bounds。所以统一改传居中 1×1 锚点之后，
  //   macOS 分享面板的落点会从窗口边沿移到**窗口正中**；iPad popover 的箭头同理
  //   指向屏幕正中，而不是触发分享的那个按钮。拿这点观感换掉 iOS 上的必崩，是
  //   有意的取舍——锚点的合法性是硬约束，落点只是美观。
  // - Android / Windows / Linux：确实忽略该参数（`MethodCallHandler.kt`、
  //   `share_plus_plugin.cpp`、`share_plus_linux.dart` 都不读它）。
  // 因此仍然不需要平台分支：给出一个恒合法的锚点，五个平台都能正确处理。

  /// 防重入：全 App 同一时刻只允许一个系统分享面板在途。
  static bool _sharing = false;

  /// 由 [viewSize] 推出一个**必定合法**的 iOS popover 锚点：位于 view 正中、
  /// 边长 1 逻辑点的矩形。
  ///
  /// 不变式（对应 iOS 侧 `CGRectIsEmpty` + `CGRectContainsRect` 两道校验）：
  /// 返回的 rect 宽高恒 `> 0`，且恒被 `Offset.zero & viewSize` 完全包含。
  /// [viewSize] 非法（零、负、非有限）时退回 `1x1@(0,0)`——此时 view 本身还没
  /// 布局，任何锚点都不可能落在其坐标系内，给合法形状即可，不留 `CGRectZero`。
  @visibleForTesting
  static Rect sharePositionOriginForViewSize(Size viewSize) {
    final double vw = viewSize.width;
    final double vh = viewSize.height;
    if (!vw.isFinite || !vh.isFinite || vw <= 0 || vh <= 0) {
      return const Rect.fromLTWH(0, 0, 1, 1);
    }
    final double w = math.min(1, vw);
    final double h = math.min(1, vh);
    return Rect.fromLTWH((vw - w) / 2, (vh - h) / 2, w, h);
  }

  /// 当前 view 的逻辑尺寸。直接读 `dart:ui` 的 [ui.PlatformDispatcher]，不经
  /// `WidgetsBinding`：分享可能从没有 `BuildContext` 的平台 seam 触发。
  static Size _currentViewSize() {
    final ui.PlatformDispatcher dispatcher = ui.PlatformDispatcher.instance;
    final ui.FlutterView? view = dispatcher.implicitView ??
        (dispatcher.views.isNotEmpty ? dispatcher.views.first : null);
    if (view == null) return Size.zero;
    final double ratio = view.devicePixelRatio;
    if (!ratio.isFinite || ratio <= 0) return Size.zero;
    return view.physicalSize / ratio;
  }

  static Rect _sharePositionOrigin() =>
      sharePositionOriginForViewSize(_currentViewSize());

  /// 通过系统分享面板分享一段文本。
  ///
  /// 与 [shareFiles] 共用同一道防重入门（全 App 同一时刻只允许一个面板），并
  /// 同样自带 iOS 锚点。空文本直接返回：iOS 侧会以 `Non-empty text expected`
  /// 拒绝，Android 侧则弹出一个空面板，都不是有用行为。
  ///
  /// 返回**这次分享是否真的送到了平台**——语义与 [shareFiles] 一致，见那里的说明。
  static Future<bool> shareText(String text, {String? subject}) async {
    if (_sharing || text.isEmpty) {
      _logDroppedShare('shareText', reentrant: _sharing);
      return false;
    }
    _sharing = true;
    try {
      await Share.share(
        text,
        subject: subject,
        sharePositionOrigin: _sharePositionOrigin(),
      ).timeout(_kShareSheetTimeout);
      return true;
    } on TimeoutException {
      _logShareTimeout('shareText');
      return false;
    } finally {
      _sharing = false;
    }
  }

  /// 通过系统分享面板分享一个或多个文件。
  ///
  /// [files] 允许包含内存型 `XFile`（`XFile.fromData`，`path` 为空）——share_plus
  /// 会先把它落盘到临时目录再分享。
  ///
  /// 返回的 `Future` 在分享面板**关闭后**才完成，其值是**这次分享是否真的送到了
  /// 平台**：`false` 表示这次分享根本没送出去——被防重入门丢弃、文件列表为空，
  /// 或平台侧在 [_kShareSheetTimeout] 内没回包。`true` 不代表用户完成了分享，
  /// 只代表面板呈现过并已关闭。
  ///
  /// **为什么必须有返回值（BUG-2542）**：手机端的日志导出把产物落在 app 私有
  /// 目录（不进相册、不注册 MediaStore），这次系统分享面板是用户取回文件的
  /// **唯一**通道。旧签名是 `Future<void>`，被丢弃时静默返回，调用方无从得知，
  /// 于是照样弹「已保存」成功提示——面板没出现、相册里没有、私有目录用户进不去，
  /// 文件等于凭空消失。调用方现在据此决定报成功还是报失败。
  static Future<bool> shareFiles(
    List<XFile> files, {
    String? subject,
    String? text,
  }) async {
    if (_sharing || files.isEmpty) {
      _logDroppedShare('shareFiles', reentrant: _sharing);
      return false;
    }
    _sharing = true;
    try {
      await Share.shareXFiles(
        files,
        subject: subject,
        text: text,
        sharePositionOrigin: _sharePositionOrigin(),
      ).timeout(_kShareSheetTimeout);
      return true;
    } on TimeoutException {
      _logShareTimeout('shareFiles');
      return false;
    } finally {
      _sharing = false;
    }
  }

  /// 分享被防重入门丢弃时留一条可查的记录。
  ///
  /// 这条出口从前是裸 `return`，用户报「导出了但什么都没发生」时错误日志页一片
  /// 空白，无从判断是导出失败还是分享被丢弃（BUG-2542）。
  ///
  /// **只记重入**：空输入（`files.isEmpty` / `text.isEmpty`）是调用方自己的空
  /// 调用，没有用户意图被丢掉，记成用户可见「错误」只是噪声（还会顶高日志页的
  /// 错误计数）；重入丢弃才是真把用户要的东西扔了。
  static void _logDroppedShare(String entry, {required bool reentrant}) {
    if (!reentrant) return;
    ErrorLogService.instance.log(
      'FushiShare.$entry',
      'share dropped before reaching the platform: '
          'another share sheet is still open',
      StackTrace.current,
    );
  }

  /// 平台侧在在途上限内没回包。记下来，并让调用方拿到 `false`。
  static void _logShareTimeout(String entry) {
    ErrorLogService.instance.log(
      'FushiShare.$entry',
      'share sheet did not close within $_kShareSheetTimeout; '
          'the reentrancy gate has been released so later shares still work',
      StackTrace.current,
    );
  }
}
