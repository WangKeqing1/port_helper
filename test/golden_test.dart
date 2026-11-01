import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:port_helper/src/data/port_scanner.dart';
import 'package:port_helper/src/model/models.dart';
import 'package:port_helper/src/state/port_controller.dart';
import 'package:port_helper/src/theme/app_theme.dart';
import 'package:port_helper/src/ui/home_page.dart';

import 'support/test_fonts.dart';

/// 金标渲染：把界面按 1× 物理像素画出来，和 Figma 导出的 PNG 逐像素对照。
///
/// 中文字体和图标字体在测试环境里不会自动加载，必须手动喂进来，
/// 否则所有文字和图标都会变成方块（见 [TestFonts]）。

/// 和设计稿一致的 netstat 样本：8080 上两条 TCP 监听（IPv4 + IPv6），同一个 PID。
const _designNetstat = '''
  TCP    0.0.0.0:8080           0.0.0.0:0              LISTENING       18420
  TCP    [::]:8080              [::]:0                 LISTENING       18420
''';

class _DesignScanner extends PortScanner {
  @override
  Future<PortQueryResult> query(int port, ProtocolFilter filter) async {
    final now = DateTime.now();
    return PortQueryResult(
      port: port,
      bindings: PortScanner.parseNetstat(_designNetstat, port, filter),
      processes: {
        18420: ProcessDetail(
          pid: 18420,
          name: 'node.exe',
          executablePath: r'C:\Program Files\nodejs\node.exe',
          description: 'Node.js JavaScript Runtime',
          startTime: DateTime(now.year, now.month, now.day, 10, 18, 32),
          userName: '本地用户',
          parentPid: 14234,
          parentName: 'cmd.exe',
        ),
      },
      queriedAt: DateTime(now.year, now.month, now.day, 14, 32, 8),
    );
  }

  @override
  Future<KillOutcome> kill(int pid) async => const KillOutcome(ok: true, message: 'ok');
}

Widget _host(PortController controller) {
  return MaterialApp(
    theme: buildAppTheme(),
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: const Color(0xFFE8E0EE),
      body: Center(
        child: SizedBox(width: 920, height: 736, child: HomePage(controller: controller)),
      ),
    ),
  );
}

void main() {
  // CI 上字体版本和抗锯齿跟本地未必一致，逐像素比对容易误报，
  // 所以金标只在本地跑。CI 覆盖的是 widget_test 里的逻辑与冒烟用例。
  final skipOnCi = TestFonts.isCi;

  setUpAll(() async {
    if (TestFonts.isCi) return;
    final ok = await TestFonts.registerAll();
    if (!ok) {
      // ignore: avoid_print
      print('⚠ 字体未全部就绪，golden 结果可能和基准图有差异');
    }
  });

  Future<PortController> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(920, 736);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = PortController(scanner: _DesignScanner());
    await tester.pumpWidget(_host(controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return controller;
  }

  testWidgets('golden: 查询结果', (tester) async {
    await pumpHome(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/01_result.png'),
    );
  }, skip: skipOnCi);

  testWidgets('golden: 结束确认', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('强制结束进程'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/02_confirm.png'),
    );
  }, skip: skipOnCi);

  testWidgets('golden: 界面风格', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('界面风格'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/03_style.png'),
    );
  }, skip: skipOnCi);
}
