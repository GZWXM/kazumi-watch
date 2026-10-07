import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/settings/settings_list.dart';
import 'package:kazumi/bean/widget/content_section.dart';
import 'package:kazumi/bean/widget/watch_list.dart';
import 'package:kazumi/bean/widget/watch_scaffold.dart';
import 'package:kazumi/pages/settings/player_settings.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/device.dart';

class _SettingsCategory {
  const _SettingsCategory({
    required this.label,
    required this.description,
    required this.icon,
    required this.path,
  });

  final String label;
  final String description;
  final IconData icon;
  final String path;
}

class _SettingsGroup {
  const _SettingsGroup({required this.title, required this.categories});

  final String title;
  final List<_SettingsCategory> categories;
}

const List<_SettingsGroup> _settingsGroups = [
  _SettingsGroup(
    title: '播放',
    categories: [
      _SettingsCategory(
        label: '播放设置',
        description: '解码、渲染与播放行为',
        icon: Icons.display_settings_rounded,
        path: '/settings/player',
      ),
      _SettingsCategory(
        label: '弹幕设置',
        description: '弹幕来源与显示效果',
        icon: Icons.subtitles_rounded,
        path: '/settings/danmaku',
      ),
      _SettingsCategory(
        label: '操作设置',
        description: '播放器按键映射',
        icon: Icons.keyboard_rounded,
        path: '/settings/keyboard',
      ),
    ],
  ),
  _SettingsGroup(
    title: '资源',
    categories: [
      _SettingsCategory(
        label: '规则管理',
        description: '番剧资源规则',
        icon: Icons.extension_rounded,
        path: '/settings/plugin',
      ),
      _SettingsCategory(
        label: '下载设置',
        description: '并发数与弹幕缓存',
        icon: Icons.downloading_rounded,
        path: '/settings/download-settings',
      ),
    ],
  ),
  _SettingsGroup(
    title: '应用',
    categories: [
      _SettingsCategory(
        label: '外观设置',
        description: '主题、配色与字体',
        icon: Icons.palette_rounded,
        path: '/settings/theme',
      ),
      _SettingsCategory(
        label: '界面设置',
        description: '启动、窗口行为与展示信息',
        icon: Icons.pages_rounded,
        path: '/settings/interface',
      ),
      _SettingsCategory(
        label: '同步设置',
        description: '追番状态与多设备同步',
        icon: Icons.cloud_rounded,
        path: '/settings/sync',
      ),
      _SettingsCategory(
        label: '网络设置',
        description: '访问加速与代理',
        icon: Icons.language_rounded,
        path: '/settings/proxy',
      ),
    ],
  ),
  _SettingsGroup(
    title: '其他',
    categories: [
      _SettingsCategory(
        label: '更新设置',
        description: '应用与规则更新',
        icon: Icons.update_rounded,
        path: '/settings/update',
      ),
      _SettingsCategory(
        label: '存储与日志',
        description: '图片缓存与错误日志',
        icon: Icons.storage_rounded,
        path: '/settings/storage',
      ),
      _SettingsCategory(
        label: '关于',
        description: '版本与开源信息',
        icon: Icons.info_outline_rounded,
        path: '/settings/about',
      ),
    ],
  ),
];

String _normalizePath(String path) =>
    path.endsWith('/') ? path.substring(0, path.length - 1) : path;

bool _isWithinPath(String location, String path) =>
    location == path || location.startsWith('$path/');

String _categoryPath(String location) {
  if (location == '/settings') {
    return '/settings/player';
  }
  if (_isWithinPath(location, '/settings/bangumi') ||
      _isWithinPath(location, '/settings/webdav')) {
    return '/settings/sync';
  }
  for (final group in _settingsGroups) {
    for (final category in group.categories) {
      if (_isWithinPath(location, category.path)) {
        return category.path;
      }
    }
  }
  return location;
}

class _SettingsCategorySelected extends Notification {
  const _SettingsCategorySelected(this.path);

