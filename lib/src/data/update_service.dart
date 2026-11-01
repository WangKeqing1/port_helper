import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../model/update_info.dart';

/// 和启动器共用的缓存目录约定。
///
/// 目录结构：
/// ```
/// %LOCALAPPDATA%\PortHelper\
/// ├─ current.txt     当前生效的版本码
/// ├─ 10200\          版本 1.2.0 的解压目录
/// └─ 10100\
/// ```
/// 启动器每次启动读 current.txt，决定拉起哪个目录里的程序。
abstract final class UpdateLayout {
  static const repo = 'WangKeqing1/port_helper';

  /// SFX 尾标：magic(8) + payload 长度(8) + 版本码(4) + 保留(4)。
  static const int sfxMagic = 0x504F525448454C50; // 'PORTHELP'
  static const int sfxTailSize = 24;

  static String get rootPath {
    final base = Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;
    return '$base\\PortHelper';
  }

  static Directory get root => Directory(rootPath);

  static File get pointer => File('$rootPath\\current.txt');

  static Directory versionDir(int code) => Directory('$rootPath\\$code');

  /// 当前正在运行的目录（从可执行文件位置反推）。
  static Directory get runningDir => File(Platform.resolvedExecutable).parent;

  /// 启动器路径。由启动器通过环境变量传给应用，用于更新完成后重启自身。
  static String? get launcherPath {
    final path = Platform.environment['PORT_HELPER_LAUNCHER'];
    if (path == null || path.isEmpty) return null;
    return File(path).existsSync() ? path : null;
  }
}

class UpdateException implements Exception {
  UpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 检查 / 下载 / 落盘三件事，UI 只管调用和展示进度。
class UpdateService {
  UpdateService({this.timeout = const Duration(seconds: 10)});

  final Duration timeout;

  /// 请求 GitHub 最新的 Release，返回比当前版本新的一条；没有则 null。
  ///
  /// 仓库是公开的，不需要 token。GitHub 强制要求 User-Agent。
  Future<UpdateInfo?> check() async {
    if (!AppVersion.isReleaseBuild) return null;

    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final uri = Uri.parse('https://api.github.com/repos/${UpdateLayout.repo}/releases/latest');
      final request = await client.getUrl(uri).timeout(timeout);
      request.headers
        ..set('User-Agent', 'port-helper')
        ..set('Accept', 'application/vnd.github+json');
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateException('检查更新失败（HTTP ${response.statusCode}）');
      }

      final body = await response.transform(utf8.decoder).join().timeout(timeout);
      final json = jsonDecode(body);
      if (json is! Map) throw UpdateException('更新信息格式异常');

      final tag = (json['tag_name'] as String?)?.trim() ?? '';
      if (tag.isEmpty) return null;
      final version = tag.replaceFirst(RegExp(r'^[vV]'), '');
      final code = AppVersion.codeOf(version);
      if (code <= AppVersion.codeOf(AppVersion.current)) return null;

      final assets = (json['assets'] as List?) ?? const [];
      Map<dynamic, dynamic>? zip;
      Map<dynamic, dynamic>? exe;
      for (final asset in assets) {
        if (asset is! Map) continue;
        final name = (asset['name'] as String?)?.toLowerCase() ?? '';
        if (name.endsWith('.zip')) {
          zip ??= asset;
        } else if (name.endsWith('.exe')) {
          exe ??= asset;
        }
      }
      // 优先 zip：11MB 对比 17MB，而且不用再从 SFX 尾部抽 payload。
      final chosen = zip ?? exe;
      if (chosen == null) return null;

      final url = chosen['browser_download_url'] as String?;
      if (url == null || url.isEmpty) return null;

