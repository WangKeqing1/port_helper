import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'src/theme/app_theme.dart';
import 'src/theme/tokens.dart';
import 'src/ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: Size(Tokens.windowWidth, Tokens.windowHeight),
    minimumSize: Size(Tokens.windowWidth, Tokens.windowHeight),
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
    title: '端口助手',
    windowButtonVisibility: false,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setResizable(false);
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const PortHelperApp());
}

class PortHelperApp extends StatelessWidget {
  const PortHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '端口助手',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const Scaffold(
        // 窗口本身透明，圆角由内容层裁出来。
        backgroundColor: Colors.transparent,
        body: Center(
          child: SizedBox(
            width: Tokens.windowWidth,
            height: Tokens.windowHeight,
            child: HomePage(),
          ),
        ),
      ),
    );
  }
}