  final String path;
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.location});

  final String location;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _outletKey = GlobalKey<RouterOutletState>();
  Object? _categoryNavigation;
  // Nested pushes do not update the root route state.
  late String _location = _normalizePath(widget.location);

  String get _selectedCategoryPath => _categoryPath(_location);
  bool get _isSecondaryRoute =>
      _location != '/settings' && _location != _selectedCategoryPath;

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      _categoryNavigation = null;
      _location = _normalizePath(widget.location);
    }
  }

  void _replaceCategory(String path) {
    _categoryNavigation = null;
    _outletKey.currentState!.navigate(path);
    setState(() => _location = _normalizePath(path));
  }

  Future<void> _pushCategory(String path) async {
    if (_categoryNavigation != null) return;
    final navigation = Object();
    final previousLocation = _location;
    _categoryNavigation = navigation;
    setState(() => _location = _normalizePath(path));
    await _outletKey.currentState!.push<void>(path);
    // Ignore completions from history replaced by a rail selection.
    if (!mounted || _categoryNavigation != navigation) return;
    setState(() {
      _categoryNavigation = null;
      _location = previousLocation;
    });
  }

  void _goBack() {
    if (_outletKey.currentState?.maybePop() ?? false) return;
    _exitSettings();
  }

  void _exitSettings() {
    if (!context.maybePop()) context.navigate('/tab/my');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > LayoutBreakpoint.compact['width']!;
      // 圆屏：索引页与各子页各自带 WatchScaffold（含自己的顶部 44 / 底部保留区内缩），
      // 这里再包一层 Scaffold + SafeArea 会出现双层内缩把内容压扁，所以圆屏只留路由容器。
      // wide 与 round 互斥（233dp 圆屏必然窄于 compact 断点），宽屏双栏逻辑不受影响。
      final round = isRoundWatch(MediaQuery.sizeOf(context));

      final pane = SettingsPaneScope(
        embedded: wide,
        showBackButton: _isSecondaryRoute,
        onBack: _goBack,
        child: NotificationListener<_SettingsCategorySelected>(
          onNotification: (notification) {
            _pushCategory(notification.path);
            return true;
          },
          child: Theme(
            data: Theme.of(context).copyWith(
              pageTransitionsTheme: settingsPageTransitionsTheme,
            ),
            child: RouterOutlet(key: _outletKey),
          ),
        ),
      );

      Widget body;
      if (round) {
        // 只给背景与 Material 祖先：不加 SafeArea/appBar，避免和 WatchScaffold 的内缩叠加。
        body = Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: pane,
        );
      } else {
        body = Scaffold(
          appBar: wide
              ? SysAppBar(
                  title: const Text('设置'),
                  leading: BackButton(onPressed: _exitSettings),
                )
              : null,
          body: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Keep the outlet at the same tree position on resize.
                SizedBox(
                  width: wide ? 280 : 0,
                  child: Offstage(
                    offstage: !wide,
                    child: _SettingsMenu(
                      wide: true,
                      selectedPath: _selectedCategoryPath,
                      onSelect: _replaceCategory,
                    ),
                  ),
                ),
                Expanded(child: pane),
              ],
            ),
          ),
        );
      }

      return NavigatorPopHandler<Object?>(
        onPopWithResult: (_) => _goBack(),
        child: body,
      );
    });
  }
}

class SettingsIndexPage extends StatelessWidget {
  const SettingsIndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (SettingsPaneScope.of(context)?.embedded ?? false) {
      return const PlayerSettingsPage();
    }
    // 圆屏：整屏交给 WatchBandList（圆弦内缩只由它负责），标题带由 WatchScaffold 画。
    // 手机分支保持原来的 Scaffold + 分组卡片。
    if (isRoundWatch(MediaQuery.sizeOf(context))) {
      return WatchScaffold(
        title: '设置',
        leading: IconButton(
          onPressed: () {
            if (!context.maybePop()) context.navigate('/tab/my');
          },
          icon: const Icon(Icons.arrow_back),
        ),
        child: _SettingsBandMenu(
          onSelect: (path) => _SettingsCategorySelected(path).dispatch(context),
        ),
      );
    }
    return Scaffold(
      appBar: SysAppBar(
        title: const Text('设置'),
        leading: BackButton(onPressed: () {
          if (!context.maybePop()) context.navigate('/tab/my');
        }),
      ),
      body: _SettingsMenu(
        wide: false,
        onSelect: (path) => _SettingsCategorySelected(path).dispatch(context),
      ),
    );
  }
}

