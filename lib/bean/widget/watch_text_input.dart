import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kazumi/bean/widget/circle_insets.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';

/// 圆屏文本输入的统一入口。
///
/// 几何口径（唯一事实来源 [CircleInsets]，屏 233×233、R=116.5）：
/// body 可视带 y∈[44, 188]，带内最窄处取 y=44 → 弦 182.4 → 单侧内缩
/// `CircleInsets.bandInset(bodyTop)` ≈ 31 就是「圆的内接矩形」宽 171；底部留 45
/// （独立路由 / 自建对话框拿不到 menu 注入的 93，口径同 WatchScaffold:39-40）。
///
/// 于是圆屏上不摆行内小输入框（点不准、键盘一弹又把行顶到圆边外），改成
/// 「点一行（≥48dp）→ 弹出整屏编辑」：[WatchInputRow] 只负责那一行，
/// [showWatchTextEditor] 负责整屏编辑页。
///
/// 注意：整屏编辑只有**这一处**内缩（水平 31 + 底部 45）。外面不要再叠
/// padding，否则就是双重内缩（行变窄、滚动行为错乱）。

/// 圆屏整屏对话框骨架：标题带（返回 + 标题 + 可选动作）+ 可滚动内容。
///
/// 为什么动作行放在**滚动内容里**而不是钉在底部：圆表上键盘弹起时
/// `Dialog.fullscreen` 会被 `AnimatedPadding(viewInsets)` 顶掉半屏
/// （233−IME≈117dp），钉底的动作行 + 标题带比剩余高度还高 → RenderFlex 溢出。
/// 放进滚动区后，标题带恒为 ~52dp，任何高度都不会溢出；[headerActions] 还能
/// 让主操作（保存/检索）在标题带里随手可点，不必先滚到底。
///
/// 自建 Dialog 在圆表上默认会挤成 233−insetPadding 的小框（例如 153×185），
/// 内容与动作落到圆边外、命中测试以父盒为界 → 够不着。所以统一走这个骨架。
class WatchFullscreenDialog extends StatelessWidget {
  const WatchFullscreenDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.headerActions = const [],
    this.onClose,
    this.leadingIcon = Icons.arrow_back,
    this.closeTooltip = '返回',
  });

  /// 标题（单行省略）
  final String title;

  /// 主内容，自动包在可滚动区域里
  final Widget child;

  /// 内容末尾的动作行（按钮建议 minimumSize 高度 ≥48）
  final List<Widget> actions;

  /// 标题带右侧的动作（建议 44×44 图标按钮；只取第一个，保证标题居中）
  final List<Widget> headerActions;

  /// 左上角按钮回调；为 null 时左上角留白占位
  final VoidCallback? onClose;

  final IconData leadingIcon;
  final String closeTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final mq = MediaQuery.of(context);

    // 水平：圆带最窄处内缩，左右各一份；底部：补齐不足 45 的部分。
    final double inset = CircleInsets.bandInset(CircleInsets.bodyTop);
    final double bottomReserve =
        mq.padding.bottom < 45 ? 45 - mq.padding.bottom : 0;

    return Dialog.fullscreen(
      backgroundColor: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: onClose == null
                        ? null
                        : IconButton(
                            tooltip: closeTooltip,
                            onPressed: onClose,
                            icon: Icon(leadingIcon),
                          ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: headerActions.isEmpty ? null : headerActions.first,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding:
                    EdgeInsets.fromLTRB(inset, 8, inset, bottomReserve + 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    child,
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: actions,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 圆屏「点一行 → 整屏编辑」里的那一行：标签 + 当前值 + 编辑图标，
/// 触区高度 ≥48dp（圆表上手指落点）。
class WatchInputRow extends StatelessWidget {
  const WatchInputRow({
    super.key,
    required this.label,
    required this.onTap,
    this.value,
    this.hint,
    this.icon = Icons.edit_rounded,
    this.enabled = true,
  });

  /// 字段名
  final String label;

  /// 当前值；null/空串显示 [hint]（或「未设置」）
  final String? value;

  /// 空值时的占位文案
  final String? hint;

  /// 右侧图标
  final IconData icon;

  final bool enabled;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final String? current = (value == null || value!.isEmpty) ? null : value;
    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        current ?? (hint ?? '未设置'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: current == null
                              ? colors.onSurfaceVariant
                              : colors.onSurface,
                          fontStyle:
                              current == null ? FontStyle.italic : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  icon,
                  size: 20,
                  color: enabled ? colors.primary : colors.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 整屏文本编辑页（圆表）：返回值 = 确认后的文本，取消/返回 = null。
///
/// 只会内缩一处（[WatchFullscreenDialog] 里那处），调用方不要再套 padding。
Future<String?> showWatchTextEditor(
  BuildContext context, {
  required String title,
  String initialValue = '',
  String? labelText,
  String? hintText,
  String? helperText,
  String? Function(String?)? validator,
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
  bool obscureText = false,
  bool autocorrect = true,
  int maxLines = 1,
  int? maxLength,
  String confirmText = '完成',
  ValueChanged<String>? onConfirmed,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => WatchTextEditor(
      title: title,
      initialValue: initialValue,
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      autocorrect: autocorrect,
      maxLines: maxLines,
      maxLength: maxLength,
      confirmText: confirmText,
      onConfirmed: onConfirmed,
    ),
  );
}

/// 整屏编辑页本体：给「自己管路由」的调用方（例如 KazumiDialog.show / 任务对话框）
/// 直接嵌进 route 用；[showWatchTextEditor] 只是它 + showDialog 的语法糖。
///
/// 确认时先 pop 掉当前 route（值 = 文本），再调 [onConfirmed]（如果给了）。
class WatchTextEditor extends StatefulWidget {
  const WatchTextEditor({
    super.key,
    required this.title,
    this.initialValue = '',
    this.labelText,
    this.hintText,
    this.helperText,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.autocorrect = true,
    this.maxLines = 1,
    this.maxLength,
    this.confirmText = '完成',
    this.onConfirmed,
  });

  final String title;
  final String initialValue;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool autocorrect;
  final int maxLines;
  final int? maxLength;
  final String confirmText;
  final ValueChanged<String>? onConfirmed;

  @override
  State<WatchTextEditor> createState() => _WatchTextEditorState();
}

class _WatchTextEditorState extends State<WatchTextEditor> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  String? _error;

  bool get _multiline => widget.maxLines > 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final String value = _controller.text;
    final validator = widget.validator;
    if (validator != null) {
      final String? error = validator(value);
      if (error != null) {
        setState(() => _error = error);
        return;
      }
    }
    Navigator.of(context).pop(value);
    widget.onConfirmed?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return WatchFullscreenDialog(
      title: widget.title,
      onClose: () => Navigator.of(context).pop(),
      // 主操作放在标题带里：键盘弹起时整屏只剩 ≈117dp，钉底按钮会被顶出屏外，
      // 标题带里的 ✓ 随手可点（IME 的「完成」键也走 onSubmitted → _confirm）。
      headerActions: [
        IconButton(
          tooltip: widget.confirmText,
          onPressed: _confirm,
          icon: const Icon(Icons.check_rounded),
        ),
      ],
      actions: [
        StateActionButton(
          onPressed: _confirm,
          text: widget.confirmText,
          icon: Icons.check_rounded,
        ),
      ],
      child: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        obscureText: widget.obscureText,
        autocorrect: widget.autocorrect,
        enableSuggestions: !widget.obscureText,
        maxLength: widget.maxLength,
        minLines: _multiline ? widget.maxLines : null,
        maxLines: widget.maxLines,
        textInputAction:
            _multiline ? TextInputAction.newline : TextInputAction.done,
        onSubmitted: _multiline ? null : (_) => _confirm(),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          helperText: widget.helperText,
          helperMaxLines: 3,
          errorText: _error,
          errorMaxLines: 3,
          alignLabelWithHint: _multiline,
          suffixIcon: _multiline
              ? IconButton(
                  tooltip: widget.confirmText,
                  onPressed: _confirm,
                  icon: const Icon(Icons.add_rounded),
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