      return UpdateInfo(
        version: version,
        code: code,
        downloadUrl: url,
        sizeBytes: (chosen['size'] as num?)?.toInt() ?? 0,
        isZip: identical(chosen, zip),
        releaseUrl: (json['html_url'] as String?) ?? 'https://github.com/${UpdateLayout.repo}/releases',
        notes: (json['body'] as String?)?.trim(),
      );
    } on TimeoutException {
      throw UpdateException('检查更新超时');
    } on SocketException catch (e) {
      throw UpdateException('网络不可用：${e.message}');
    } finally {
      client.close(force: true);
    }
  }

  /// 下载到临时文件，边下边回报进度。
  Future<File> download(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    final suffix = info.isZip ? 'zip' : 'exe';
    final target = File('${Directory.systemTemp.path}\\port_helper_update_${info.code}.$suffix');

    try {
      final request = await client.getUrl(Uri.parse(info.downloadUrl)).timeout(timeout);
      request.headers.set('User-Agent', 'port-helper');
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateException('下载失败（HTTP ${response.statusCode}）');
      }

      final sink = target.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.timeout(timeout)) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, info.sizeBytes);
        }
      } finally {
        await sink.close();
      }

      if (info.sizeBytes > 0 && received != info.sizeBytes) {
        throw UpdateException('下载不完整（$received / ${info.sizeBytes} 字节）');
      }
      return target;
    } on TimeoutException {
      throw UpdateException('下载超时，请检查网络后重试');
    } on SocketException catch (e) {
      throw UpdateException('下载失败：${e.message}');
    } finally {
      client.close(force: true);
    }
  }

  /// 把下载到的包解到新版本目录，并切换 current.txt。
  ///
  /// 启动器下次启动就会拉起新目录里的程序，所以这里不需要改动正在运行的 exe。
  Future<void> apply(File downloaded, UpdateInfo info) async {
    final payload = await _readPayload(downloaded, info);
    final dir = UpdateLayout.versionDir(info.code);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    dir.createSync(recursive: true);

    _extractZip(payload, dir);

    if (!File('${dir.path}\\port_helper.exe').existsSync()) {
      throw UpdateException('解压后没有找到主程序，更新包可能不完整');
    }

    UpdateLayout.pointer.parent.createSync(recursive: true);
    UpdateLayout.pointer.writeAsStringSync('${info.code}', flush: true);

    // 下载的临时文件用完就删。
    try {
      if (downloaded.existsSync()) downloaded.deleteSync();
    } catch (_) {
      // 删不掉也不影响使用。
    }
  }

  /// zip 直接用；exe 是 SFX，要从尾部尾标里抽出内嵌的 zip。
  Future<Uint8List> _readPayload(File downloaded, UpdateInfo info) async {
    final bytes = await downloaded.readAsBytes();
    if (info.isZip) return bytes;

    const tailSize = UpdateLayout.sfxTailSize;
    if (bytes.length < tailSize) throw UpdateException('更新包损坏');
    final tail = ByteData.sublistView(bytes, bytes.length - tailSize);
    if (tail.getUint64(0, Endian.little) != UpdateLayout.sfxMagic) {
      throw UpdateException('更新包格式不正确');
    }
    final length = tail.getUint64(8, Endian.little);
    final start = bytes.length - tailSize - length;
    if (length <= 0 || start < 0) throw UpdateException('更新包损坏');
    return Uint8List.sublistView(bytes, start, bytes.length - tailSize);
  }

  void _extractZip(Uint8List payload, Directory target) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(payload, verify: false);
    } catch (e) {
      throw UpdateException('解压失败：$e');
    }

    for (final entry in archive) {
      if (!entry.isFile) continue;
      var name = entry.name.replaceAll('\\', '/');
      // 包内有一层 port_helper/ 前缀，剥掉。
      final slash = name.indexOf('/');
      if (slash >= 0) name = name.substring(slash + 1);
      if (name.isEmpty) continue;

      final out = File('${target.path}\\${name.replaceAll('/', '\\')}');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(entry.content as List<int>, flush: true);
    }
  }

  /// 拉起启动器，当前进程随后退出。
  Future<bool> restart() async {
    final launcher = UpdateLayout.launcherPath;
    if (launcher == null) return false;
    await Process.start(
      launcher,
      const [],
      mode: ProcessStartMode.detached,
      workingDirectory: File(launcher).parent.path,
    );
    return true;
  }
}