/// 圆屏菜单的一个槽位：分组标题或分类行（WatchBandList 需要「槽位等距/可上报高度」的扁平列表）。
class _BandSlot {
  const _BandSlot.group(this.groupTitle) : category = null;

  const _BandSlot.category(this.category) : groupTitle = null;

  final String? groupTitle;
  final _SettingsCategory? category;

  bool get isGroup => category == null;
}

/// 圆屏设置菜单：把 _settingsGroups 的分组标题 + 分类行拉平成一个 WatchBandList。
/// 分类行数据仍来自 _settingsGroups（单一数据源），所以每个分类的路由都可达。
class _SettingsBandMenu extends StatelessWidget {
  const _SettingsBandMenu({required this.onSelect});

  final ValueChanged<String> onSelect;

  /// 分组标题槽位高度（视觉高 28 + 间距 8）：比分类行矮，视觉上区分「组」。
  /// 必须用 extentOf 上报，否则标题之后的每一行 yTop 会按 pitch 近似算错、圆弦内缩整体偏移。
  static const double _groupSlotHeight = 36;

  /// 分类行槽位高度，与 WatchBandList 的 pitch 一致（WatchRow 自带 44 + 底部 8）。
  static const double _rowSlotHeight = 52;

  @override
  Widget build(BuildContext context) {
    final slots = <_BandSlot>[
      for (final group in _settingsGroups) ...[
        _BandSlot.group(group.title),
        for (final category in group.categories) _BandSlot.category(category),
      ],
    ];

    return WatchBandList(
      pitch: _rowSlotHeight,
      itemCount: slots.length,
      extentOf: (index) =>
          slots[index].isGroup ? _groupSlotHeight : _rowSlotHeight,
      itemBuilder: (context, index) {
        final slot = slots[index];
        if (slot.isGroup) {
          return _BandGroupTitle(title: slot.groupTitle!);
        }
        final category = slot.category!;
        // 横向内缩由 WatchBandList 负责，这里不再加任何水平 Padding。
        return WatchRow(
          icon: category.icon,
          title: category.label,
          onTap: () => onSelect(category.path),
        );
      },
    );
  }
}

class _BandGroupTitle extends StatelessWidget {
  const _BandGroupTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // 视觉高 28 + 底部 8 = 36，与 extentOf 上报的高度一致。
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 28,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _SettingsMenu extends StatelessWidget {
  const _SettingsMenu({
    required this.wide,
    this.selectedPath,
    required this.onSelect,
  });

  final bool wide;
  final String? selectedPath;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(
        padding: wide
            ? const EdgeInsets.fromLTRB(4, 0, 0, 12)
            : const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (final group in _settingsGroups)
            if (wide) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
                child: SectionHeader(title: Text(group.title)),
              ),
              for (final category in group.categories)
                _RailDestination(
                  category: category,
                  selected: selectedPath == category.path,
                  onTap: () => onSelect(category.path),
                ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ContentSection.group(
                  title: group.title,
                  children: [
                    for (final category in group.categories)
                      SettingsCategoryTile(
                        icon: category.icon,
                        title: category.label,
                        description: category.description,
                        onTap: () => onSelect(category.path),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _RailDestination extends StatelessWidget {
  const _RailDestination({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final _SettingsCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final foreground = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? colorScheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(category.icon, size: 24, color: foreground),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category.label,
                    style: textTheme.labelLarge?.copyWith(color: foreground),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
