import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 应用图标母版渲染。
///
/// 不用 Material 字形而手绘，是因为字形的笔画在 16px 下不足一个像素，
/// 任务栏里会糊成一团。这里全部用粗笔画（最细处也有 8.8% 画布宽），
/// 从 16px 到 256px 都能认出来。
///
/// 用法：flutter test test/icon_test.dart --update-goldens
/// 产物 test/icons/app_icon_1024.png，再由 tool/make_icon.py 转成多尺寸 .ico。

const _materialIcons =
    r'C:\Users\mashiro\develop\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf';

Future<void> _registerIconFont() async {
  final file = File(_materialIcons);
  if (!file.existsSync()) return;
  final bytes = file.readAsBytesSync();
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

/// 电源断开符号：开口圆环 + 顶部竖线。笔画粗，缩到 16px 也不会糊。
class _PowerGlyphPainter extends CustomPainter {
  const _PowerGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.082
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final center = Offset(s * 0.5, s * 0.558);
    final radius = s * 0.19;
    // 顶部留口，开口约 60°。
    const gap = 1.05;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + gap / 2,
      2 * math.pi - gap,
      false,
      paint,
    );

    canvas.drawLine(
      Offset(s * 0.5, s * 0.292),
      Offset(s * 0.5, s * 0.452),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  setUpAll(_registerIconFont);

  testWidgets('render app icon', (tester) async {
    const size = 1024.0;
    tester.view.physicalSize = const Size(size, size);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        // 不套 MaterialApp，外层保持透明，圆角以外才能透出去。
        child: Center(
          child: SizedBox(
            width: size,
            height: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF8B77D6), Color(0xFF6750A4), Color(0xFF4A3680)],
                  stops: [0.0, 0.55, 1.0],
                ),
                borderRadius: BorderRadius.circular(size * 0.225),
              ),
              child: const CustomPaint(painter: _PowerGlyphPainter()),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(SizedBox).first,
      matchesGoldenFile('icons/app_icon_1024.png'),
    );
  });
}
