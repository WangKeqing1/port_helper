// 单文件启动器（SFX）。
//
// 发布时 tool/build_exe.py 会把 App 的 Release 目录打成 zip，
// 追加到本程序 AOT 产物尾部，再把 PE 子系统改成 GUI，最终得到一个
// 双击即用、不弹任何对话框的 exe。
//
// 启动逻辑：
//   1. 读自身末尾 24 字节尾标（magic + payload 长度 + 内置版本码）
//   2. 读 %LOCALAPPDATA%\PortHelper\current.txt，看有没有比内置更新的版本
//   3. 有就用它，没有就解压内置 payload 到 <版本码> 目录并写指针
//   4. 拉起 port_helper.exe，并把自身路径通过环境变量传下去（更新后靠它重启）
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

const int _magic = 0x504F525448454C50; // 'PORTHELP'
const int _tailSize = 24; // magic(8) + payloadLen(8) + versionCode(4) + reserved(4)
const String _cacheRoot = 'PortHelper';
const String _appExe = 'port_helper.exe';

/// 传给应用的启动器路径，应用更新完成后用它拉起新版本。
const String _launcherEnv = 'PORT_HELPER_LAUNCHER';

Future<void> main() async {
  try {
    await _run();
  } catch (_) {
    // 启动器不做 UI，失败就静默退出。
    exit(1);
  }
}

Future<void> _run() async {
  final self = File(Platform.resolvedExecutable);
  final bytes = await self.readAsBytes();
  if (bytes.length < _tailSize) return;

  final tail = ByteData.sublistView(bytes, bytes.length - _tailSize);
  if (tail.getUint64(0, Endian.little) != _magic) {
    // 不是打包过的启动器（比如开发者直接跑），什么都不做。
    return;
  }
  final payloadLength = tail.getUint64(8, Endian.little);
  final builtinCode = tail.getUint32(16, Endian.little);
  final start = bytes.length - _tailSize - payloadLength;
  if (payloadLength <= 0 || start < 0) return;

  final base = Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;
  final root = Directory('$base\\$_cacheRoot');
  final pointer = File('${root.path}\\current.txt');

  final activeCode = _resolveActiveCode(root, pointer, builtinCode) ??
      await _installBuiltin(bytes, start, payloadLength, root, pointer, builtinCode);

  var exe = File('${root.path}\\$activeCode\\$_appExe');
  if (!exe.existsSync()) {
    // 指针指向的目录被误删，退回内置 payload 重新解压。
    final repaired = await _installBuiltin(bytes, start, payloadLength, root, pointer, builtinCode);
    exe = File('${root.path}\\$repaired\\$_appExe');
  }

  await _launch(exe, self.path);
}

/// 找出应当启动的版本码：只在「指针有效且不低于内置版本」时才用它。
int? _resolveActiveCode(Directory root, File pointer, int builtinCode) {
  if (!pointer.existsSync()) return null;
  final code = int.tryParse(pointer.readAsStringSync().trim());
  if (code == null || code < builtinCode) return null;
  if (!File('${root.path}\\$code\\$_appExe').existsSync()) return null;
  return code;
}

/// 把内置 payload 解压到 `<版本码>` 目录，并把指针指过去。
Future<int> _installBuiltin(
  Uint8List bytes,
  int start,
  int payloadLength,
  Directory root,
  File pointer,
  int code,
) async {
  final target = Directory('${root.path}\\$code');
  final exe = File('${target.path}\\$_appExe');
  if (!exe.existsSync()) {
    final payload = Uint8List.sublistView(bytes, start, bytes.length - _tailSize);
    await _extract(payload, target);
  }
  pointer.parent.createSync(recursive: true);
  pointer.writeAsStringSync('$code', flush: true);
  return code;
}

Future<void> _launch(File exe, String launcherPath) async {
  await Process.start(
    exe.path,
    const [],
    mode: ProcessStartMode.detached,
    workingDirectory: exe.parent.path,
    // 父进程环境会自动带上，这里只追加一个键。
    environment: {_launcherEnv: launcherPath},
    includeParentEnvironment: true,
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
