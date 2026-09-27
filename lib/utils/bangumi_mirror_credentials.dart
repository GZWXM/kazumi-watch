// Bangumi mirror API credentials for the search signature flow.
// Release/PR CI injects them via --dart-define=KAZUMI_APPID / KAZUMI_KEY.
const Map<String, String> bangumiMirrorCredentials = {
  'id': String.fromEnvironment('KAZUMI_APPID'),
  'value': String.fromEnvironment('KAZUMI_KEY'),
};

/// 镜像凭据是否可用（KAZUMI_APPID / KAZUMI_KEY 是构建期注入的）。
///
/// fork/自编译包拿不到这两个值 —— 此时**绝不能走镜像**：镜像要求 X-Signature，
/// 用空凭据算出来的签名会被判 401 `invalid request signature`，
/// 表现为"番剧能翻、一搜就挂"（推荐接口不签名，所以看着正常）。
bool get bangumiMirrorAvailable =>
    bangumiMirrorCredentials['id']!.isNotEmpty &&
    bangumiMirrorCredentials['value']!.isNotEmpty;
