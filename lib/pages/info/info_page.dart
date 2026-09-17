
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/bean/widget/circle_insets.dart';
import 'package:kazumi/bean/widget/watch_scaffold.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/pages/info/info_tabview.dart';
import 'package:kazumi/pages/info/rating_review_dialog.dart';
import 'package:kazumi/pages/info/source_sheet.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({
    super.key,
    required this.inputBangumiItem,
    required this.infoController,
  });

  final BangumiItem inputBangumiItem;
  final InfoController infoController;

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage>
    with SingleTickerProviderStateMixin {
  static const List<String> _infoTabs = <String>[
    '概览',
    '吐槽',
    '角色',
    '关联',
    '制作人员',
  ];
  static const Duration _minimumBangumiInfoLoadingDuration =
      Duration(milliseconds: 600);

  InfoController get infoController => widget.infoController;
  late final TabController infoTabController;
  late final bool showRating;

  bool commentsIsLoading = false;
  bool charactersIsLoading = false;
  bool commentsQueryTimeout = false;
  bool commentsHasLoaded = false;
  bool charactersQueryTimeout = false;
  bool charactersIsEmpty = false;
  bool staffIsLoading = false;
  bool staffQueryTimeout = false;
  bool staffIsEmpty = false;
  bool _showBangumiInfoSkeleton = false;

  bool get _isShowingBangumiInfoSkeleton =>
      infoController.isLoading || _showBangumiInfoSkeleton;

  bool _needsBangumiInfoRefresh(BangumiItem bangumiItem) {
    final votesCount = bangumiItem.votesCount;
    final missingVoteDistribution =
        votesCount.isEmpty || bangumiItem.votes <= 0 || votesCount.length < 10;
    return bangumiItem.summary == '' || missingVoteDistribution;
  }

  Future<void> loadCharacters() async {
    if (charactersIsLoading) return;
    setState(() {
      charactersIsLoading = true;
      charactersQueryTimeout = false;
      charactersIsEmpty = false;
    });
    try {
      await infoController
          .queryBangumiCharactersByID(infoController.bangumiItem.id);
      if (mounted) {
        setState(() {
          charactersIsLoading = false;
          if (infoController.characterList.isEmpty) {
            charactersIsEmpty = true;
          }
        });
      }
    } catch (e) {
      KazumiLogger().e('InfoPage: failed to load characters', error: e);
      if (mounted) {
        setState(() {
          charactersIsLoading = false;
          charactersQueryTimeout = true;
        });
      }
    }
  }

  Future<void> loadStaff() async {
    if (staffIsLoading) return;
    setState(() {
      staffIsLoading = true;
      staffQueryTimeout = false;
      staffIsEmpty = false;
    });
    try {
      await infoController
          .queryBangumiStaffsByID(infoController.bangumiItem.id);
      if (mounted) {
        setState(() {
          staffIsLoading = false;
          if (infoController.staffList.isEmpty) {
            staffIsEmpty = true;
          }
        });
      }
    } catch (e) {
      KazumiLogger().e('InfoPage: failed to load staff', error: e);
      if (mounted) {
        setState(() {
          staffIsLoading = false;
          staffQueryTimeout = true;
        });
      }
    }
  }

  Future<void> loadRelations() async {
    try {
      await infoController
          .queryBangumiRelationsByID(infoController.bangumiItem.id);
    } catch (e) {
      KazumiLogger().e('InfoPage: failed to load relations', error: e);
    }
  }

  Future<void> loadMoreComments({bool loadMore = false}) async {
    if (commentsIsLoading) return;
    setState(() {
      commentsIsLoading = true;
      commentsQueryTimeout = false;
    });
    try {
      await infoController.queryBangumiCommentsByID(
          infoController.bangumiItem.id,
          refresh: !loadMore);
      if (mounted) {
        setState(() {
          commentsIsLoading = false;
          commentsHasLoaded = true;
        });
      }
    } catch (e) {
      KazumiLogger().e('InfoPage: failed to load comments', error: e);
      if (mounted) {
        setState(() {
          commentsIsLoading = false;
          commentsQueryTimeout = true;
        });
      }
    }
  }

  Future<void> _openReviewEditor() async {
    final token =
        GStorage.getSetting(SettingsKeys.bangumiAccessToken).toString().trim();
    if (token.isEmpty) {
      KazumiDialog.showToast(message: '请先在同步设置中绑定 Bangumi');
      return;
    }
    final localType = infoController.collectController
        .getCollectType(infoController.bangumiItem);
    if (localType == 0) {
      KazumiDialog.showToast(message: '请先追番');
      return;
    }
    final editing =
        infoController.bangumiItem.interest?.hasReviewContent ?? false;
    final submitted = await KazumiDialog.show<bool>(
      context: context,
      builder: (context) => RatingReviewDialog(
        bangumiItem: infoController.bangumiItem,
        onSubmit: (review) =>
            infoController.rateBangumi(review, localType: localType),
      ),
    );
    if (submitted == true && mounted) {
      setState(() {});
      KazumiDialog.showToast(
        context: context,
        message: editing ? '吐槽已更新' : '吐槽已发表',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    infoController.bangumiItem = widget.inputBangumiItem;
    infoController.characterList.clear();
    infoController.clearComments();
    infoController.staffList.clear();
    infoController.clearRelations();
    infoController.pluginSearchResponseList.clear();
    if (_needsBangumiInfoRefresh(infoController.bangumiItem)) {
      _showBangumiInfoSkeleton = true;
      _loadBangumiInfo();
    }
    infoTabController = TabController(length: _infoTabs.length, vsync: this);
    showRating = GStorage.getSetting(SettingsKeys.showRating);
    infoTabController.addListener(onInfoTabChanged);
  }

  void onInfoTabChanged() {
    final index = infoTabController.index;
    if (index == 1) {
      onCommentsTabSelected();
    }
    if (index == 2 &&
        infoController.characterList.isEmpty &&
        !charactersIsLoading &&
        !charactersIsEmpty &&
        !charactersQueryTimeout) {
      loadCharacters();
    }
    if (index == 3 && infoController.canLoadRelations) {
      loadRelations();
    }
    if (index == 4 &&
        infoController.staffList.isEmpty &&
        !staffIsLoading &&
        !staffIsEmpty &&
        !staffQueryTimeout) {
      loadStaff();
    }
  }

  Future<void> onCommentsTabSelected() async {
    final interest = infoController.bangumiItem.interest;
    final token =
        GStorage.getSetting(SettingsKeys.bangumiAccessToken).toString().trim();
    if (interest != null && token.isNotEmpty) {
      final updated = await infoController.fillInterestUserProfileIfNeeded();
      if (!mounted) return;
      if (updated) {
        setState(() {});
      }
    }
    if (infoController.commentsList.isEmpty &&
        !commentsIsLoading &&
        !commentsHasLoaded &&
        !commentsQueryTimeout) {
      loadMoreComments();
    }
  }

  @override
  void dispose() {
    infoTabController.removeListener(onInfoTabChanged);
    infoController.characterList.clear();
    infoController.clearComments();
    infoController.staffList.clear();
    infoController.clearRelations();
    infoController.pluginSearchResponseList.clear();
    infoTabController.dispose();
    super.dispose();
  }

  Future<void> _loadBangumiInfo() async {
    final loadingStartedAt = DateTime.now();
    try {
      // Attach metadata without replacing rendered image URLs.
      await infoController.queryBangumiInfoByID(
        infoController.bangumiItem.id,
        type: 'attach',
      );
    } catch (e) {
      KazumiLogger()
          .e('InfoPage: failed to query bangumi info by ID', error: e);
    } finally {
      if (mounted) {
        await _waitForMinimumBangumiInfoLoadingDuration(loadingStartedAt);
      }
      if (mounted) {
        setState(() {
          _showBangumiInfoSkeleton = false;
        });
      }
    }
  }

  Future<void> _waitForMinimumBangumiInfoLoadingDuration(
      DateTime loadingStartedAt) async {
    final elapsed = DateTime.now().difference(loadingStartedAt);
    final remaining = _minimumBangumiInfoLoadingDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
  }

  void _openSourceSheet() {
    showAdaptiveBottomSheet<void>(
      context: context,
      maxHeightFactor: 0.88,
      builder: (context) {
        return SourceSheet(infoController: infoController);
      },
    );
  }

  String get _displayTitle {
    final item = infoController.bangumiItem;
    return item.nameCn == '' ? item.name : item.nameCn;
  }

  // 圆屏头部：海报/标题/元信息/评分整体作为核心带内容，横向内缩按行取带表
  Widget _buildWatchHeader() {
    final theme = Theme.of(context);
    final item = infoController.bangumiItem;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: CircleInsets.bandInset(CircleInsets.bodyTop),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // 海报 72x104 居中
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: NetworkImgLayer(
              src: item.images['large'] ?? item.images['common'] ?? '',
              width: 72,
              height: 104,
              filterQuality: FilterQuality.medium,
            ),
          ),
          const SizedBox(height: 8),
          // 标题 15 号、最多两行
          Text(
            _displayTitle,
            style: theme.textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // 元信息 11 号
          Text(
            item.airDate,
            style: theme.textTheme.labelMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (showRating && showRating) ...[
            const SizedBox(height: 4),
            // 评分 22 w700 tabular，字号统一走 watchTheme
            Text(
              item.ratingScore.toStringAsFixed(1),
              style: theme.textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  // 5 页签改为横向 chips（chips 横向滚动属于规范允许的例外）
  Widget _buildWatchTabChips() {
    final theme = Theme.of(context);
    return SizedBox(
      height: 36,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: CircleInsets.bandInset(60),
        ),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_infoTabs.length, (index) {
                    final selected = infoTabController.index == index;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_infoTabs[index]),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            infoTabController.index = index;
                          });
                        },
                        labelStyle: theme.textTheme.labelMedium,
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 滚动末项：追番/外链两个 40dp tonal 圆钮 + 「开始观看」整带胶囊
  Widget _buildWatchBottomActions() {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CollectButton(
                bangumiItem: infoController.bangumiItem,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton.filledTonal(
                onPressed: () {
                  launchUrl(
                    Uri.parse(
                        'https://bangumi.tv/subject/${infoController.bangumiItem.id}'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.open_in_browser_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 160,
          height: 44,
          child: FilledButton(
            onPressed: _openSourceSheet,
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
              padding: EdgeInsets.zero,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow_rounded, size: 22),
                const SizedBox(width: 4),
                Text('开始观看', style: theme.textTheme.labelLarge),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WatchScaffold(
      title: _displayTitle,
      leading: IconButton(
        onPressed: () {
          Navigator.of(context).maybePop();
        },
        icon: const Icon(Icons.arrow_back),
      ),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Observer(builder: (context) {
              return _buildWatchHeader();
            }),
          ),
          SliverToBoxAdapter(
            child: _buildWatchTabChips(),
          ),
          // TabBarView 保留，占满剩余视口高度
          SliverFillRemaining(
            hasScrollBody: true,
            child: Observer(builder: (context) {
              final showBangumiInfoSkeleton = _isShowingBangumiInfoSkeleton;
              return InfoTabView(
                tabController: infoTabController,
                bangumiItem: infoController.bangumiItem,
                commentsQueryTimeout: commentsQueryTimeout,
                commentsHasLoaded: commentsHasLoaded,
                charactersQueryTimeout: charactersQueryTimeout,
                charactersIsEmpty: charactersIsEmpty,
                staffQueryTimeout: staffQueryTimeout,
                staffIsEmpty: staffIsEmpty,
                loadMoreComments: loadMoreComments,
                loadCharacters: loadCharacters,
                loadStaff: loadStaff,
                commentsList:
                    infoController.commentsList.toList(growable: false),
                commentsIsLoading: commentsIsLoading,
                onWriteReview: _openReviewEditor,
                characterList: infoController.characterList,
                staffList: infoController.staffList,
                relationList: infoController.relationList,
                relationsIsLoading: infoController.relationsIsLoading,
                relationsQueryTimeout: infoController.relationsQueryTimeout,
                relationsHasLoaded: infoController.relationsHasLoaded,
                loadRelations: loadRelations,
                isLoading: showBangumiInfoSkeleton,
              );
            }),
          ),
          SliverToBoxAdapter(
            child: _buildWatchBottomActions(),
          ),
        ],
      ),
    );
  }
}

