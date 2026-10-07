import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/utils/device.dart';

/// Shrink-wraps in slivers and scrolls within bounded viewports.
class GeneralEmptyState extends StatelessWidget {
  const GeneralEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.actions = const [],
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final List<Widget> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isWatch = isRoundWatch(MediaQuery.sizeOf(context));
    
    // Watch 下恒 compact，且强制使用指定的紧凑尺寸
    final effectiveCompact = isWatch || compact;

    return Center(
      child: SingleChildScrollView(
        primary: false,
        padding: effectiveCompact
            ? const EdgeInsets.all(16)
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StateIconBadge(
                icon: icon,
                size: effectiveCompact ? 48 : 88,
                iconSize: effectiveCompact ? 24 : 36,
                backgroundColor: colorScheme.secondaryContainer,
                foregroundColor: colorScheme.onSecondaryContainer,
              ),
              SizedBox(height: effectiveCompact ? 16 : 24),
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style:
                      (effectiveCompact 
                          ? textTheme.titleMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w700)
                          : textTheme.titleLarge)?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: effectiveCompact ? null : FontWeight.w700,
                  ),
                ),
              ),
              if (actions.isNotEmpty) ...[
                SizedBox(height: effectiveCompact ? 16 : 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
