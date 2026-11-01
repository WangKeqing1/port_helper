// 性能基准：把一次完整查询拆开计时，看清每一段的耗时。
// 用法：dart run tool/bench.dart [端口]
import 'dart:io';

import 'package:port_helper/src/data/port_scanner.dart';
import 'package:port_helper/src/data/win32_process.dart';
import 'package:port_helper/src/model/models.dart';

Future<void> main(List<String> args) async {
  final port = int.tryParse(args.isNotEmpty ? args.first : '') ?? 135;
  final scanner = PortScanner();

  // 预热一次，把 DLL 加载和首次 JIT 的开销排除掉。
  await scanner.query(port, ProtocolFilter.all);

  final samples = <double>[];
  for (var i = 0; i < 5; i++) {
    final sw = Stopwatch()..start();
    final r = await scanner.query(port, ProtocolFilter.all);
    sw.stop();
    samples.add(sw.elapsedMicroseconds / 1000);
    if (i == 0) {
      stdout.writeln('查询结果：${r.summaryLabel}');
      for (final pid in r.pids) {
        final d = r.detailFor(pid);
        stdout.writeln('  PID $pid  ${d?.name}  ${d?.userName ?? '-'}  ${d?.subtitle}');
      }
    }
  }

  final sorted = [...samples]..sort();
  final avg = samples.reduce((a, b) => a + b) / samples.length;
  stdout.writeln('\n完整查询耗时（${samples.length} 次）：');
  stdout.writeln('  最小 ${sorted.first.toStringAsFixed(1)} ms');
  stdout.writeln('  中位 ${sorted[sorted.length ~/ 2].toStringAsFixed(1)} ms');
  stdout.writeln('  平均 ${avg.toStringAsFixed(1)} ms');
  stdout.writeln('  最大 ${sorted.last.toStringAsFixed(1)} ms');

  // 单独量一下 FFI 各段。
  final pids = (await scanner.query(port, ProtocolFilter.all)).pids;
  if (pids.isNotEmpty) {
    final sw = Stopwatch()..start();
    for (var i = 0; i < 20; i++) {
      Win32Process.snapshot();
    }
    sw.stop();
    stdout.writeln('\n进程快照：${(sw.elapsedMicroseconds / 20 / 1000).toStringAsFixed(2)} ms/次');

    final pid = pids.first;
    final sw2 = Stopwatch()..start();
    for (var i = 0; i < 20; i++) {
      Win32Process.imagePath(pid);
    }
    sw2.stop();
    stdout.writeln('取路径：  ${(sw2.elapsedMicroseconds / 20 / 1000).toStringAsFixed(2)} ms/次');

    final sw3 = Stopwatch()..start();
    for (var i = 0; i < 20; i++) {
      Win32Process.userName(pid);
    }
    sw3.stop();
    stdout.writeln('取属主：  ${(sw3.elapsedMicroseconds / 20 / 1000).toStringAsFixed(2)} ms/次');
  }
}
