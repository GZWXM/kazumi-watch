import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import 'package:kazumi/bean/widget/content_section.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/bean/widget/watch_text_input.dart';
import 'package:kazumi/pages/my/my_controller.dart';
import 'package:kazumi/utils/device.dart';

class DanmakuShieldEditor extends StatefulWidget {
  const DanmakuShieldEditor({
    super.key,
    required this.controller,
    this.padding = const EdgeInsets.fromLTRB(24, 0, 24, 24),
  });

  final MyController controller;
  final EdgeInsetsGeometry padding;

  @override
  State<DanmakuShieldEditor> createState() => _DanmakuShieldEditorState();
}

class _DanmakuShieldEditorState extends State<DanmakuShieldEditor> {
  MyController get myController => widget.controller;
  final TextEditingController textEditingController = TextEditingController();

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }

  Future<void> _addRule() async {
    final rule = textEditingController.text.trim();
    if (rule.isEmpty) return;
    final added = await myController.addShieldList(rule);
    if (mounted && added && textEditingController.text.trim() == rule) {
      textEditingController.clear();
    }
  }

  /// 圆表：输入框换成「点一行 → 整屏编辑」。校验/去重仍由
  /// [MyController.addShieldList] 负责（内含 toast 提示）。
  Future<void> _addRuleViaEditor() async {
    final rule = await showWatchTextEditor(
      context,
      title: '添加屏蔽规则',
      labelText: '关键词或 /正则表达式/',
      hintText: '例如：前方高能 或 /^.*广告.*\$/',
      helperText: '包含关键词的弹幕会被隐藏。用 / / 包裹正则表达式。',
      validator: (value) => (value ?? '').trim().isEmpty ? '请输入关键词' : null,
    );
    if (rule == null) return;
    await myController.addShieldList(rule.trim());
  }

  @override
  Widget build(BuildContext context) {
    // 圆表：本组件要么被 180dp 的圆屏路由（danmaku_shield_settings.dart）包着，
    // 要么被 170dp 的圆屏 sheet 对话框（DanmakuShieldSettingsSheet）包着 ——
    // 宽度已经约束好了，这里左右 padding 必须归零（内缩只能有一处，双重内缩会把
    // 行压窄、滚动行为也错乱），只留一点上下呼吸区。
    final round = isRoundWatch(MediaQuery.sizeOf(context));
    return ListView(
      padding: round ? const EdgeInsets.fromLTRB(0, 0, 0, 24) : widget.padding,
      children: [
        ContentSection(
          title: '添加规则',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (round)
              WatchInputRow(
                label: '关键词或 /正则表达式/',
                hint: '点这里输入',
                icon: Icons.add_rounded,
                onTap: _addRuleViaEditor,
              )
            else
              TextField(
                controller: textEditingController,
                decoration: InputDecoration(
                  hintText: '关键词或 /正则表达式/',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                  suffixIcon: IconButton(
                    tooltip: '添加规则',
                    onPressed: _addRule,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ),
                onSubmitted: (_) => _addRule(),
              ),
            const SizedBox(height: 8),
            Text('包含关键词的弹幕会被隐藏。用 / / 包裹正则表达式。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
          ]),
        ),
        const SizedBox(height: 24),
        Observer(builder: (context) {
          final rules = myController.shieldList.toList();
          if (rules.isEmpty) {
            return const GeneralEmptyState(
              icon: Icons.filter_alt_off_rounded,
              title: '还没有屏蔽规则',
              compact: true,
            );
          }
          return ContentSection.group(
            title: '已添加 · ${rules.length}',
            children: [
              for (final rule in rules)
                ListTile(
                  title: Text(rule),
                  subtitle: rule.startsWith('/') && rule.endsWith('/')
                      ? const Text('正则表达式')
                      : null,
                  trailing: IconButton(
                    tooltip: '删除规则',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => myController.removeShieldList(rule),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}
