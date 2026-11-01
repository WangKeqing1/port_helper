# 端口助手（port_helper）

Windows 桌面端端口占用查询工具。按 Figma 设计稿 1:1 还原，查询、详情、结束进程全部走真实系统调用。

## 设计来源

Figma 文件 `MVMDYZRqpjbNrRZwBaYHqd`，三个状态帧：

| 节点 | 状态 | 对应界面 |
| --- | --- | --- |
| `14:1587` | 查询结果 | 主界面 |
| `14:1707` | 结束确认 | 强制结束确认弹窗 |
| `14:1852` | 界面风格 | 右上角风格浮层 |

窗口尺寸 920×736，无系统标题栏（自绘标题栏 + 圆角窗口）。

## 功能

- **端口查询**：`netstat -ano` 解析监听行，支持「全部 / TCP / UDP」筛选
- **进程详情**：`Get-CimInstance Win32_Process` 取进程名、可执行路径、文件描述、启动时间、父进程链、运行用户
- **强制结束**：`taskkill /PID <pid> /T /F`，结束前弹出二次确认，结束后自动重查
- **快捷键**：`Enter` 查询、`F5` 刷新、`Esc` 关闭浮层或弹窗
- **复制路径**：进程路径一键复制到剪贴板

## 运行

```bash
flutter pub get
flutter run -d windows          # 开发调试
flutter build windows --release # 产物在 build/windows/x64/runner/Release/
```

也可以直接双击 `启动.bat`（内部走 release 产物）。

## 发布

**主推单文件 exe**：

```bash
flutter build windows --release
python tool/build_exe.py
```

产出 `dist/端口助手-1.0.0.exe`（约 17 MB），双击即用，一个文件搞定。

做法是把 Release 目录打成 zip，追加到一个小启动器（Dart AOT）尾部，
再把 PE 子系统改成 GUI 所以不闪黑框：

- 首次运行解压到 `%LOCALAPPDATA%\PortHelper\<内容CRC32>`，约 0.5s
- 之后命中缓存直接启动
- 换了版本内容指纹就变，自动落到新目录，旧目录可手动删

⚠️ 启动器必须单独注入图标：`dart compile exe` 产出的是**没有资源段**的 PE，
资源管理器只会显示默认图标。所以构建流程里用 `tool/bin/rcedit.exe` 把
`app_icon.ico` 和版本信息写进启动器，**且必须在拼接 payload 之前做** ——
rcedit 会重写 PE，会丢掉文件尾部的附加数据。

构建脚本最后会自动校验资源段，看到这几行才算成功：

```
校验最终 exe 的资源:
  资源类型: RT_ICON, RT_GROUP_ICON, RT_VERSION, 24
```

