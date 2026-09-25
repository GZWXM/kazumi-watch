import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
// ⚠️ 下面三个 import 是给 part 文件（search_filter_sheet.dart）用的，本文件里看起来「没引用」
//    也不能删 —— part 文件没有自己的 import，全部继承宿主库。
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/bean/widget/circle_insets.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/bean/widget/watch_list.dart';
import 'package:kazumi/bean/widget/watch_scaffold.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/storage/settings_keys.dart';
import 'package:kazumi/utils/constants.dart';      // part 文件（search_filter_sheet）要用
import 'package:kazumi/utils/date_time.dart';       // 同上：formatDateTime
import 'package:kazumi/utils/search_parser.dart';

part 'search_filter_sheet.dart';
part 'search_widgets.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.controller, this.inputTag = ''});

  final SearchPageController controller;
  final String inputTag;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();
  String? _submittedQuery;
  bool _managingHistory = false;

  SearchPageController get _controller => widget.controller;
  bool get _hasSearched => _submittedQuery != null;

  // 固定头部高度（8顶距 + 40搜索框 + 12底距），与 source_search_page 同规格
  static const double _kHeaderExtent = 60.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadMoreOnScroll);
    _controller.loadSearchHistories();
    if (widget.inputTag.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyFilters(
            SearchFilterState(tags: [Uri.decodeComponent(widget.inputTag)]));
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _writeInput(String value) {
    _input.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Future<void> _submit(String value) async {
    final filters = SearchParser(value).toFilterState();
    final query = SearchParser.fromFilterState(filters);
    _inputFocus.unfocus();
    _writeInput(query);
    setState(() => _submittedQuery = query);
    final request = _controller.searchBangumi(query, type: 'init');
    if (_scroll.hasClients) _scroll.jumpTo(0);
    await request;
  }

  Future<void> _applyFilters(SearchFilterState filters) =>
      _submit(SearchParser.fromFilterState(filters));

  void _loadMoreOnScroll() {
    if (!_scroll.hasClients || _scroll.position.extentAfter > 360) return;
    _loadMore();
  }

  void _loadMore() {
    final query = _submittedQuery;
    if (query != null) _controller.searchBangumi(query);
  }

  Future<void> _showFilters() async {
    _inputFocus.unfocus();
    final result = await showAdaptiveBottomSheet<_SearchFilterResult>(
      context: context,
      maxHeightFactor: 0.9,
      builder: (_) => _SearchFilterSheet(
        initialState: SearchParser(_input.text).toFilterState(),
        initialNotShowWatched: _controller.notShowWatchedBangumis,
        initialNotShowAbandoned: _controller.notShowAbandonedBangumis,
      ),
    );
    if (!mounted || result == null) return;
    await _controller.setNotShowWatchedBangumis(result.notShowWatched);
    await _controller.setNotShowAbandonedBangumis(result.notShowAbandoned);
    if (!mounted) return;
    await _applyFilters(result.filterState);
  }

  Future<void> _imageSearch() async {
    _inputFocus.unfocus();
    final result = await context.pushNamed('/search/image');
    if (!mounted || result is! String || result.isEmpty) return;
    await _submit(result);
  }

  void _clearSearch() {
    _inputFocus.unfocus();
    _writeInput('');
    setState(() {
      _submittedQuery = null;
      _managingHistory = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Widget _searchField() {
    final colors = Theme.of(context).colorScheme;
    final rowInset = CircleInsets.bandInset(CircleInsets.bodyTop);
    
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _input,
      builder: (context, value, child) => Padding(
        padding: EdgeInsets.symmetric(horizontal: rowInset),
        child: SearchBar(
          controller: _input,
          focusNode: _inputFocus,
          hintText: '搜索番剧名称',
          textInputAction: TextInputAction.search,
          constraints: const BoxConstraints(minHeight: 40),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerHigh),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
          textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 13)),
          leading: IconButton(
            tooltip: '搜索',
            onPressed: () => _submit(_input.text),
            icon: const Icon(Icons.search_rounded, size: 20),
          ),
          trailing: [
            if (value.text.isNotEmpty || _hasSearched)
              IconButton(
                  tooltip: '清空搜索',
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.close_rounded, size: 20)),
            IconButton(
              tooltip: '以图搜番',
              onPressed: _imageSearch,
              icon: const Icon(Icons.image_search_rounded, size: 20),
            ),
          ],
          onSubmitted: _submit,
        ),
      ),
    );
  }

  /// 固定头部：不随列表滚动，高度正好 _kHeaderExtent
  Widget _header() => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: _searchField(),
      );

  /// 发现态：入口行 + 历史记录（全在 WatchBandList 管理）
  Widget _discoveryBody() {
    return Observer(builder: (_) {
      final histories = _controller.searchHistories.toList();
      final historyItems = histories.take(10).toList();
      
      // 行布局：
      // 0: 用番剧源搜索
      // 1: 按条件查找
      // 2-N: 历史记录（如果有的话，前面有个标签头）
      final baseRows = 2;
      final hasHistory = historyItems.isNotEmpty;
      final historyHeader = hasHistory ? 1 : 0;
      final itemCount = baseRows + historyHeader + historyItems.length;
      
      return WatchBandList(
        controller: _scroll,
        pitch: 52,
        headerExtent: _kHeaderExtent,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return WatchRow(
              icon: Icons.travel_explore_rounded,
              title: '用番剧源搜索',
              meta: 'Bangumi 搜不了时用',
              onTap: () => context.pushNamed('/search/source'),
            );
          }
          if (index == 1) {
            return WatchRow(
              icon: Icons.tune_rounded,
              title: '按条件查找',
              meta: '题材、时间等',
              onTap: _showFilters,
            );
          }
          
          // 历史部分
          if (!hasHistory) return const SizedBox(height: 44);
          
          final historyIndex = index - baseRows;
          if (historyIndex == 0) {
            // 历史记录标签头
            final theme = Theme.of(context);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                height: 44,
                child: Row(children: [
                  Expanded(
                    child: Text('最近搜索',
                        style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ),
                  if (_managingHistory)
                    TextButton(
                        onPressed: () async {
                          await _controller.clearSearchHistory();
                          if (mounted) {
                            setState(() => _managingHistory = false);
                          }
                        },
                        child: const Text('清空')),
                  TextButton(
                      onPressed: () => setState(
                          () => _managingHistory = !_managingHistory),
                      child: Text(_managingHistory ? '完成' : '管理')),
                ]),
              ),
            );
          }
          
          final history = historyItems[historyIndex - 1];
          return WatchRow(
            icon: Icons.history_rounded,
            title: _readableQuery(history.keyword),
            onTap: () => _submit(history.keyword),
          );
        },
      );
    });
  }

  /// 结果态：结果标签 + 结果列表（全在 WatchBandList 管理）
  Widget _resultBody() {
    return Observer(builder: (_) {
      final allItems = _controller.bangumiList.toList();
      final watched = _controller.notShowWatchedBangumis
          ? _controller.loadWatchedBangumiIds()
          : <int>{};
      final abandoned = _controller.notShowAbandonedBangumis
          ? _controller.loadAbandonedBangumiIds()
          : <int>{};
      final items = allItems
          .where((item) =>
              !watched.contains(item.id) && !abandoned.contains(item.id))
          .toList();
      final busy = _controller.isLoading;
      final failed = _controller.isTimeOut;
      final submitted = SearchParser(_submittedQuery!).toFilterState();
      final summary = _filterSummary(submitted);

      // 行布局：
      // 0: 结果标签头（含筛选按钮/排序/统计）
      // 1-N: 结果行 或 空状态
      // N+1: 加载更多footer（如果有结果的话）
      
      if (busy && allItems.isEmpty) {
        // 初次加载中
        return WatchBandList(
          controller: _scroll,
          pitch: 52,
          headerExtent: _kHeaderExtent,
          itemCount: 1,
          itemBuilder: (context, index) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: _SearchLoadingState(),
          ),
        );
      }
      
      if (allItems.isEmpty) {
        // 无结果
        return WatchBandList(
          controller: _scroll,
          pitch: 52,
          headerExtent: _kHeaderExtent,
          itemCount: 1,
          itemBuilder: (context, index) => GeneralEmptyState(
            icon: Icons.search_off_rounded,
            title: '没有找到番剧',
            actions: [
              StateActionButton.tonal(
                onPressed: () => context.pushNamed('/search/source'),
                icon: Icons.travel_explore_rounded,
                text: '用番剧源搜索',
              ),
            ],
          ),
        );
      }
      
      if (items.isEmpty) {
        // 全被筛选隐藏
        return WatchBandList(
          controller: _scroll,
          pitch: 52,
          headerExtent: _kHeaderExtent,
          itemCount: 1,
          itemBuilder: (context, index) => GeneralEmptyState(
            icon: Icons.filter_alt_off_rounded,
            title: '这些番剧被筛选隐藏了',
            actions: [
              StateActionButton.tonal(
                onPressed: () async {
                  await _controller.setNotShowWatchedBangumis(false);
                  await _controller.setNotShowAbandonedBangumis(false);
                },
                icon: Icons.visibility_outlined,
                text: '显示全部',
              ),
            ],
          ),
        );
      }

      // 有结果：标签头(1) + 结果行(N) + footer(1)
      final headerRow = 1;
      final resultRows = items.length;
      final footerRow = 1;
      final totalCount = headerRow + resultRows + footerRow;
      
      return WatchBandList(
        controller: _scroll,
        pitch: 68, // 结果行用 WatchMediaRow，pitch=68
        headerExtent: _kHeaderExtent,
        itemCount: totalCount,
        extentOf: (index) {
          // 第0行（标签头）高度不等于68，需要特殊报告
          // 标签头内容：标题行24 + 统计行16 + summary(可选)18 + 底距12 ≈ 70，用68近似
          // footer行也不等于68，但它在末尾、偏差不累积
          if (index == 0) return 68.0; // 标签头
          if (index <= resultRows) return 68.0; // 结果行
          return 52.0; // footer行用标准pitch
        },
        itemBuilder: (context, index) {
          if (index == 0) {
            // 结果标签头
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                height: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text('搜索结果',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600))),
                      if (!submitted.isIdSearch)
                        _SearchSortMenu(
                            value: submitted.sort,
                            onChanged: (sort) =>
                                _applyFilters(submitted.copyWith(sort: sort))),
                      IconButton(
                        tooltip: '筛选番剧',
                        onPressed: _showFilters,
                        icon: Badge(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            isLabelVisible: submitted.hasAdvancedFilters ||
                                _controller.notShowWatchedBangumis ||
                                _controller.notShowAbandonedBangumis,
                            smallSize: 6,
                            child: const Icon(Icons.tune_rounded)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                        busy
                            ? '正在搜索…'
                            : '${items.length} 部番剧${items.length < allItems.length ? ' · 隐藏 ${allItems.length - items.length} 部' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
            );
          }
          
          if (index <= resultRows) {
            // 结果行
            final item = items[index - 1];
            final showRating = GStorage.getSetting(SettingsKeys.showRating);
            String? meta;
            if (showRating && item.ratingScore > 0) {
              meta = '评分 ${item.ratingScore.toStringAsFixed(1)}';
            }
            return WatchMediaRow(
              coverUrl: item.images['large'] ?? item.images['common'] ?? '',
              title: item.nameCn.isNotEmpty ? item.nameCn : item.name,
              meta: meta,
              onTap: () {
                context.pushNamed('/info/', arguments: item);
              },
            );
          }
          
          // Footer行：加载更多
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              height: 44,
              child: Center(
                child: busy
                    ? const LoadingIndicator(size: 24)
                    : _controller.hasMoreSearchResults
                        ? TextButton.icon(
                            onPressed: _loadMore,
                            icon: const Icon(Icons.expand_more_rounded, size: 18),
                            label: const Text('加载更多', style: TextStyle(fontSize: 12)))
                        : Text('已经看到全部结果',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
              ),
            ),
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return WatchScaffold(
      title: '番剧搜索',
      child: Column(
        children: [
          SizedBox(height: _kHeaderExtent, child: _header()),
          Expanded(
            child: _hasSearched ? _resultBody() : _discoveryBody(),
          ),
        ],
      ),
    );
  }
  
  String _readableQuery(String keyword) {
    if (keyword.startsWith('tag:')) {
      return keyword.substring(4);
    }
    return keyword;
  }
  
  String _filterSummary(SearchFilterState state) {
    final parts = <String>[];
    if (state.keyword.isNotEmpty) parts.add('关键词: ${state.keyword}');
    if (state.tags.isNotEmpty) parts.add('标签: ${state.tags.join(', ')}');
    if (state.season.isNotEmpty) parts.add('季度: ${state.season}');
    if (state.weekdays.isNotEmpty) parts.add('放送日: ${state.weekdays.length} 天');
    return parts.join(' | ');
  }
}
