import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:port_helper/src/data/port_scanner.dart';
import 'package:port_helper/src/data/update_service.dart';
import 'package:port_helper/src/model/models.dart';
import 'package:port_helper/src/model/update_info.dart';
import 'package:port_helper/src/state/port_controller.dart';
import 'package:port_helper/src/state/update_controller.dart';
import 'package:port_helper/src/theme/app_theme.dart';
import 'package:port_helper/src/ui/home_page.dart';

/// netstat 的真实输出片段（中文表头在解码后是乱码，但数据行不变）。
const _netstatSample = '''
活动连接

  协议  本地地址          外部地址        状态           PID
  TCP    0.0.0.0:8080           0.0.0.0:0              LISTENING       18420
  TCP    127.0.0.1:8080         127.0.0.1:52133        ESTABLISHED     18420
  TCP    [::]:8080              [::]:0                 LISTENING       18420
  TCP    0.0.0.0:135            0.0.0.0:0              LISTENING       1024
  UDP    0.0.0.0:8080           *:*                                    9910
  UDP    [::]:5353              *:*                                    3044
''';

class _FakeScanner extends PortScanner {
  _FakeScanner({this.failing = false});

  final bool failing;

  @override
  Future<PortQueryResult> query(int port, ProtocolFilter filter) async {
    if (failing) {
      return PortQueryResult(
        port: port,
        bindings: const [],
        processes: const {},
        queriedAt: DateTime(2026, 11, 1, 14, 32, 8),
        error: 'netstat 响应超时',
      );
    }
    return PortQueryResult(
      port: port,
      bindings: PortScanner.parseNetstat(_netstatSample, port, filter),
      processes: const {
        18420: ProcessDetail(
          pid: 18420,
          name: 'node.exe',
          executablePath: r'C:\Program Files\nodejs\node.exe',
          description: 'Node.js JavaScript Runtime',
          parentPid: 14234,
          parentName: 'cmd.exe',
        ),
      },
      queriedAt: DateTime(2026, 11, 1, 14, 32, 8),
    );
  }

  @override
  Future<KillOutcome> kill(int pid) async => const KillOutcome(ok: true, message: 'ok');
}

Widget _host(PortController controller, {UpdateController? update}) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 920,
          height: 736,
          child: HomePage(controller: controller, updateController: update),
        ),
      ),
    ),
  );
}

/// 假装已经查到新版本，用来验证状态栏和弹窗的渲染。
class _FoundUpdateService extends UpdateService {
  @override
  Future<UpdateInfo?> check() async => const UpdateInfo(
        version: '9.9.9',
        code: 90909,
        downloadUrl: 'https://example.com/x.zip',
        sizeBytes: 11 * 1024 * 1024,
        isZip: true,
        releaseUrl: 'https://example.com',
        notes: '- 测试用更新说明',
      );
}

