import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/card/rule_card.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/circle_insets.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/bean/widget/watch_text_input.dart';
import 'package:kazumi/modules/plugin/plugin_http_module.dart';
import 'package:kazumi/pages/plugin_editor/plugin_update_actions.dart';
import 'package:kazumi/pages/plugin_editor/rule_management_widgets.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/device.dart';

enum _CatalogSort { lastUpdate, name }

enum _CatalogFilter { all, installed, updates }

class PluginCatalogView extends StatefulWidget {
  const PluginCatalogView({
    super.key,
    required this.controller,
  }) : _scrollViewBuilder = null;

  const PluginCatalogView.onboarding({
    super.key,
    required this.controller,
    required Widget Function(BuildContext context, List<Widget> slivers)
        builder,
  }) : _scrollViewBuilder = builder;

  final PluginsController controller;
  final Widget Function(BuildContext context, List<Widget> slivers)?
      _scrollViewBuilder;

  bool get _onboarding => _scrollViewBuilder != null;

  @override
  State<PluginCatalogView> createState() => _PluginCatalogViewState();
}

class _PluginCatalogViewState extends State<PluginCatalogView> {
  final _search = TextEditingController();
  final Set<String> _installing = {};
  _CatalogSort _sort = _CatalogSort.lastUpdate;
  _CatalogFilter _filter = _CatalogFilter.all;
  bool _loading = true;
  bool _loadFailed = false;

