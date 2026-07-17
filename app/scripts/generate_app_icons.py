"""Generate ThriftyChef launcher icons for all platforms from branding source."""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = Image.open(ROOT / "assets/branding/thriftychef_app_icon_1024.png").convert("RGBA")
BG = (245, 248, 250, 255)


def save_resized(path: Path, size: int, *, pad_ratio: float = 0.0) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if pad_ratio > 0:
        canvas = Image.new("RGBA", (size, size), BG)
        content = int(size * (1 - 2 * pad_ratio))
        icon = SRC.resize((content, content), Image.Resampling.LANCZOS)
        offset = (size - content) // 2
        canvas.paste(icon, (offset, offset), icon)
        out = canvas
    else:
        out = SRC.resize((size, size), Image.Resampling.LANCZOS)
    out.save(path, "PNG")
    print(f"wrote {path.relative_to(ROOT)} ({size}x{size})")


def main() -> None:
    android = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in android.items():
        save_resized(ROOT / f"android/app/src/main/res/{folder}/ic_launcher.png", size)

    ios_dir = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    ios_sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for name, size in ios_sizes.items():
        save_resized(ios_dir / name, size)

    mac_dir = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for size in (16, 32, 64, 128, 256, 512, 1024):
        save_resized(mac_dir / f"app_icon_{size}.png", size)

    web = ROOT / "web"
    save_resized(web / "favicon.png", 32)
    save_resized(web / "icons/Icon-192.png", 192)
    save_resized(web / "icons/Icon-512.png", 512)
    save_resized(web / "icons/Icon-maskable-192.png", 192, pad_ratio=0.1)
    save_resized(web / "icons/Icon-maskable-512.png", 512, pad_ratio=0.1)

    ico_sizes = [16, 32, 48, 64, 128, 256]
    ico_images = [SRC.resize((s, s), Image.Resampling.LANCZOS) for s in ico_sizes]
    ico_path = ROOT / "windows/runner/resources/app_icon.ico"
    ico_images[-1].save(
        ico_path,
        format="ICO",
        sizes=[(s, s) for s in ico_sizes],
        append_images=ico_images[:-1],
    )
    print(f"wrote {ico_path.relative_to(ROOT)}")
    print("done")


if __name__ == "__main__":
    main()
