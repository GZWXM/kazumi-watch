import 'dart:async';

import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/network/metered_network_service.dart';
import 'package:kazumi/services/player/low_memory_mode.dart';
import 'package:kazumi/utils/async_serial_queue.dart';
import 'package:kazumi/utils/device.dart';
import 'package:media_kit/media_kit.dart';

class PlaybackCachePolicy {
  PlaybackCachePolicy({
    required bool Function() isLocalPlayback,
    required Player? Function() currentPlayer,
  })  : _isLocalPlayback = isLocalPlayback,
        _currentPlayer = currentPlayer;

  static const int _lowMemoryBufferSize = 2 * 1024 * 1024;
  static const int _defaultBufferSize = 1500 * 1024 * 1024;

  /// HLS 变体码率上限（bps），仅在低分辨率设备（手表）上启用。
  /// 约 800 kbps 对应常见番剧源的 480p 档附近，避免在小屏上拉 1080p：
  /// 省解码功耗、省计量流量。
  static const String _watchHlsBitrateCap = '800000';

  final bool Function() _isLocalPlayback;
  final Player? Function() _currentPlayer;
  final AsyncSerialQueue _writes = AsyncSerialQueue();

  StreamSubscription<void>? _settingsSubscription;

  bool get networkAutomatic =>
      LowMemoryMode.current == LowMemoryMode.auto &&
      !_isLocalPlayback() &&
      MeteredNetworkService.isMetered;

  int get bufferSize => LowMemoryMode.current.isEnabled(
        isMetered: MeteredNetworkService.isMetered,
        isLocalPlayback: _isLocalPlayback(),
      )
          ? _lowMemoryBufferSize
          : _defaultBufferSize;

  void startWatching() {
    if (_settingsSubscription != null) {
      return;
    }
    _settingsSubscription = LowMemoryMode.watch().listen((_) => _onChanged());
    MeteredNetworkService.listenable.addListener(_onChanged);
  }

  void stopWatching() {
    MeteredNetworkService.listenable.removeListener(_onChanged);
    unawaited(_settingsSubscription?.cancel());
    _settingsSubscription = null;
  }

  Future<void> apply() async {
    final player = _currentPlayer();
    if (player == null) {
      return;
    }
    try {
      final pp = player.platform as NativePlayer;
      // A stale player's initialization must not block its replacement's writes.
      await pp.waitForPlayerInitialization;
      await _writes.run(() async {
        if (!identical(_currentPlayer(), player)) {
          return;
        }
        final size = bufferSize.toString();
        await pp.setProperty('demuxer-max-bytes', size);
        await pp.setProperty('demuxer-max-back-bytes', size);
        // 手表优化：低分辨率屏幕上限制 HLS 变体码率，避免拉 1080p 档位。
        try {
          if (await isLowResolution()) {
            await pp.setProperty('hls-bitrate', _watchHlsBitrateCap);
          }
        } catch (_) {
          // 非致命：属性不被支持或设备信息不可用，忽略即可。
        }
      });
    } catch (e) {
      KazumiLogger().w(
        'PlaybackCachePolicy: failed to apply demuxer cache size',
        error: e,
      );
    }
  }

  void _onChanged() {
    unawaited(apply());
  }
}
