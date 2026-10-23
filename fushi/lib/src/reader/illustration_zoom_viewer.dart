/// 插图全屏缩放查看：阅读器正文点图 / 插图册点大图 / 书架端插图册三处共用的
/// 一条缩放路径（半透明遮罩路由 + [InteractiveViewer] + 点图关闭），以及围绕
/// 「一张磁盘图片文件」的复制 / 分享 / 右键菜单动作。宿主只负责解析出 [File]
/// 并决定要不要挂上下文菜单。
library;

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:fushi/utils.dart';

/// 缩放看图的路由：非不透明、深色 scrim、点 scrim 关闭。[builder] 提供路由
/// 内容（通常是 [IllustrationZoomViewer]，宿主可在外面再包上下文菜单触发口）。
Route<void> illustrationZoomRoute(BuildContext context, WidgetBuilder builder) {
  return PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.87),
    barrierDismissible: true,
    pageBuilder: (BuildContext routeContext, _, __) => builder(routeContext),
  );
}

/// 一张图的缩放查看：点图关闭路由；[onLongPress]（移动端分享）由宿主决定挂不挂。
class IllustrationZoomViewer extends StatelessWidget {
  const IllustrationZoomViewer({
    super.key,
    required this.file,
    required this.diagnosticTag,
    this.onLongPress,
  });

  final File file;

  /// 坏图解码失败写诊断日志时的来源标签。
  final String diagnosticTag;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      onLongPress: onLongPress,
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 10,
        child: Center(
          child: Image.file(
            file,
            fit: BoxFit.contain,
            // BUG-2496：坏图解码失败退回占位图标，不当致命 FlutterError。
            errorBuilder: (_, Object error, __) {
              ErrorLogService.instance.logDiagnostic(
                '$diagnosticTag.coverDecode',
                '${file.path}: $error',
              );
              return const Icon(Icons.broken_image_outlined, size: 64);
            },
          ),
        ),
      ),
    );
  }
}
