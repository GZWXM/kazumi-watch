import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:kazumi/bean/widget/circle_insets.dart';
import 'package:kazumi/bean/widget/watch_list.dart';
import 'package:kazumi/bean/widget/watch_scaffold.dart';
import 'package:kazumi/modules/search/plugin_search_module.dart';
import 'package:kazumi/plugins/plugins.dart';
import 'package:kazumi/plugins/plugins_controller.dart';
import 'package:kazumi/request/core/network_exception.dart';
import 'package:kazumi/services/plugin/rule_engine_models.dart'
    show RuleCancelToken;

/// 手表端「源搜索」最小验证切片：
/// 输入关键词 → 并发查询所有已安装番剧源（上限 4、单源 15s 超时）→
/// 展示【每源状态】+【结果平铺行】。只做验证，不做点击跳转。
library;

const int _kMaxConcurrent = 4;
const Duration _kSourceTimeout = Duration(seconds: 15);
const int _kMaxResultRows = 200;

/// 行距 = WatchRow 槽位高（视觉 44 + 间隙 8），铁律：item 高度必须 == pitch
const double _kRowPitch = 52;

/// 固定头部高度（8 顶距 + 40 搜索框 + 12 底距），作为 WatchBandList 的 headerExtent
const double _kHeaderExtent = 60;

enum _SourceStatus { waiting, running, success, noResult, captcha, timeout, error, cancelled }

class _SourceEntry {
  _SourceEntry(this.plugin);

  final Plugin plugin;
  _SourceStatus status = _SourceStatus.waiting;
  List<SearchItem> items = const <SearchItem>[];

  /// 已进入终态（防止超时后取消异常回写覆盖超时状态）
  bool settled = false;

  RuleCancelToken? token;

  String get displayName =>
      plugin.name.isEmpty ? (plugin.baseUrl.isEmpty ? '未命名源' : plugin.baseUrl) : plugin.name;
}

class SourceSearchPage extends StatefulWidget {
  const SourceSearchPage({super.key});

  @override
  State<SourceSearchPage> createState() => _SourceSearchPageState();
}

class _SourceSearchPageState extends State<SourceSearchPage> {
  final PluginsController _pluginsController = inject<PluginsController>();

  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _listScroll = ScrollController();

  List<_SourceEntry> _entries = const <_SourceEntry>[];
  List<({String title, String source})> _visibleResults =
      const <({String title, String source})>[];
  int _totalResultCount = 0;
  bool _truncated = false;
  bool _running = false;
  bool _stopRequested = false;
  bool _hasSearched = false;
  int _runId = 0;

  final List<RuleCancelToken> _activeTokens = <RuleCancelToken>[];

  @override
  void dispose() {
    _runId++; // 让所有在途回写失效
    for (final token in _activeTokens) {
      if (!token.isCancelled) token.cancel();
    }
    _activeTokens.clear();
    _input.dispose();
    _inputFocus.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- 搜索流程

  Future<void> _submit(String value) async {
    final keyword = value.trim();
    _inputFocus.unfocus();
    if (keyword.isEmpty || _running) return;
    _cancelActive();
    _writeInput(keyword);

    final plugins = List<Plugin>.of(_pluginsController.pluginList);
    final entries = plugins.map((p) => _SourceEntry(p)).toList();
    final run = ++_runId;
    setState(() {
      _hasSearched = true;
      _entries = entries;
      _running = true;
      _stopRequested = false;
      _rebuildResults();
    });
    if (_listScroll.hasClients) _listScroll.jumpTo(0);

    // 简单工人池：并发上限 _kMaxConcurrent，共享一个待办队列
    final queue = List<_SourceEntry>.of(entries);
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        if (run != _runId || _stopRequested || !mounted) return;
        await _queryOne(queue.removeAt(0), keyword, run);
      }
    }

