import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/widget/circle_insets.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/bean/widget/watch_list.dart';
import 'package:kazumi/bean/widget/watch_scaffold.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/device.dart';
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
  // Preserve the input subtree when the header moves in or out of the scroll view.
  final _searchHeaderKey = GlobalKey();
  String? _submittedQuery;
  bool _managingHistory = false;

  SearchPageController get _controller => widget.controller;
  bool get _hasSearched => _submittedQuery != null;

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
    // Row horizontal inset for y=44 (bodyTop) is CircleInsets.bandInset(44) ≈ 31
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

  Widget _header() => Padding(
        key: _searchHeaderKey,
        padding: EdgeInsets.only(top: _hasSearched ? 8 : 16, bottom: 12),
        child: _searchField(),
      );

  Widget _discovery() {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      WatchRow(
        icon: Icons.tune_rounded,
        title: '按条件查找',
        meta: '题材、时间等',
        onTap: _showFilters,
      ),
      const SizedBox(height: 16),
      Observer(builder: (_) {
        final histories = _controller.searchHistories.toList();
        if (histories.isEmpty) return const SizedBox.shrink();
        
        final items = histories.take(10).toList();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: CircleInsets.bandInset(80)),
              child: Row(children: [
                Expanded(
                    child: Text('最近搜索',
                        style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant))),
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
              ])),
            const SizedBox(height: 4),
            WatchBandList(
              itemCount: items.length,
              pitch: 52,
              itemBuilder: (context, index) {
                final history = items[index];
                return WatchRow(
                  icon: Icons.history_rounded,
                  title: _readableQuery(history.keyword),
                  onTap: () => _submit(history.keyword),
                );
              },
            ),
          ],
        );
      }),
    ]);
  }

  Widget _resultSlivers(BuildContext context) {
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

    // Header content inside sliver
    Widget headerContent = Padding(
      padding: EdgeInsets.symmetric(horizontal: CircleInsets.bandInset(80)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ]),
    );

    List<Widget> listChildren = [];
    
    if (busy && allItems.isEmpty) {
       listChildren.add(const SliverToBoxAdapter(child: _SearchLoadingState()));
    } else if (allItems.isEmpty) {
       listChildren.add(const SliverToBoxAdapter(
         child: GeneralEmptyState(
           icon: Icons.search_off_rounded,
           title: '没有找到番剧',
         ),
       ));
    } else if (items.isEmpty) {
       listChildren.add(SliverToBoxAdapter(
           child: GeneralEmptyState(
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
       )));
    } else {
      // Single column rich rows using WatchMediaRow
      listChildren.add(WatchBandList(
        itemCount: items.length,
        pitch: 68, // Height 60 + gap 8
        headerExtent: 0, // Handled by preceding SliverToBoxAdapter
        controller: _scroll,
        itemBuilder: (context, index) {
          final item = items[index];
          final showRating = GStorage.getSetting(SettingsKeys.showRating);
          String meta = '';
          if (showRating && item.rating != null) {
             meta = '评分 ${item.rating!.score.toStringAsFixed(1)}';
          }
          return WatchMediaRow(
            coverUrl: item.images.medium ?? '',
            title: item.name,
            meta: meta,
            onTap: () {
              Modular.to.pushNamed('/bangumi/detail', arguments: item);
            },
          );
        },
      ));
      
      // Load more footer
      if (allItems.isNotEmpty || !failed) {
        listChildren.add(SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: busy
                      ? (allItems.isEmpty
                          ? const SizedBox.shrink()
                          : const LoadingIndicator(size: 32))
                      : _controller.hasMoreSearchResults
                          ? TextButton.icon(
                              onPressed: _loadMore,
                              icon: const Icon(Icons.expand_more_rounded),
                              label: const Text('加载更多'))
                          : Text('已经看到全部结果',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                ))));
      }
    }

    return CustomScrollView(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(child: headerContent),
        ...listChildren,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return WatchScaffold(
      title: '番剧搜索',
      child: Observer(
        builder: (_) {
          if (_hasSearched) {
            return _resultSlivers(context);
          } else {
            return ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _header(),
                _discovery(),
              ],
            );
          }
        },
      ),
    );
  }
  
  // Helper for readable query (copied from original logic implicitly needed)
  String _readableQuery(String keyword) {
    if (keyword.startsWith('tag:')) {
      return keyword.substring(4);
    }
    return keyword;
  }
  
  String _filterSummary(SearchFilterState state) {
    final parts = <String>[];
    if (state.tags.isNotEmpty) parts.add('标签: ${state.tags.join(', ')}');
    if (state.year != null) parts.add('年份: ${state.year}');
    if (state.status != null) parts.add('状态: ${state.status}');
    if (state.type != null) parts.add('类型: ${state.type}');
    return parts.join(' | ');
  }
}
