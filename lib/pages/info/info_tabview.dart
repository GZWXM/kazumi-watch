import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/widget/circle_insets.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/pages/info/info_comments_view.dart';
import 'package:kazumi/pages/info/character_page.dart';
import 'package:kazumi/bean/card/character_card.dart';
import 'package:kazumi/bean/card/staff_card.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_relation.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/modules/characters/character_item.dart';
import 'package:kazumi/modules/staff/staff_item.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/bean/widget/watch_list.dart';

class InfoTabView extends StatefulWidget {
  const InfoTabView({
    super.key,
    required this.commentsQueryTimeout,
    required this.commentsHasLoaded,
    required this.charactersQueryTimeout,
    required this.charactersIsEmpty,
    required this.staffQueryTimeout,
    required this.staffIsEmpty,
    required this.relationsQueryTimeout,
    required this.relationsIsLoading,
    required this.relationsHasLoaded,
    required this.tabController,
    required this.loadMoreComments,
    required this.loadCharacters,
    required this.loadStaff,
    required this.loadRelations,
    required this.bangumiItem,
    required this.commentsList,
    required this.commentsIsLoading,
    required this.onWriteReview,
    required this.characterList,
    required this.staffList,
    required this.relationList,
    required this.isLoading,
    // 次级操作从 info_page 传入，避免放在 SliverFillRemaining 后的死 sliver
    required this.secondaryActions,
  });

  final bool commentsQueryTimeout;
  final bool commentsHasLoaded;
  final bool commentsIsLoading;
  final VoidCallback onWriteReview;
  final bool charactersQueryTimeout;
  final bool charactersIsEmpty;
  final bool staffQueryTimeout;
  final bool staffIsEmpty;
  final bool relationsQueryTimeout;
  final bool relationsIsLoading;
  final bool relationsHasLoaded;
  final TabController tabController;
  final Future<void> Function({bool loadMore}) loadMoreComments;
  final Future<void> Function() loadCharacters;
  final Future<void> Function() loadStaff;
  final Future<void> Function() loadRelations;
  final BangumiItem bangumiItem;
  final List<CommentItem> commentsList;
  final List<CharacterItem> characterList;
  final List<StaffFullItem> staffList;
  final List<BangumiRelation> relationList;
  final bool isLoading;
  final Widget secondaryActions;

  @override
  State<InfoTabView> createState() => _InfoTabViewState();
}

class _InfoTabViewState extends State<InfoTabView> {
  final maxWidth = 950.0;
  bool fullIntro = false;
  bool fullTag = false;

