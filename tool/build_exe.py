"""把 Flutter 的 Release 目录打成一个可直接双击的单文件 exe。

产物形态：bootstrapper(AOT) + app.zip + 16 字节尾标，
再把 PE 子系统改成 GUI，双击不留黑框。

用法：python tool/build_exe.py
前置：flutter build windows --release
"""
import argparse
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

# Windows CI（和部分精简终端）的 stdout 是 cp1252，打印中文会直接抛
# UnicodeEncodeError。这里强制切到 UTF-8。
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:  # 老版本 Python 或被重定向到不支持 reconfigure 的对象
    pass

ROOT = Path(__file__).resolve().parent.parent
RELEASE = ROOT / "build" / "windows" / "x64" / "runner" / "Release"
DIST = ROOT / "dist"
APP = "port_helper"
MAGIC = 0x504F525448454C50  # 'PORTHELP'
# magic(8) + payload 长度(8) + 内置版本码(4) + 保留(4)
TAIL = struct.Struct("<QQII")


def version_code(version: str) -> int:
    """1.2.0 → 10200。启动器和应用都用这个整数比较版本、当缓存目录名。"""
    parts = []
    for chunk in version.split(".")[:3]:
        digits = "".join(c for c in chunk if c.isdigit())
        parts.append(int(digits) if digits else 0)
    while len(parts) < 3:
        parts.append(0)
    return parts[0] * 10000 + parts[1] * 100 + parts[2]


def stamp_resources(exe: Path, version: str) -> None:
    """给启动器注入图标和版本信息。

    Dart AOT 产物没有资源段，资源管理器只能显示默认图标，
    所以编译完必须再用 rcedit 把 .ico 和版本串写进去。
    这一步要排在拼接 payload 之前 —— rcedit 会重写 PE，会丢掉文件尾部的附加数据。
    """
    rcedit = ROOT / "tool" / "bin" / "rcedit.exe"
    if not rcedit.exists():
        print("  ⚠ 找不到 tool/bin/rcedit.exe，exe 将没有图标")
        return

    ico = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    if not ico.exists():
        raise SystemExit(f"图标不存在：{ico}\n先跑 python tool/make_icon.py")

    parts = [p for p in version.split(".") if p]
    while len(parts) < 4:
        parts.append("0")
    v4 = ".".join(parts[:4])

    subprocess.run(
        [
            str(rcedit), str(exe),
            "--set-icon", str(ico),
            "--set-file-version", v4,
            "--set-product-version", v4,
            "--set-version-string", "ProductName", "端口助手",
            "--set-version-string", "FileDescription", "端口助手 - 端口占用查询",
            "--set-version-string", "OriginalFilename", "端口助手.exe",
            "--set-version-string", "InternalName", APP,
            "--set-version-string", "LegalCopyright", "",
        ],
        check=True,
        stdout=subprocess.DEVNULL,
    )


def list_resource_types(exe: Path) -> list[int]:
    """解析 PE 资源目录，返回顶层资源类型 ID（3=图标, 14=图标组, 16=版本信息）。"""
    data = exe.read_bytes()
    e_lfanew = struct.unpack_from("<I", data, 0x3C)[0]
    n_sections = struct.unpack_from("<H", data, e_lfanew + 6)[0]
    opt_size = struct.unpack_from("<H", data, e_lfanew + 20)[0]
    opt = e_lfanew + 24
    magic = struct.unpack_from("<H", data, opt)[0]
    # DataDirectory 起点：PE32 在 +96，PE32+ 在 +112
    dd = opt + (112 if magic == 0x20B else 96)
    res_rva = struct.unpack_from("<I", data, dd + 16)[0]  # index 2 = Resource
    if res_rva == 0:
        return []

    sections = []
    sec_off = opt + opt_size
    for i in range(n_sections):
        off = sec_off + i * 40
        vsize, vaddr, rawsize, rawptr = struct.unpack_from("<IIII", data, off + 8)
        sections.append((vaddr, vsize, rawptr, rawsize))

    def rva_to_off(rva: int) -> int | None:
        for vaddr, vsize, rawptr, rawsize in sections:
            if vaddr <= rva < vaddr + max(vsize, rawsize):
                return rawptr + (rva - vaddr)
        return None

    res_off = rva_to_off(res_rva)
    if res_off is None:
        return []

    n_named, n_id = struct.unpack_from("<HH", data, res_off + 12)
    types = []
    for i in range(n_named + n_id):
        name_id = struct.unpack_from("<I", data, res_off + 16 + i * 8)[0]
        if name_id & 0x80000000 == 0:
            types.append(name_id & 0xFFFF)
    return sorted(types)


def verify(exe: Path) -> bool:
    types = list_resource_types(exe)
    labels = {3: "RT_ICON", 14: "RT_GROUP_ICON", 16: "RT_VERSION"}
    if not types:
        print("  ⚠ 资源段为空，exe 不会有图标")
        return False
    found = [labels.get(t, str(t)) for t in types]
    print(f"  资源类型: {', '.join(found)}")
    ok = 3 in types and 14 in types
    if not ok:
        print("  ⚠ 缺少图标资源")
    return ok


