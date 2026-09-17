import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/bean/widget/watch_scaffold.dart';
import 'package:kazumi/bean/widget/watch_list.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final List<String> _logLines = [];
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _hasError = false;
  String _fullContent = '';

  static const int _initialLoadCount = 50;
  static const int _loadMoreCount = 100;
  int _displayedLines = 0;
  List<String> _allLines = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || _displayedLines >= _allLines.length) {
      return;
    }

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = maxScroll * 0.8;

    if (currentScroll >= threshold) {
      _loadMoreLines();
    }
  }

  Future<void> _loadLogs() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final file = await _getLogsFile();
      if (!mounted) return;

      if (await file.exists()) {
        final content = await file.readAsString();
        if (!mounted) return;

        _allLines = content.split('\n');
        _fullContent = content;

        final initialCount = _allLines.length < _initialLoadCount
            ? _allLines.length
            : _initialLoadCount;

        setState(() {
          _logLines.clear();
          _logLines.addAll(_allLines.take(initialCount));
          _displayedLines = initialCount;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _loadMoreLines() {
    if (_displayedLines >= _allLines.length) {
      return;
    }

    Future.microtask(() {
      if (!mounted) return;

      final remainingLines = _allLines.length - _displayedLines;
      final linesToLoad =
          remainingLines < _loadMoreCount ? remainingLines : _loadMoreCount;

      final newLines = _allLines.skip(_displayedLines).take(linesToLoad);

      setState(() {
        _logLines.addAll(newLines);
        _displayedLines += linesToLoad;
      });
    });
  }

  Future<File> _getLogsFile() async {
    final directory = await getApplicationSupportDirectory();
    final path = directory.path;
    return File('$path/logs/kazumi_logs.log');
  }

  Future<void> _clearLogs() async {
    try {
      final file = await _getLogsFile();
      await file.writeAsString('');
      if (!mounted) return;

      setState(() {
        _logLines.clear();
        _allLines.clear();
        _fullContent = '';
        _displayedLines = 0;
      });
    } catch (e) {
      if (!mounted) return;
      KazumiDialog.showToast(message: '清空失败: $e');
    }
  }

  Future<void> _copyLogs() async {
    try {
      await Clipboard.setData(ClipboardData(text: _fullContent));
      if (!mounted) return;
      KazumiDialog.showToast(message: '已复制到剪贴板');
    } catch (e) {
      if (!mounted) return;
      KazumiDialog.showToast(message: '复制失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WatchScaffold(
      title: '日志',
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: LoadingIndicator(),
      );
    }

    if (_hasError) {
      return GeneralErrorWidget(
        title: '无法读取日志',
        errMsg: '请稍后重新加载。',
        icon: Icons.receipt_long_rounded,
        onRetry: _loadLogs,
      );
    }

    if (_logLines.isEmpty) {
      return const GeneralEmptyState(
        icon: Icons.receipt_long_rounded,
        title: '还没有日志记录',
      );
    }

    // Total items: log lines + 1 action row at the end
    final totalItems = _logLines.length + 1;

    return SelectionArea(
      child: WatchBandList(
        controller: _scrollController,
        itemCount: totalItems,
        pitch: 44.0,   // 日志行与末行按钮统一 44dp 槽位；pitch 必须 ≥ 槽位高，否则行间重叠
        itemBuilder: (context, index) {
          if (index < _logLines.length) {
            return _buildLogLine(index);
          } else {
            return _buildActionRow();
          }
        },
      ),
    );
  }

  Widget _buildLogLine(int index) {
    final theme = Theme.of(context);
    // 规范：monospace 12 → 11
    return SizedBox(
      height: 44, // 与 pitch 一致
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _logLines[index],
          softWrap: true, // Allow wrapping since no horizontal scroll
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 2,
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    return SizedBox(
      height: 44,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TonalButton(
              onPressed: _copyLogs,
              child: const Icon(Icons.copy, size: 16),
              label: '复制',
            ),
            const SizedBox(width: 8),
            _TonalButton(
              onPressed: _clearLogs,
              child: const Icon(Icons.clear_all, size: 16),
              label: '清空',
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper widget for the tonal buttons in logs page
class _TonalButton extends StatelessWidget {
  const _TonalButton({
    required this.onPressed,
    required this.child,
    required this.label,
  });

  final VoidCallback onPressed;
  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(76, 44), // Total width approx 160 with gap
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}
