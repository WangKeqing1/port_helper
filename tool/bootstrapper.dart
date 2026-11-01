// 单文件启动器（SFX）。
//
// 发布时 tool/build_exe.py 会把 App 的 Release 目录打成 zip，
// 追加到本程序 AOT 产物尾部，再把 PE 子系统改成 GUI，最终得到一个
// 双击即用、不弹任何对话框的 exe。
//
// 运行逻辑：
//   1. 读自身末尾 16 字节尾标（magic + payload 长度）
//   2. 用 payload 的 CRC32 作为缓存目录名，解压到 %LOCALAPPDATA%\PortHelper\<crc>
//   3. 启动真正的 port_helper.exe，自身立即退出
//
// 同版本二次启动直接命中缓存，只做一次文件存在性检查。
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// 'PORTHELP' 按小端读成 uint64。
const int _magic = 0x504F525448454C50;
const int _tailSize = 16;
const String _cacheRoot = 'PortHelper';
const String _appExe = 'port_helper.exe';

Future<void> main() async {
  try {
    await _run();
  } catch (_) {
    // 启动器不做 UI，失败就静默退出，避免弹出黑框或错误对话框。
    exit(1);
  }
}

Future<void> _run() async {
  final self = File(Platform.resolvedExecutable);
  final bytes = await self.readAsBytes();
  if (bytes.length < _tailSize) return;

  final tail = ByteData.sublistView(bytes, bytes.length - _tailSize);
  final magic = tail.getUint64(0, Endian.little);
  if (magic != _magic) {
    // 不是打包过的启动器（比如开发者直接跑），什么都不做。
    return;
  }
  final payloadLength = tail.getUint64(8, Endian.little);
  final start = bytes.length - _tailSize - payloadLength;
  if (payloadLength <= 0 || start < 0) return;

  final payload = Uint8List.sublistView(bytes, start, bytes.length - _tailSize);

  // 用内容指纹做目录名：换了版本自然落到新目录，不会残留旧文件。
  final fingerprint = getCrc32(payload).toRadixString(16);
  final base = Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;
  final appDir = Directory('$base\\$_cacheRoot\\$fingerprint');
  final exe = File('${appDir.path}\\$_appExe');

  if (!exe.existsSync()) {
    await _extract(payload, appDir);
  }

  await Process.start(
    exe.path,
    const [],
    mode: ProcessStartMode.detached,
    workingDirectory: appDir.path,
  );
}

/// 解压 payload。zip 内层有一层 `port_helper/` 目录，这里剥掉。
Future<void> _extract(Uint8List payload, Directory target) async {
  final archive = ZipDecoder().decodeBytes(payload, verify: false);
  for (final entry in archive) {
    if (!entry.isFile) continue;

    var name = entry.name.replaceAll('\\', '/');
    final slash = name.indexOf('/');
    if (slash >= 0) name = name.substring(slash + 1);
    if (name.isEmpty) continue;

    final out = File('${target.path}\\${name.replaceAll('/', '\\')}');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(entry.content as List<int>, flush: true);
  }
}