  PluginsController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    if (_controller.isPluginCatalogFresh) {
      _loading = false;
    } else {
      unawaited(_loadPluginCatalog());
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadPluginCatalog({bool forceRefresh = false}) async {
    try {
      if (forceRefresh) {
        await _controller.refreshPluginCatalog();
      } else {
        await _controller.ensurePluginCatalog();
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  void _refresh() {
    if (_loading) return;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    unawaited(_loadPluginCatalog(forceRefresh: true));
  }

  Future<void> _toggleGitProxyAndRefresh() async {
    try {
      final enabled = GStorage.getSetting(SettingsKeys.enableGitProxy);
      await GStorage.putSetting(SettingsKeys.enableGitProxy, !enabled);
      if (mounted) _refresh();
    } catch (_) {
      KazumiDialog.showToast(message: '切换规则镜像失败，请重试');
    }
  }

  Future<void> _install(
      PluginHTTPItem item, PluginCatalogItemStatus status) async {
    if (!_installing.add(item.name)) return;
    setState(() {});
    try {
      await updatePluginWithFeedback(_controller, item.name,
          installing: status == PluginCatalogItemStatus.install);
    } finally {
      if (mounted) setState(() => _installing.remove(item.name));
    }
  }

  /// 圆表：可用宽只有 233−2×31（或 170 的对话框）里的一小段，小搜索框点不准
  /// ⇒ 点一行弹整屏编辑；清空内容再确认 = 显示全部（等价于原来的清除按钮）。
  Future<void> _searchViaEditor() async {
    final value = await showWatchTextEditor(
      context,
      title: '搜索规则',
      initialValue: _search.text,
      labelText: '关键词',
      hintText: '规则名或作者，清空则显示全部',
    );
    if (value == null || !mounted) return;
    setState(() => _search.text = value);
  }

  List<PluginHTTPItem> _visibleItems() {
    final query = _search.text.trim().toLowerCase();
    final items = _controller.pluginHTTPList.where((item) {
      final status = _controller.pluginStatus(item);
      return (item.name.toLowerCase().contains(query) ||
              item.author.toLowerCase().contains(query)) &&
          switch (_filter) {
            _CatalogFilter.all => true,
            _CatalogFilter.installed =>
              status != PluginCatalogItemStatus.install,
            _CatalogFilter.updates => status == PluginCatalogItemStatus.update,
          };
    }).toList();
    switch (_sort) {
      case _CatalogSort.lastUpdate:
        items.sort((a, b) => b.lastUpdate.compareTo(a.lastUpdate));
      case _CatalogSort.name:
        items.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return items;
  }

  Widget _sortButton() => MenuAnchor(
        builder: (context, controller, _) => TextButton.icon(
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          icon: const Icon(Icons.sort_rounded, size: 20),
          label: Text(_sort == _CatalogSort.name ? '名称排序' : '最近更新'),
        ),
        menuChildren: [
          for (final sort in _CatalogSort.values)
            MenuItemButton(
              leadingIcon: Icon(
                  _sort == sort ? Icons.check_rounded : Icons.sort_rounded),
              onPressed: () => setState(() => _sort = sort),
              child: Text(sort == _CatalogSort.name ? '按名称排序' : '按更新时间排序'),
            ),
        ],
      );

  Widget _header(int total, int installed, int updates) {
    final theme = Theme.of(context);
    final round = isRoundWatch(MediaQuery.sizeOf(context));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!widget._onboarding) ...[
        const RulePageIntro(
          title: '发现更多来源',
          description: '浏览社区规则，为你的番剧搜索添加更多选择。',
          icon: Icons.travel_explore_rounded,
        ),
        const SizedBox(height: 20),
        if (round)
          WatchInputRow(
            label: '搜索规则或作者',
            value: _search.text.trim().isEmpty ? null : _search.text,
            hint: '点这里输入关键词',
            icon: Icons.search_rounded,
            onTap: _searchViaEditor,
          )
        else
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: ruleInputDecoration(context,
                hint: '搜索规则或作者',
                prefix: const Icon(Icons.search_rounded),
                suffix: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清除搜索',
                        onPressed: () => setState(_search.clear),
                        icon: const Icon(Icons.close_rounded))),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final entry in [
              (_CatalogFilter.all, '全部 $total'),
              (_CatalogFilter.installed, '已安装 $installed'),
              (_CatalogFilter.updates, '可更新 $updates'),
            ])
              FilterChip(
                  label: Text(entry.$2),
                  selected: _filter == entry.$1,
                  onSelected: (_) => setState(() => _filter = entry.$1)),
          ],
        ),
      ],
      Row(children: [
        if (widget._onboarding)
          Expanded(
            child: Text('规则仓库 · 已安装 $installed',
                style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600)),
          )
        else ...[
          _sortButton(),
          const Spacer(),
        ],
        IconButton.filledTonal(
            tooltip: '刷新规则列表',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded)),
      ]),
      if (_loading && total > 0)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator()),
      if (_loadFailed && total > 0)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('刷新失败，正在显示上次获取的规则。', style: theme.textTheme.bodySmall)),
      const SizedBox(height: 8),
    ]);
  }

  Widget _emptyBody() {
    // 圆表：48dp 内边距会把空态/加载态撑出 170dp 的内容盒。
    final round = isRoundWatch(MediaQuery.sizeOf(context));
    if (_loading) {
      return Padding(
          padding: EdgeInsets.all(round ? 16 : 48),
          child: const Center(child: LoadingIndicator()));
    }
    if (_loadFailed && _controller.pluginHTTPList.isEmpty) {
      final enabled = GStorage.getSetting(SettingsKeys.enableGitProxy);
      return GeneralErrorWidget(
        title: '无法访问规则仓库',
        errMsg: '请检查网络连接，或切换规则仓库镜像后重试。',
        icon: Icons.cloud_off_rounded,
        onRetry: _refresh,
        retryText: '重新加载',
        actions: [
          StateActionButton.tonal(
            onPressed: _toggleGitProxyAndRefresh,
            icon: Icons.tune_rounded,
            text: enabled ? '关闭规则镜像' : '启用规则镜像',
          ),
        ],
      );
    }
    return GeneralEmptyState(
      title: _controller.pluginHTTPList.isEmpty ? '仓库暂无规则' : '没有符合条件的规则',
      icon: _controller.pluginHTTPList.isEmpty
          ? Icons.extension_rounded
          : Icons.search_off_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 圆表：本视图挂在独立路由（plugin_shop_page → Scaffold + SysAppBar）下，
    // 拿不到 watch shell 注入的 93 底部安全区，横向上也只允许一处内缩。
    final round = isRoundWatch(MediaQuery.sizeOf(context));
    final double roundInset = CircleInsets.bandInset(CircleInsets.bodyTop);
    return Observer(builder: (context) {
        final colors = Theme.of(context).colorScheme;
        final catalog = _controller.pluginHTTPList.toList();
        final installed = catalog
            .where((p) =>
                _controller.pluginStatus(p) != PluginCatalogItemStatus.install)
            .length;
        final updates = catalog
            .where((p) =>
                _controller.pluginStatus(p) == PluginCatalogItemStatus.update)
            .length;
        final items = _visibleItems();
        final slivers = <Widget>[
          SliverPadding(
            // 圆表：横向内缩只留这一处 —— 取 body 带最窄处（y=44）的圆弦内缩
            // （≈31 ⇒ 行宽 171，是这条带的内接矩形，宁可内接也不铺满裁边）；
            // 底部补到 45，替代拿不到的 shell 93 注入。
            padding: widget._onboarding
                ? EdgeInsets.zero
                : (round
                    ? EdgeInsets.fromLTRB(roundInset, 12, roundInset, 45)
                    : const EdgeInsets.fromLTRB(16, 12, 16, 24)),
            sliver: SliverMainAxisGroup(slivers: [
              SliverToBoxAdapter(
                  child: _header(catalog.length, installed, updates)),
              if (items.isEmpty)
                SliverToBoxAdapter(child: _emptyBody())
              else
                SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final status = _controller.pluginStatus(item);
                    final busy = _installing.contains(item.name);
                    return RuleCard(
                      key: ValueKey(item.name),
                      title: item.name,
                      installed: status == PluginCatalogItemStatus.installed,
                      subtitle:
                          item.author.isEmpty ? null : '作者 · ${item.author}',
                      tags: [
                        RuleTag(
                            label: item.version,
                            background: colors.surfaceContainerHighest,
                            foreground: colors.onSurfaceVariant),
                        if (item.antiCrawlerEnabled)
                          RuleTag(
                              label: '含验证支持',
                              background: colors.tertiaryContainer,
                              foreground: colors.onTertiaryContainer),
                      ],
                      caption: item.lastUpdate > 0
                          ? '更新于 ${DateTime.fromMillisecondsSinceEpoch(item.lastUpdate).toString().split(' ').first}'
                          : null,
                      trailing: _CatalogRuleAction(
                        status: status,
                        busy: busy,
                        onPressed: () => _install(item, status),
                      ),
                    );
                  },
                ),
            ]),
          ),
        ];
        return widget._scrollViewBuilder?.call(context, slivers) ??
            CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: slivers,
            );
      });
  }
}

class _CatalogRuleAction extends StatelessWidget {
  const _CatalogRuleAction({
    required this.status,
    required this.busy,
    required this.onPressed,
  });

  final PluginCatalogItemStatus status;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (!busy && status == PluginCatalogItemStatus.installed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_rounded, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: 6),
          Text('已安装',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: colors.onSurfaceVariant)),
        ]),
      );
    }
    final installing = status == PluginCatalogItemStatus.install;
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        minimumSize: const Size(108, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      onPressed: busy ? null : onPressed,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (busy)
          const LoadingIndicator(size: 20)
        else
          Icon(installing ? Icons.add_rounded : Icons.sync_rounded, size: 18),
        const SizedBox(width: 6),
        Text(installing ? (busy ? '安装中' : '安装') : (busy ? '更新中' : '更新')),
      ]),
    );
  }
}