def find_dart() -> str:
    """找到真正的 dart.exe。

    Windows 上 flutter/bin/dart 是 .bat，subprocess 直接调会找不到；
    真正的可执行文件在 flutter/bin/cache/dart-sdk/bin/dart.exe。
    """
    exe = "dart.exe" if os.name == "nt" else "dart"

    sdk = os.environ.get("DART_SDK")
    if sdk:
        candidate = Path(sdk) / "bin" / exe
        if candidate.exists():
            return str(candidate)

    found = shutil.which("dart")
    if found and not found.lower().endswith(".bat"):
        return found

    flutter = shutil.which("flutter")
    if flutter:
        candidate = Path(flutter).parent / "cache" / "dart-sdk" / "bin" / exe
        if candidate.exists():
            return str(candidate)

    raise SystemExit("找不到 dart 可执行文件，请确认 Flutter SDK 已加入 PATH")


def read_version() -> str:
    text = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    m = re.search(r"^version:\s*([0-9.]+)", text, re.MULTILINE)
    return m.group(1) if m else "0.0.0"


def set_gui_subsystem(exe: Path) -> None:
    """把控制台子系统改成 GUI，双击不再闪黑框。"""
    data = bytearray(exe.read_bytes())
    e_lfanew = struct.unpack_from("<I", data, 0x3C)[0]
    if data[e_lfanew : e_lfanew + 4] != b"PE\0\0":
        raise SystemExit("不是有效的 PE 文件")
    opt = e_lfanew + 24  # PE sig(4) + COFF header(20)
    magic = struct.unpack_from("<H", data, opt)[0]
    if magic not in (0x10B, 0x20B):
        raise SystemExit(f"未知的 OptionalHeader magic: {magic:#x}")
    # PE32 与 PE32+ 的 Subsystem 都在 OptionalHeader + 68
    struct.pack_into("<H", data, opt + 68, 2)  # IMAGE_SUBSYSTEM_WINDOWS_GUI
    exe.write_bytes(data)


def build_bootstrapper(version: str) -> Path:
    out_dir = ROOT / "build" / "sfx"
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / "bootstrapper.exe"
    print("编译启动器 …")
    subprocess.run(
        [find_dart(), "compile", "exe", "tool/bootstrapper.dart", "-o", str(out)],
        cwd=ROOT,
        check=True,
        stdout=subprocess.DEVNULL,
    )
    print("注入图标与版本信息 …")
    stamp_resources(out, version)
    set_gui_subsystem(out)
    return out


def pack_app_zip() -> bytes:
    files = sorted(p for p in RELEASE.rglob("*") if p.is_file())
    if not files:
        raise SystemExit(f"Release 目录为空：{RELEASE}\n先跑 flutter build windows --release")
    with tempfile.TemporaryFile() as tmp:
        with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
            for f in files:
                zf.write(f, (Path(APP) / f.relative_to(RELEASE)).as_posix())
        tmp.seek(0)
        return tmp.read()


def main() -> None:
    parser = argparse.ArgumentParser(description="把 Release 目录打成单文件 exe")
    parser.add_argument(
        "--also-ascii",
        action="store_true",
        help="额外输出一份英文名副本，供 CI 上传（避免 Release 附件链接出现百分号编码）",
    )
    args = parser.parse_args()

    version = read_version()
    bootstrapper = build_bootstrapper(version)
    payload = pack_app_zip()
    code = version_code(version)

    DIST.mkdir(exist_ok=True)
    target = DIST / f"端口助手-{version}.exe"
    with target.open("wb") as fp:
        fp.write(bootstrapper.read_bytes())
        fp.write(payload)
        fp.write(TAIL.pack(MAGIC, len(payload), code, 0))

    size_mb = target.stat().st_size / 1024 / 1024
    print(f"\n已生成 {target}")
    print(f"体积 {size_mb:.1f} MB（启动器 {bootstrapper.stat().st_size/1024/1024:.1f} MB + 应用 {len(payload)/1024/1024:.1f} MB）")
    print(f"内置版本码 {code}")
    print("校验最终 exe 的资源:")
    ok = verify(target)

    # payload 本身就是 zip，直接落盘当作更新包 —— 应用内更新下载它，比下 exe 省 6MB。
    zip_path = DIST / f"{APP}-{version}.zip"
    zip_path.write_bytes(payload)
    print(f"更新包 {zip_path}")

    if args.also_ascii:
        ascii_target = DIST / f"{APP}-{version}.exe"
        shutil.copyfile(target, ascii_target)
        print(f"英文名副本 {ascii_target}")

    print("双击即用，首次运行会解压到 %LOCALAPPDATA%\\PortHelper，之后秒开。")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
