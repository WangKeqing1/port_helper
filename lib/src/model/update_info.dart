/// 一个可用的更新。
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.code,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.isZip,
    required this.releaseUrl,
    this.notes,
  });

  /// 纯版本号，如 `1.2.0`（去掉 tag 上的 v）。
  final String version;

  /// 用于比较和目录命名的整数版本码：1.2.0 → 10200。
  final int code;

  final String downloadUrl;
  final int sizeBytes;

  /// 下载的是 zip（推荐，体积小）还是 exe（SFX，需要从尾部抽 payload）。
  final bool isZip;

  final String releaseUrl;

  /// Release 说明正文，可能为空。
  final String? notes;

  String get sizeLabel {
    if (sizeBytes <= 0) return '未知大小';
    final mb = sizeBytes / 1024 / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

/// 版本号和整数码互转。
///
/// 用整数码是为了能在一处比较、也能直接当缓存目录名（目录名不能有小数点带来的歧义）。
abstract final class AppVersion {
  /// 编译时注入：`--dart-define=APP_VERSION=1.2.0`。
  /// 本地直接 `flutter run` 时为空，此时不检查更新。
  static const String raw = String.fromEnvironment('APP_VERSION');

  /// 当前运行版本，未知时返回 `dev`。
  static String get current => raw.isEmpty ? 'dev' : raw;

  /// 是否具备更新检查条件（开发态不检查，免得一直提示）。
  static bool get isReleaseBuild => raw.isNotEmpty;

  static int codeOf(String version) {
    final parts = version.split('.');
    int at(int i) {
      if (i >= parts.length) return 0;
      final digits = parts[i].replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(digits) ?? 0;
    }

    return at(0) * 10000 + at(1) * 100 + at(2);
  }
}
