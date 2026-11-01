"""把 Release 产物打成可分发 zip。

Flutter 的 Windows 程序不能只发 exe —— 还要带上 flutter_windows.dll 和 data/，
所以整目录打包，解压即用。

用法：python tool/package.py
"""
import re
import sys
import zipfile
from pathlib import Path

# Windows CI / 精简终端的 stdout 可能是 cp1252，打印中文会抛 UnicodeEncodeError。
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = Path(__file__).resolve().parent.parent
RELEASE = ROOT / "build" / "windows" / "x64" / "runner" / "Release"
DIST = ROOT / "dist"
APP = "port_helper"


def read_version() -> str:
    text = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    m = re.search(r"^version:\s*([0-9.]+)", text, re.MULTILINE)
    return m.group(1) if m else "0.0.0"


def main() -> None:
    exe = RELEASE / f"{APP}.exe"
    if not exe.exists():
        raise SystemExit(f"还没构建：{exe}\n先跑 flutter build windows --release")

    version = read_version()
    DIST.mkdir(exist_ok=True)
    target = DIST / f"{APP}-{version}-windows-x64.zip"

    files = sorted(p for p in RELEASE.rglob("*") if p.is_file())
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for f in files:
            arc = Path(APP) / f.relative_to(RELEASE)
            zf.write(f, arc.as_posix())
        # 压缩包里的启动脚本和开发目录那份不一样：这里 exe 就在同级目录。
        zf.writestr(
            f"{APP}/启动.bat",
            "@echo off\r\n"
            "chcp 65001 >nul\r\n"
            'cd /d "%~dp0"\r\n'
            f'start "" "{APP}.exe"\r\n',
        )

    total = target.stat().st_size
    print(f"已打包 {len(files)} 个文件 -> {target}")
    print(f"体积 {total / 1024 / 1024:.1f} MB")
    print("\n解压后双击 启动.bat 或 {0}/{0}.exe 即可运行。".format(APP))


if __name__ == "__main__":
    main()
