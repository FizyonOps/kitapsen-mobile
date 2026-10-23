import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fushi/utils.dart';

class SettingsSecretField extends StatefulWidget {
  const SettingsSecretField({
    super.key,
    required this.title,
    required this.icon,
    required this.initialValue,
    required this.onChanged,
    this.obscureText = false,
    this.revealToggle = false,
    this.keyboardType = TextInputType.text,
    this.hintText,
    this.subtitle,
    this.showIcon = false,
    this.debounce = const Duration(milliseconds: 500),
    this.resetValue,
    this.onReset,
  });

  final String title;
  final IconData? icon;
  final String initialValue;
  final bool obscureText;

  /// true 时在行尾提供眼睛按钮切换 [obscureText] 的显隐（SettingsTextItem 的
  /// secret 走此路径）；false 保持既有调用点行为（固定遮蔽、无切换）。
  final bool revealToggle;
  final TextInputType keyboardType;

  /// 可选占位提示（传给内部 TextField 的 decoration.hintText）。null = 不显示提示。
  final String? hintText;
  final String? subtitle;
  final bool showIcon;

  /// 击键到 [onChanged] 的防抖间隔；[Duration.zero] = 立即写。提交（回车）恒立即写。
  final Duration debounce;

  /// 非 null（连同 [onReset]）时行尾提供重置按钮：回填输入框 + 触发 [onReset]。
  final String? resetValue;
  final VoidCallback? onReset;
  final Future<void> Function(String value) onChanged;

  @override
  State<SettingsSecretField> createState() => SettingsSecretFieldState();
}

class SettingsSecretFieldState extends State<SettingsSecretField> {
  late final TextEditingController _controller;
  late bool _obscured;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _obscured = widget.obscureText;
  }

  @override
  void dispose() {
    // 防抖窗口内关页不丢输入：还有 pending 写入（timer 未触发）时同步冲刷最新
    // 文本再销毁。[SettingsSecretField.onChanged] 是纯写穿闭包、不依赖本 widget
    // 树，dispose 后触发安全。
    if (_debounce?.isActive ?? false) {
      unawaited(widget.onChanged(_controller.text));
    }
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleChanged(String value) {
    _debounce?.cancel();
    if (widget.debounce == Duration.zero) {
      unawaited(widget.onChanged(value));
      return;
    }
    _debounce = Timer(widget.debounce, () {
      unawaited(widget.onChanged(value));
    });
  }

  void _submit(String value) {
    _debounce?.cancel();
    unawaited(widget.onChanged(value));
  }

  Widget? _suffix() {
    final List<Widget> actions = <Widget>[
      if (widget.revealToggle)
        FushiIconButton(
          tooltip: _obscured ? t.settings_secret_show : t.settings_secret_hide,
          size: 18,
          icon: _obscured
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          onTap: () => setState(() => _obscured = !_obscured),
        ),
    ];
    if (actions.isEmpty) return null;
    if (actions.length == 1) return actions.single;
    return Row(mainAxisSize: MainAxisSize.min, children: actions);
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveSettingsRow(
      title: widget.title,
      subtitle: widget.subtitle,
      icon: widget.icon,
      showIcon: widget.showIcon,
      controlBelow: true,
      trailing: AdaptiveSettingsTextField(
        controller: _controller,
        obscureText: _obscured,
        keyboardType: widget.keyboardType,
        textInputAction: TextInputAction.done,
        labelText: widget.title,
        hintText: widget.hintText,
        suffixIcon: _suffix(),
        onChanged: _scheduleChanged,
        onSubmitted: _submit,
      ),
    );
  }
}