    await Future.wait(List.generate(_kMaxConcurrent, (_) => worker()));
    if (run == _runId && mounted) setState(() => _running = false);
  }

  Future<void> _queryOne(_SourceEntry entry, String keyword, int run) async {
    final token = CancelToken();
    entry.token = token;
    _activeTokens.add(token);
    _setStatus(entry, _SourceStatus.running, run);
    try {
      final response = await entry.plugin
          .queryBangumi(
            keyword,
            shouldRethrow: true,
            cancelToken: token,
          )
          .timeout(_kSourceTimeout);
      if (run != _runId || entry.settled || !mounted) return;
      entry.items = response.data;
      _finish(
        entry,
        response.data.isEmpty ? _SourceStatus.noResult : _SourceStatus.success,
        run,
      );
    } on TimeoutException {
      if (!token.isCancelled) token.cancel(); // 掐掉仍在飞的请求
      _finish(entry, _SourceStatus.timeout, run);
    } on CaptchaRequiredException {
      _finish(entry, _SourceStatus.captcha, run);
    } on NoResultException {
      _finish(entry, _SourceStatus.noResult, run);
    } catch (error) {
      if (_isCancelError(error)) {
        _finish(entry, _SourceStatus.cancelled, run);
      } else {
        _finish(entry, _SourceStatus.error, run);
      }
    } finally {
      entry.token = null;
      _activeTokens.remove(token);
    }
  }

  void _stop() {
    _stopRequested = true;
    for (final entry in _entries) {
      if (entry.settled) continue;
      if (entry.status == _SourceStatus.waiting) {
        entry.status = _SourceStatus.cancelled;
        entry.settled = true;
      } else if (entry.token != null && !entry.token!.isCancelled) {
        entry.token!.cancel();
      }
    }
    setState(() {
      _running = false;
      _rebuildResults();
    });
  }

  void _cancelActive() {
    for (final token in _activeTokens) {
      if (!token.isCancelled) token.cancel();
    }
    _activeTokens.clear();
  }

  bool _isCancelError(Object error) {
    if (error is DioException) return error.type == DioExceptionType.cancel;
    if (error is NetworkException) return error.type == NetworkExceptionType.cancel;
    if (error is SearchErrorException && error.cause != null) {
      return _isCancelError(error.cause!);
    }
    return false;
  }

  void _setStatus(_SourceEntry entry, _SourceStatus status, int run) {
    if (run != _runId || entry.settled || !mounted) return;
    setState(() => entry.status = status);
  }

  void _finish(_SourceEntry entry, _SourceStatus status, int run) {
    if (run != _runId || entry.settled || !mounted) return;
    entry.status = status;
    entry.settled = true;
    setState(_rebuildResults);
  }

  /// 把各源结果平铺成行（总上限 200，超出截断并在标注里说明）
  void _rebuildResults() {
    final rows = <({String title, String source})>[];
    var total = 0;
    for (final entry in _entries) {
      total += entry.items.length;
      for (final item in entry.items) {
        if (rows.length < _kMaxResultRows) {
          final name = item.name.trim();
          rows.add((title: name.isEmpty ? '(无标题)' : name, source: entry.displayName));
        }
      }
    }
    _visibleResults = rows;
    _totalResultCount = total;
    _truncated = total > _kMaxResultRows;
  }

  // ---------------------------------------------------------------- UI

  String get _statusLabel {
    final done = _entries.where((e) => e.settled).length;
    return '$done/${_entries.length} 完成';
  }

  String get _resultLabel => _truncated
      ? '显示 ${_visibleResults.length} 条 · 已截断'
      : '共 $_totalResultCount 条';

  void _writeInput(String value) {
    _input.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Widget _searchField() {
    final colors = Theme.of(context).colorScheme;
    // 与 search_page 的 _header() 同风格；Row 横向内缩取 y=44 的弦
    final rowInset = CircleInsets.bandInset(CircleInsets.bodyTop);

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _input,
      builder: (context, value, child) => Padding(
        padding: EdgeInsets.symmetric(horizontal: rowInset),
        child: SizedBox(
          height: 40,
          child: SearchBar(
            controller: _input,
            focusNode: _inputFocus,
            hintText: '输入关键词搜全部源',
            textInputAction: TextInputAction.search,
            constraints: const BoxConstraints(minHeight: 40, maxHeight: 40),
            elevation: const WidgetStatePropertyAll(0),
            backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerHigh),
            padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 8)),
            textStyle: WidgetStatePropertyAll(
                Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 13)),
            leading: IconButton(
              tooltip: '搜索',
              onPressed: () => _submit(_input.text),
              icon: const Icon(Icons.search_rounded, size: 20),
            ),
            trailing: [
              if (_running)
                IconButton(
                  tooltip: '停止',
                  onPressed: _stop,
                  icon: const Icon(Icons.stop_circle_outlined, size: 20),
                )
              else if (value.text.isNotEmpty)
                IconButton(
                  tooltip: '清空',
                  onPressed: () {
                    _inputFocus.unfocus();
                    _writeInput('');
                  },
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
            ],
            onSubmitted: _submit,
          ),
        ),
      ),
    );
  }

  /// 固定头部：不随列表滚动，高度正好 _kHeaderExtent（8 + 40 + 12）
  Widget _header() => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: _searchField(),
      );

  Widget _statusRow(_SourceEntry entry) {
    final (icon, label) = _statusPresentation(entry);
    return WatchRow(
      icon: icon,
      title: entry.displayName,
      meta: label,
    );
  }

  (IconData, String) _statusPresentation(_SourceEntry entry) {
    switch (entry.status) {
      case _SourceStatus.waiting:
        return (Icons.hourglass_empty_rounded, '等待中');
      case _SourceStatus.running:
        return (Icons.refresh_rounded, '搜索中…');
      case _SourceStatus.success:
        return (Icons.check_circle_outline_rounded, '✓ ${entry.items.length} 条');
      case _SourceStatus.noResult:
        return (Icons.search_off_rounded, '无结果');
      case _SourceStatus.captcha:
        return (Icons.security_rounded, '需验证码');
      case _SourceStatus.timeout:
        return (Icons.timer_off_rounded, '超时');
      case _SourceStatus.error:
        return (Icons.error_outline_rounded, '出错');
      case _SourceStatus.cancelled:
        return (Icons.stop_rounded, '已停止');
    }
  }

  Widget _body() {
    if (!_hasSearched || _entries.isEmpty) {
      return WatchBandList(
        pitch: _kRowPitch,
        headerExtent: _kHeaderExtent,
        controller: _listScroll,
        itemCount: 1,
        itemBuilder: (context, index) => _entries.isEmpty
            ? const WatchRow(
                icon: Icons.extension_off_rounded,
                title: '未安装任何番剧源',
                meta: '先去我的-规则设置安装',
              )
            : const WatchRow(
                icon: Icons.touch_app_rounded,
                title: '输入关键词后按搜索',
                meta: '并发查全部已装源',
              ),
      );
    }

    final entryCount = _entries.length;
    final resultCount = _visibleResults.length;
    // 行布局（每行高度恒等于 pitch 52）：
    //   0            → 源状态标签
    //   1..n         → 各源状态行
    //   n+1          → 结果标签
    //   n+2..n+1+m   → 结果行
    return WatchBandList(
      pitch: _kRowPitch,
      headerExtent: _kHeaderExtent,
      controller: _listScroll,
      itemCount: 2 + entryCount + resultCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return WatchRow(
            icon: Icons.traffic_rounded,
            title: '源状态',
            meta: _statusLabel,
          );
        }
        if (index <= entryCount) {
          return _statusRow(_entries[index - 1]);
        }
        if (index == entryCount + 1) {
          return WatchRow(
            icon: Icons.movie_filter_rounded,
            title: '结果',
            meta: _resultLabel,
          );
        }
        final row = _visibleResults[index - entryCount - 2];
        return WatchRow(
          title: row.title,
          meta: _shortenSource(row.source),
        );
      },
    );
  }

  /// meta 区无宽度约束，源名过长会顶爆行 → 收敛到 8 字
  String _shortenSource(String source) =>
      source.length <= 8 ? source : '${source.substring(0, 8)}…';

  @override
  Widget build(BuildContext context) {
    return WatchScaffold(
      title: '源搜索',
      child: Column(
        children: [
          SizedBox(height: _kHeaderExtent, child: _header()),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}