void main() {
  group('netstat 解析', () {
    test('抓出命中端口的监听行，TCP 先于 UDP、IPv4 先于 IPv6', () {
      final bindings = PortScanner.parseNetstat(_netstatSample, 8080, ProtocolFilter.all);
      // 2 条 TCP LISTENING + 1 条 UDP；ESTABLISHED 那条属于连接，不算占用。
      expect(bindings.length, 3);
      expect(bindings[0].protocol, 'TCP');
      expect(bindings[0].isIpv6, isFalse);
      expect(bindings[0].stateLabel, '监听中');
      expect(bindings[1].protocol, 'TCP');
      expect(bindings[1].isIpv6, isTrue);
      expect(bindings[2].protocol, 'UDP');
      expect(bindings[2].pid, 9910);
    });

    test('ESTABLISHED 连接不计入端口占用', () {
      final bindings = PortScanner.parseNetstat(_netstatSample, 8080, ProtocolFilter.all);
      expect(bindings.any((b) => b.state.toUpperCase() == 'ESTABLISHED'), isFalse);
      expect(bindings.every((b) => b.isListening), isTrue);
    });

    test('协议筛选生效', () {
      final tcp = PortScanner.parseNetstat(_netstatSample, 8080, ProtocolFilter.tcp);
      expect(tcp.every((b) => b.protocol == 'TCP'), isTrue);
      expect(tcp.length, 2);

      final udp = PortScanner.parseNetstat(_netstatSample, 8080, ProtocolFilter.udp);
      expect(udp.length, 1);
      expect(udp.single.protocol, 'UDP');
      expect(udp.single.pid, 9910);
      expect(udp.single.state, isEmpty);
    });

    test('无关端口与非法行被忽略', () {
      final bindings = PortScanner.parseNetstat(_netstatSample, 9999, ProtocolFilter.all);
      expect(bindings, isEmpty);
    });

    test('IPv6 地址能正确取到端口', () {
      final bindings = PortScanner.parseNetstat(
        '  TCP    [::1]:65535    [::]:0    LISTENING    42',
        65535,
        ProtocolFilter.all,
      );
      expect(bindings.single.port, 65535);
      expect(bindings.single.isIpv6, isTrue);
    });
  });

  group('查询结果模型', () {
    test('汇总文案按监听条数与去重进程数统计', () {
      final bindings = PortScanner.parseNetstat(_netstatSample, 8080, ProtocolFilter.all);
      final result = PortQueryResult(
        port: 8080,
        bindings: bindings,
        processes: const {},
        queriedAt: DateTime(2026),
      );
      expect(result.summaryLabel, '3 条监听 · 2 个进程');
      expect(result.protocolsFor(18420), ['TCP']);
      expect(result.hasBothStacksFor(18420), isTrue);
      expect(result.hasBothStacksFor(9910), isFalse);
    });

    test('启动时间按今天/昨天/日期分档', () {
      final now = DateTime.now();
      final today = ProcessDetail(
        pid: 1,
        name: 'a',
        startTime: DateTime(now.year, now.month, now.day, 10, 18, 32),
      );
      expect(today.formatStartTime(), '今天 10:18:32');

      final old = ProcessDetail(pid: 2, name: 'b', startTime: DateTime(2026, 10, 30, 9, 5, 1));
      expect(old.formatStartTime(), startsWith('2026-10-30'));

      expect(const ProcessDetail(pid: 3, name: 'c').formatStartTime(), '未知');
    });

    test('没有文件描述时副标题退回进程名', () {
      expect(const ProcessDetail(pid: 1, name: 'node.exe').subtitle, 'node.exe');
      expect(
        const ProcessDetail(pid: 1, name: 'node.exe', description: 'Node.js JavaScript Runtime').subtitle,
        'Node.js JavaScript Runtime',
      );
    });
  });

  group('控制器', () {
    test('写入非法端口时只保留数字并截断到 5 位', () {
      final c = PortController(scanner: _FakeScanner());
      c.setPortText('abc12345678');
      expect(c.portText, '12345');
      c.clearPort();
      expect(c.portText, isEmpty);
      c.dispose();
    });

    test('查询成功后默认选中第一条记录', () async {
      final c = PortController(scanner: _FakeScanner());
      c.setPortText('8080');
      await c.query();
      expect(c.result, isNotNull);
      expect(c.selectedPid, 18420);
      expect(c.selectedProcess?.name, 'node.exe');
      expect(c.statusText, '查询完成 · 找到 2 个进程');
      expect(c.statusKind, StatusKind.success);
      c.dispose();
    });

    test('查询失败时给出错误状态而不是空结果', () async {
      final c = PortController(scanner: _FakeScanner(failing: true));
      await c.query();
      expect(c.statusKind, StatusKind.error);
      expect(c.statusText, contains('超时'));
      c.dispose();
    });

    test('端口为空时不发请求，直接提示', () async {
      final c = PortController(scanner: _FakeScanner());
      c.clearPort();
      await c.query();
      expect(c.statusKind, StatusKind.warning);
      expect(c.result, isNull);
      c.dispose();
    });
  });

  group('页面冒烟', () {
    testWidgets('按设计稿渲染出四段式骨架与关键文案', (tester) async {
      tester.view.physicalSize = const Size(920, 736);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = PortController(scanner: _FakeScanner());
      await tester.pumpWidget(_host(controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('端口助手'), findsOneWidget);
      expect(find.text('端口占用查询'), findsOneWidget);
      expect(find.text('界面风格'), findsOneWidget);
      expect(find.text('占用结果'), findsOneWidget);
      expect(find.text('node.exe'), findsWidgets);
      expect(find.text('强制结束进程'), findsOneWidget);
      expect(find.textContaining('查询完成'), findsOneWidget);
    });

    testWidgets('有更新时状态栏出现入口，点开是更新弹窗', (tester) async {
      tester.view.physicalSize = const Size(920, 736);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = PortController(scanner: _FakeScanner());
      final update = UpdateController(service: _FoundUpdateService(), enabled: true);
      await tester.pumpWidget(_host(controller, update: update));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('新版本 v9.9.9'), findsOneWidget);

      await tester.tap(find.textContaining('新版本 v9.9.9'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('发现新版本'), findsOneWidget);
      expect(find.text('立即更新'), findsOneWidget);
      expect(find.text('稍后'), findsOneWidget);
    });

    testWidgets('点「强制结束进程」弹出确认框', (tester) async {
      tester.view.physicalSize = const Size(920, 736);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = PortController(scanner: _FakeScanner());
      await tester.pumpWidget(_host(controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('强制结束进程'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('强制结束此进程？'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('强制结束'), findsOneWidget);
    });
  });
}