`tool/bin/rcedit.exe` 是 [electron/rcedit](https://github.com/electron/rcedit) v2.0.0，
用来改 PE 资源，MIT 协议。

**备选便携 zip**（需要完整目录、或要做绿色版时）：

```bash
python tool/package.py   # dist/port_helper-1.0.0-windows-x64.zip
```

Flutter 的 Windows 程序不能只发裸 exe —— 必须有 `flutter_windows.dll` 和 `data/`，
所以 zip 方案是整目录打包，解压后双击 `启动.bat`。

## 图标

图标不是外部素材，而是**渲染出来的**：`test/icon_test.dart` 用 CustomPainter
画一个电源断开符号（开口圆环 + 竖线），配 M3 紫色渐变，输出 1024px 母版；
`tool/make_icon.py` 再把母版转成 10 个尺寸的 `windows/runner/resources/app_icon.ico`。

```bash
flutter test test/icon_test.dart --update-goldens   # 重绘母版
python tool/make_icon.py                            # 生成多尺寸 ico
flutter build windows --release                     # 图标编进 exe
```

不用 Material 字形是因为它的笔画在 16px 下不足一个像素，任务栏里会糊成一团；
手绘的全是粗笔画，16px 下依然能认出形状。

## 目录结构

```
lib/
├─ main.dart                      入口 + 窗口初始化（无边框、固定尺寸）
└─ src/
   ├─ theme/tokens.dart           设计令牌：颜色 / 圆角 / 间距 / 阴影 / 字体
   ├─ theme/app_theme.dart        ThemeData（只装配令牌，不做推导）
   ├─ model/models.dart           监听记录、进程详情、查询结果
   ├─ data/port_scanner.dart      netstat 解析 + 编排
   ├─ data/win32_process.dart     Win32 FFI：进程名 / 路径 / 启动时间 / 属主 / 版本描述
   ├─ state/port_controller.dart  查询状态机
   └─ ui/
      ├─ home_page.dart           920×736 四段式拼装
      └─ widgets/                 标题栏 / 标题 / 查询 / 结果 / 详情 / 操作 / 状态栏 / 浮层 / 弹窗
tool/
├─ probe.dart                     命令行探针：不开界面直接验证系统调用
├─ bench.dart                     性能基准：拆段计时
├─ bootstrapper.dart              单文件 exe 的启动器（解压 + 拉起主程序）
├─ build_exe.py                   启动器 + 应用 → dist/端口助手-x.y.z.exe
├─ make_icon.py                   图标母版 → 多尺寸 ico
└─ package.py                     便携 zip 打包
```

## 测试

```bash
flutter test
```

- `test/widget_test.dart`：netstat 解析、模型格式化、控制器状态机、页面冒烟
- `test/golden_test.dart`：三个状态的像素级金标（`test/goldens/`）
- `test/icon_test.dart`：图标母版渲染（生成工具，不是回归测试）
- `test/support/test_fonts.dart`：测试字体装配。图标字体路径不写死，从 flutter_tester 位置反推 SDK 根目录，本地和 CI 都能用

> 注意：如果本机设置了 `HTTP_PROXY` / `HTTPS_PROXY`，`flutter test` 会因为
> flutter_tester 的本地 WebSocket 走代理而报 `Invalid WebSocket upgrade request`。
> 跑测试前清掉代理变量即可：`env -u HTTP_PROXY -u HTTPS_PROXY flutter test`。

golden 和 icon 用例在 CI 上会自动跳过（`CI=true` 时），因为远程环境的字体版本和
抗锯齿跟本地不完全一致，逐像素比对容易误报。CI 覆盖的是逻辑与冒烟部分。

## 持续集成与发版

两个 workflow，都在 `.github/workflows/`：

| 文件 | 触发 | 做什么 |
| --- | --- | --- |
| `ci.yml` | push / PR 到 main | `flutter analyze` + `flutter test`（windows-latest，约 3 分钟） |
| `release.yml` | push 到 main / 手动 | 版本号有变化时构建并发布 Release |

### 日常发版流程

```bash
# 1. 改代码
# 2. 改版本号
#    pubspec.yaml: version: 1.0.1+2
git commit -am "fix: xxx"
git push
```

推上去之后，`release.yml` 会读 `pubspec.yaml` 的 version：

- tag `v1.0.1` 不存在 → 构建 → 打 tag → 创建 Release 并附上单文件 exe
- tag 已存在（版本号没改）→ 跳过构建，只留 CI 跑测试

**所以发版的关键就是记得改版本号。** 只改代码不改版本号不会触发发布。

需要重发同一个版本时，去 Actions 页面手动跑 `Release`，勾上 `force`。

### 额度

私有仓库的 GitHub Free 每月有 $12 计算额度（Windows runner $0.010/分钟，
折合约 1200 分钟）。一次完整发布约 8 分钟，个人开发完全够用。

额度用尽不会自动扣费 —— 默认 spending limit 是 $0，任务直接失败，下月重置。
改成公开仓库则标准 runner 完全免费。

## 已知限制

- 结束系统级进程需要管理员权限，普通权限下 `taskkill` 会返回「拒绝访问」，状态栏会如实显示。
- 部分受保护进程（如 `System`、`csrss.exe`）读不到 `ExecutablePath`，详情里显示为提示文案。
- 窗口尺寸固定 920×736，中间那个正方形按钮不响应点击。
