"""把 Flutter 渲染出来的图标母版转成 Windows 多尺寸 .ico。

母版由 test/icon_test.dart 生成（1024×1024，透明圆角）。
用法：python tool/make_icon.py
"""
import sys
from pathlib import Path

from PIL import Image

# Windows CI / 精简终端的 stdout 可能是 cp1252，打印中文会抛 UnicodeEncodeError。
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "test" / "icons" / "app_icon_1024.png"
DST = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"

# Windows 实际会用到的尺寸。256 是资源管理器大图标，16/24 是任务栏和标题栏。
SIZES = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256]


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"母版不存在：{SRC}\n先跑 flutter test test/icon_test.dart --update-goldens")

    master = Image.open(SRC).convert("RGBA")
    if master.size != (1024, 1024):
        raise SystemExit(f"母版尺寸不对：{master.size}，应为 1024×1024")

    # 每个尺寸单独高质量缩放，再交给 PIL 打包成 ico。
    frames = {
        s: master.resize((s, s), Image.LANCZOS)
        for s in SIZES
    }

    frames[256].save(
        DST,
        format="ICO",
        sizes=[(s, s) for s in SIZES],
        append_images=[frames[s] for s in SIZES if s != 256],
    )
    print(f"已写入 {DST}  ({DST.stat().st_size / 1024:.1f} KB)")

    # 顺手拼一张预览图，方便肉眼检查小尺寸有没有糊。
    preview_dir = ROOT.parent / ".codex-tmp" / "figma"
    preview_dir.mkdir(parents=True, exist_ok=True)
    pad = 16
    show = [16, 24, 32, 48, 64, 96, 128, 256]
    width = sum(show) + pad * (len(show) + 1)
    height = max(show) + pad * 2
    sheet = Image.new("RGBA", (width, height), (245, 242, 250, 255))
    x = pad
    for s in show:
        sheet.paste(frames[s], (x, pad), frames[s])
        x += s + pad
    out = preview_dir / "icon_preview.png"
    sheet.save(out)
    print(f"预览图 {out}")


if __name__ == "__main__":
    main()