  Widget get infoBody {
    final screenSize = MediaQuery.sizeOf(context);
    final roundWatch = isRoundWatch(screenSize);
    final contentWidth =
        roundWatch ? screenSize.width : (screenSize.width > maxWidth ? maxWidth : screenSize.width - 32);
    // 圆屏：横向内缩用带表计算，避免页面层双重内缩；非圆屏保持原有 16dp 边距
    final sidePadding = roundWatch
        ? CircleInsets.bandInset(CircleInsets.bodyTop)
        : 16.0;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: sidePadding, vertical: 8),
        child: SizedBox(
          width: contentWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('简介', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, constraints) {
                final span = TextSpan(text: widget.bangumiItem.summary);
                final tp =
                    TextPainter(text: span, textDirection: TextDirection.ltr);
                tp.layout(maxWidth: constraints.maxWidth);
                final numLines = tp.computeLineMetrics().length;
                // 圆屏行宽更窄，截断高度从 120 收到 64
                if (numLines > (roundWatch ? 4 : 7)) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: fullIntro ? null : (roundWatch ? 64 : 120),
                        width: contentWidth,
                        child: SelectableText(
                          widget.bangumiItem.summary,
                          textAlign: TextAlign.start,
                          scrollBehavior: const ScrollBehavior().copyWith(
                            scrollbars: false,
                          ),
                          scrollPhysics: NeverScrollableScrollPhysics(),
                          selectionHeightStyle: ui.BoxHeightStyle.max,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            fullIntro = !fullIntro;
                          });
                        },
                        child: Text(fullIntro ? '加载更少' : '加载更多'),
                      ),
                    ],
                  );
                } else {
                  return SelectableText(
                    widget.bangumiItem.summary,
                    textAlign: TextAlign.start,
                    scrollPhysics: NeverScrollableScrollPhysics(),
                    selectionHeightStyle: ui.BoxHeightStyle.max,
                  );
                }
              }),
              const SizedBox(height: 16),
              Text('标签', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: isDesktop() ? 8 : 0,
                children: List<Widget>.generate(
                    fullTag || widget.bangumiItem.tags.length < 13
                        ? widget.bangumiItem.tags.length
                        : 13, (int index) {
                  if (!fullTag && index == 12) {
                    return ActionChip(
                      label: Text(
                        '更多 +',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary),
                      ),
                      onPressed: () {
                        setState(() {
                          fullTag = !fullTag;
                        });
                      },
                    );
                  }
                  return ActionChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${widget.bangumiItem.tags[index].name} ',
                            style: Theme.of(context).textTheme.labelMedium),
                        Text(
                          '${widget.bangumiItem.tags[index].count}',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
                    onPressed: () {
                      final tagName = Uri.encodeComponent(
                          widget.bangumiItem.tags[index].name);
                      context.pushNamed('/search/$tagName');
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget get relationsListBody {
    // 圆屏：WatchBandList 负责动态内缩，关联条目用 WatchMediaRow（带封面）
    if (widget.relationsQueryTimeout) {
      return GeneralErrorWidget(
        title: '关联条目加载失败',
        errMsg: '请检查网络连接后重试。',
        onRetry: widget.loadRelations,
      );
    }
    if (widget.relationsHasLoaded && widget.relationList.isEmpty) {
      return const GeneralEmptyState(
        icon: Icons.account_tree_rounded,
        title: '暂无关联条目',
      );
    }
    final showSkeleton = !widget.relationsHasLoaded || widget.relationsIsLoading;
    if (showSkeleton) {
      return WatchBandList(
        key: const PageStorageKey<String>('关联'),
        itemCount: 3,
        pitch: 68,
        itemBuilder: (context, _) => Skeletonizer.zone(
          child: const WatchMediaRow(
            coverUrl: '',
            title: '加载中',
          ),
        ),
      );
    }
    return WatchBandList(
      key: const PageStorageKey<String>('关联'),
      itemCount: widget.relationList.length,
      pitch: 68,
      itemBuilder: (context, index) {
        final rel = widget.relationList[index];
        final bangumiItem = rel.toBangumiItem();
        final title = bangumiItem.nameCn.isEmpty
            ? bangumiItem.name.trim()
            : bangumiItem.nameCn.trim();
        final label = rel.relation.isEmpty ? '关联' : rel.relation;
        return WatchMediaRow(
          coverUrl: bangumiItem.images['large'] ?? '',
          title: title,
          meta: label,
          onTap: () {
            // 跳转到关联条目详情页，路由名与主模块注册一致
            context.pushNamed('/info/', arguments: bangumiItem);
          },
        );
      },
    );
  }

  Widget get infoBodyBone {
    final screenSize = MediaQuery.sizeOf(context);
    final contentWidth = isRoundWatch(screenSize)
        ? screenSize.width
        : (screenSize.width > maxWidth ? maxWidth : screenSize.width - 32);
    // 圆屏骨架同样用带表内缩，与 infoBody 对齐
    final sidePadding = isRoundWatch(screenSize)
        ? CircleInsets.bandInset(CircleInsets.bodyTop)
        : 16.0;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: sidePadding, vertical: 8),
        child: SizedBox(
          width: contentWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeletonizer.zone(child: Bone.text(fontSize: 15, width: 50)),
              const SizedBox(height: 8),
              Skeletonizer.zone(child: Bone.multiText(lines: 7)),
              const SizedBox(height: 16),
              Skeletonizer.zone(child: Bone.text(fontSize: 15, width: 50)),
              const SizedBox(height: 8),
              if (widget.isLoading)
                Skeletonizer.zone(
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: List.generate(
                        4, (_) => Bone.button(uniRadius: 8, height: 32)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget get staffListBody {
    // 圆屏：WatchBandList 负责动态内缩，不在页面层加横向 Padding
    if (widget.staffList.isNotEmpty) {
      return WatchBandList(
        key: const PageStorageKey<String>('制作人员'),
        itemCount: widget.staffList.length,
        pitch: 52,
        itemBuilder: (context, index) {
          final s = widget.staffList[index];
          return WatchRow(
            icon: Icons.person_outline_rounded,
            title: s.staff.nameCN.isNotEmpty ? s.staff.nameCN : s.staff.name,
            meta: s.relations.isNotEmpty ? s.relations.first : null,
          );
        },
      );
    }
    if (widget.staffQueryTimeout) {
      return GeneralErrorWidget(
        title: '制作人员加载失败',
        errMsg: '请检查网络连接后重试。',
        onRetry: widget.loadStaff,
      );
    }
    if (widget.staffIsEmpty) {
      return const GeneralEmptyState(
        icon: Icons.groups_rounded,
        title: '暂无制作人员信息',
      );
    }
    // 骨架态：8 行 WatchRow，pitch 对齐真实行高避免 yTop 偏移
    return WatchBandList(
      key: const PageStorageKey<String>('制作人员'),
      itemCount: 8,
      pitch: 52,
      itemBuilder: (context, _) => Skeletonizer.zone(
        child: const WatchRow(
          icon: Icons.person_outline_rounded,
          title: '加载中',
        ),
      ),
    );
  }

  Widget get charactersListBody {
    // 圆屏：WatchBandList 负责动态内缩，角色用 onTap 打开底部面板而非直接路由
    if (widget.characterList.isNotEmpty) {
      return WatchBandList(
        key: const PageStorageKey<String>('角色'),
        itemCount: widget.characterList.length,
        pitch: 52,
        itemBuilder: (context, index) {
          final c = widget.characterList[index];
          return WatchRow(
            icon: Icons.person_outline_rounded,
            title: c.name,
            meta: c.relation,
            onTap: () {
              // CharacterPage 是底部面板入口，不是独立路由；保持原 CharacterCard 的打开方式
              showAdaptiveBottomSheet<void>(
                context: context,
                builder: (_) => CharacterPage(
                  characterID: c.id,
                  characterName: c.name,
                  characterRelation: c.relation,
                  actorNames: c.actorList
                      .map((a) => a.name.trim())
                      .where((n) => n.isNotEmpty)
                      .toSet()
                      .toList(),
                ),
              );
            },
          );
        },
      );
    }
    if (widget.charactersQueryTimeout) {
      return GeneralErrorWidget(
        title: '角色列表加载失败',
        errMsg: '请检查网络连接后重试。',
        onRetry: widget.loadCharacters,
      );
    }
    if (widget.charactersIsEmpty) {
      return const GeneralEmptyState(
        icon: Icons.people_alt_rounded,
        title: '暂无角色信息',
      );
    }
    // 骨架态：4 行 WatchRow，pitch 对齐真实行高
    return WatchBandList(
      key: const PageStorageKey<String>('角色'),
      itemCount: 4,
      pitch: 52,
      itemBuilder: (context, _) => Skeletonizer.zone(
        child: const WatchRow(
          icon: Icons.person_outline_rounded,
          title: '加载中',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: widget.tabController,
      children: [
        // 概览 tab：简介 + 标签 + 次级操作（追番/外链）
        SingleChildScrollView(
          key: const PageStorageKey<String>('概览'),
          child: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                widget.isLoading ? infoBodyBone : infoBody,
                // 次级操作由 info_page 传入，放在概览内容最下方
                widget.secondaryActions,
              ],
            ),
          ),
        ),
        InfoCommentsView(
          interest: widget.bangumiItem.interest,
          comments: widget.commentsList,
          isLoading: widget.commentsIsLoading,
          hasLoaded: widget.commentsHasLoaded,
          hasError: widget.commentsQueryTimeout,
          onReviewTap: widget.onWriteReview,
          onRetry: () => widget.loadMoreComments(loadMore: false),
          onLoadMore: () => widget.loadMoreComments(loadMore: true),
        ),
        charactersListBody,
        relationsListBody,
        staffListBody,
      ],
    );
  }
}


