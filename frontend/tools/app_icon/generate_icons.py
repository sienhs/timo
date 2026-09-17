"""앱 아이콘 생성 스크립트.

tools/app_icon/app_icon.png (1024x1024, 배경 포함 정방형) 하나로
Android(레거시 + 적응형)·iOS·웹 아이콘을 모두 만든다.

    cd frontend && python tools/app_icon/generate_icons.py

의존성: Pillow
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).with_name("app_icon.png")

# 적응형 아이콘은 108dp 캔버스 중 가운데 72dp만 보인다(원형 마스크 기준).
# 원본을 캔버스의 이 비율로 줄이고 남는 여백은 가장자리 색을 늘려 채운다.
ADAPTIVE_CONTENT_RATIO = 0.80

ANDROID_RES = ROOT / "android/app/src/main/res"
ANDROID_DENSITIES = {
    "mdpi": 1,
    "hdpi": 1.5,
    "xhdpi": 2,
    "xxhdpi": 3,
    "xxxhdpi": 4,
}
LEGACY_ICON_DP = 48
ADAPTIVE_ICON_DP = 108

IOS_ICONSET = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
IOS_ICONS = {
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

WEB = ROOT / "web"


def resized(image: Image.Image, size: int) -> Image.Image:
    return image.resize((size, size), Image.LANCZOS)


def padded_with_edge_color(image: Image.Image, size: int, content_ratio: float) -> Image.Image:
    """원본을 size 캔버스 안에 content_ratio 크기로 놓고, 여백은 원본 가장자리 색으로 채운다."""
    content_size = round(size * content_ratio)
    content = resized(image, content_size)
    offset = (size - content_size) // 2
    right = offset + content_size

    canvas = Image.new("RGB", (size, size))
    canvas.paste(content, (offset, offset))

    left_edge = content.crop((0, 0, 1, content_size)).resize((offset, content_size))
    right_edge = content.crop((content_size - 1, 0, content_size, content_size)).resize(
        (size - right, content_size)
    )
    canvas.paste(left_edge, (0, offset))
    canvas.paste(right_edge, (right, offset))

    top_edge = canvas.crop((0, offset, size, offset + 1)).resize((size, offset))
    bottom_edge = canvas.crop((0, right - 1, size, right)).resize((size, size - right))
    canvas.paste(top_edge, (0, 0))
    canvas.paste(bottom_edge, (0, right))
    return canvas


def write_android(image: Image.Image) -> None:
    for density, scale in ANDROID_DENSITIES.items():
        folder = ANDROID_RES / f"mipmap-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        resized(image, round(LEGACY_ICON_DP * scale)).save(folder / "ic_launcher.png", optimize=True)
        padded_with_edge_color(
            image, round(ADAPTIVE_ICON_DP * scale), ADAPTIVE_CONTENT_RATIO
        ).save(folder / "ic_launcher_foreground.png", optimize=True)


def write_ios(image: Image.Image) -> None:
    for filename, size in IOS_ICONS.items():
        resized(image, size).save(IOS_ICONSET / filename, optimize=True)


def write_web(image: Image.Image) -> None:
    icons = WEB / "icons"
    for size in (192, 512):
        resized(image, size).save(icons / f"Icon-{size}.png", optimize=True)
        padded_with_edge_color(image, size, ADAPTIVE_CONTENT_RATIO).save(
            icons / f"Icon-maskable-{size}.png", optimize=True
        )
    resized(image, 64).save(WEB / "favicon.png", optimize=True)


def main() -> None:
    image = Image.open(SOURCE).convert("RGB")
    write_android(image)
    write_ios(image)
    write_web(image)
    print("done")


if __name__ == "__main__":
    main()
