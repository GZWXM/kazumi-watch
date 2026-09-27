part of 'source_sheet.dart';

void _showAliasPickerDialog({
  required String sourceName,
  required List<String> aliases,
  required ValueChanged<String> onAliasSelected,
  required VoidCallback onAliasesChanged,
}) {
  KazumiDialog.show(
    builder: (context) => _AliasPickerDialog(
      sourceName: sourceName,
      aliases: aliases,
      onAliasSelected: (alias) {
        KazumiDialog.dismiss();
        onAliasSelected(alias);
      },
      onAliasesChanged: onAliasesChanged,
    ),
  );
}

void _showCustomKeywordDialog({
  required ValueChanged<String> onSubmit,
  required String initialKeyword,
  required String sourceName,
}) {
  String keyword = initialKeyword;

  void submit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    KazumiDialog.dismiss();
    onSubmit(trimmed);
  }

  KazumiDialog.show(
    builder: (context) {
      // 圆表：对话框盒只有 153×185（233 − insetPadding 40/24），标题+输入框+两枚
      // 竖排动作 ≈350dp → 动作落到框外、命中测试以父盒为界 → 够不着；而且小输入框
      // 在圆屏上本来就点不准 ⇒ 圆屏改整屏编辑（内缩只在整屏骨架里那一处）。
      if (isRoundWatch(MediaQuery.sizeOf(context))) {
        return WatchTextEditor(
          title: '修改检索词',
          initialValue: initialKeyword,
          labelText: '检索关键词',
          helperText: '仅检索来源：$sourceName',
          confirmText: '检索',
          validator: (value) =>
              (value ?? '').trim().isEmpty ? '请输入检索关键词' : null,
          onConfirmed: (value) => onSubmit(value.trim()),
        );
      }
      return AlertDialog(
      // 圆表：对话框盒只有 153×185（233 − insetPadding 40/24），
      // 标题+输入框+两枚竖排动作 ≈350dp → 动作会落到框外、命中测试以父盒为界 → 够不着。
      // 与同库 _VerifyDialogFrame（source_captcha_flow.dart:122）同口径打开 scrollable。
      scrollable: true,
      title: const Text('修改检索词'),
      content: TextFormField(
        initialValue: initialKeyword,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          labelText: '检索关键词',
          helperText: '仅检索来源：$sourceName',
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) => keyword = value,
        onFieldSubmitted: submit,
      ),
      actions: [
        TextButton(
          onPressed: KazumiDialog.dismiss,
          child: Text(
            '取消',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        TextButton(
          onPressed: () => submit(keyword),
          child: const Text('检索'),
        ),
      ],
      );
    },
  );
}

class _AliasPickerDialog extends StatefulWidget {
  const _AliasPickerDialog({
    required this.sourceName,
    required this.aliases,
    required this.onAliasSelected,
    required this.onAliasesChanged,
  });

  final String sourceName;
  final List<String> aliases;
  final ValueChanged<String> onAliasSelected;
  final VoidCallback onAliasesChanged;

  @override
  State<_AliasPickerDialog> createState() => _AliasPickerDialogState();
}

class _AliasPickerDialogState extends State<_AliasPickerDialog> {
  void _confirmDelete(int index) {
    KazumiDialog.show(
      builder: (context) => AlertDialog(
        // 同上：圆表 153×185 装不下标题+说明+竖排动作（≈208dp），动作会落到框外
        scrollable: true,
        title: const Text('删除确认'),
        content: const Text('删除后无法恢复，确认要永久删除这个别名吗？'),
        actions: [
          TextButton(
            onPressed: KazumiDialog.dismiss,
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () {
              KazumiDialog.dismiss();
              // Aliases are shared across source rules.
              setState(() => widget.aliases.removeAt(index));
              widget.onAliasesChanged();
              if (widget.aliases.isEmpty) {
                Navigator.of(this.context).pop();
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 圆表：560 的硬宽会被夹到 233−2×24=185，再减左右各 24 只剩 137dp 的行宽；
    // 圆屏改走整屏骨架（内缩只在整屏骨架里那一处），行高按 ListTile 默认 ≥48dp。
    if (isRoundWatch(MediaQuery.sizeOf(context))) {
      return WatchFullscreenDialog(
        title: '别名检索',
        onClose: () => Navigator.of(context).maybePop(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '仅检索来源：${widget.sourceName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < widget.aliases.length; index++)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(widget.aliases[index]),
                trailing: IconButton(
                  onPressed: () => _confirmDelete(index),
                  icon: const Icon(Icons.delete),
                ),
                onTap: () => widget.onAliasSelected(widget.aliases[index]),
              ),
          ],
        ),
      );
    }
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 560,
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('别名检索', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    '仅检索来源：${widget.sourceName}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            for (var index = 0; index < widget.aliases.length; index++)
              ListTile(
                title: Text(widget.aliases[index]),
                trailing: IconButton(
                  onPressed: () => _confirmDelete(index),
                  icon: const Icon(Icons.delete),
                ),
                onTap: () => widget.onAliasSelected(widget.aliases[index]),
              ),
          ],
        ),
      ),
    );
  }
}
