from __future__ import annotations

import argparse
import hashlib
import io
import os
from datetime import date
from pathlib import Path
from typing import Sequence

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas


# Environment-configurable certificate defaults.
CYAN = os.getenv("CERT_CYAN", "#00e5ff")
DARK = os.getenv("CERT_DARK", "#0b0c0e")
BACKGROUND = os.getenv("CERT_BACKGROUND", "#050607")
GRID_COLOR = os.getenv("CERT_GRID_COLOR", "#002f35")
LOGO_PATH = os.getenv("CERT_LOGO_PATH", "assets/icon2.jpg")
OUTPUT_PATH = os.getenv("CERT_OUTPUT_PATH", "nereus_certificate.pdf")
ORBITRON_PATH = os.getenv("CERT_ORBITRON_PATH", "assets/fonts/Orbitron.ttf")
SHARE_TECH_MONO_PATH = os.getenv("CERT_SHARE_TECH_MONO_PATH", "assets/fonts/ShareTechMono-Regular.ttf")
ORBITRON_WEIGHT = int(os.getenv("CERT_ORBITRON_WEIGHT", "900"))
MONO_STROKE_WIDTH = int(os.getenv("CERT_MONO_STROKE_WIDTH", "0"))

EXERCISE_1_LABEL = os.getenv("CERT_EXERCISE_1_LABEL", "PLANK HOLD")
EXERCISE_1_UNIT = os.getenv("CERT_EXERCISE_1_UNIT", "MIN : SEC")
EXERCISE_2_LABEL = os.getenv("CERT_EXERCISE_2_LABEL", "SQUATS")
EXERCISE_2_UNIT = os.getenv("CERT_EXERCISE_2_UNIT", "REPS")
EXERCISE_3_LABEL = os.getenv("CERT_EXERCISE_3_LABEL", "PUSH-UPS")
EXERCISE_3_UNIT = os.getenv("CERT_EXERCISE_3_UNIT", "REPS")

BRAND_NAME = os.getenv("CERT_BRAND_NAME", "NEREUS TECHNOLOGIES.")
BRAND_SUBTITLE = os.getenv("CERT_BRAND_SUBTITLE", "The biology of potential")
CHALLENGE_NAME = os.getenv("CERT_CHALLENGE_NAME", "THE NEREUS CHALLENGE")
WEBSITE = os.getenv("CERT_WEBSITE", "nereustechnologies.com")
WAITLIST_URL = os.getenv("CERT_WAITLIST_URL", "https://waitlist.nereustechnologies.com/")

WIDTH = int(os.getenv("CERT_WIDTH", "690"))
HEIGHT = int(os.getenv("CERT_HEIGHT", "1330"))


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.strip().lstrip("#")
    if len(value) != 6:
        raise ValueError(f"Expected a 6-digit hex color, got {value!r}")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


CYAN_RGB = hex_to_rgb(CYAN)
DARK_RGB = hex_to_rgb(DARK)
BACKGROUND_RGB = hex_to_rgb(BACKGROUND)
GRID_RGB = hex_to_rgb(GRID_COLOR)
WHITE = (255, 255, 255)


def blend(color: tuple[int, int, int], alpha: float, base: tuple[int, int, int] = DARK_RGB) -> tuple[int, int, int]:
    return tuple(int(base[i] * (1 - alpha) + color[i] * alpha) for i in range(3))


def local_path(path: str) -> Path:
    value = Path(path)
    if value.is_absolute():
        return value
    return Path(__file__).resolve().parent / value


def font(size: int, bold: bool = False, mono: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [local_path(SHARE_TECH_MONO_PATH) if mono else local_path(ORBITRON_PATH)]
    windir = Path(os.environ.get("WINDIR", "C:/Windows"))
    if mono:
        candidates += [
            windir / "Fonts" / "consolab.ttf",
            windir / "Fonts" / "consola.ttf",
        ]
    elif bold:
        candidates += [
            windir / "Fonts" / "bahnschrift.ttf",
            windir / "Fonts" / "arialbd.ttf",
            windir / "Fonts" / "segoeuib.ttf",
        ]
    else:
        candidates += [
            windir / "Fonts" / "bahnschrift.ttf",
            windir / "Fonts" / "arial.ttf",
            windir / "Fonts" / "segoeui.ttf",
        ]

    for path in candidates:
        if path.exists():
            loaded = ImageFont.truetype(str(path), size=size)
            if not mono and hasattr(loaded, "set_variation_by_axes"):
                loaded.set_variation_by_axes([ORBITRON_WEIGHT if bold else 700])
            return loaded
    return ImageFont.load_default()


FONTS = {
    "micro": font(10, mono=True),
    "tiny": font(13, mono=True),
    "small": font(15, mono=True),
    "body": font(16, mono=True),
    "label": font(15, mono=True),
    "brand": font(15, bold=True),
    "metric": font(40, bold=True),
    "date": font(15, mono=True),
    "name": font(23, bold=True),
    "title": font(55, bold=True),
    "question": font(104, bold=True),
}
MONO_FONT_IDS = {id(FONTS[key]) for key in ("micro", "tiny", "small", "body", "label")}


def draw_letterspaced(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    text: str,
    fill: tuple[int, int, int],
    font_obj: ImageFont.ImageFont,
    spacing: int = 4,
    stroke: bool = True,
) -> None:
    x, y = xy
    for char in text:
        draw.text(
            (x, y),
            char,
            fill=fill,
            font=font_obj,
            stroke_width=MONO_STROKE_WIDTH if stroke and id(font_obj) in MONO_FONT_IDS else 0,
            stroke_fill=fill,
        )
        bbox = draw.textbbox((x, y), char, font=font_obj)
        x += bbox[2] - bbox[0] + spacing


def draw_dashed_rectangle(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    fill: tuple[int, int, int],
    dash: int = 16,
    gap: int = 10,
    width: int = 2,
) -> None:
    x0, y0, x1, y1 = box
    for x in range(x0, x1, dash + gap):
        draw.line((x, y0, min(x + dash, x1), y0), fill=fill, width=width)
        draw.line((x, y1, min(x + dash, x1), y1), fill=fill, width=width)
    for y in range(y0, y1, dash + gap):
        draw.line((x0, y, x0, min(y + dash, y1)), fill=fill, width=width)
        draw.line((x1, y, x1, min(y + dash, y1)), fill=fill, width=width)


def clipped_box(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], fill, outline, cut: int = 20, width: int = 2) -> None:
    x0, y0, x1, y1 = box
    points = [
        (x0, y0),
        (x1 - cut, y0),
        (x1, y0 + cut),
        (x1, y1),
        (x0 + cut, y1),
        (x0, y1 - cut),
    ]
    draw.polygon(points, fill=fill)
    draw.line(points + [points[0]], fill=outline, width=width)


def gradient_line(draw: ImageDraw.ImageDraw, x0: int, y: int, x1: int, color: tuple[int, int, int], max_alpha: float = 0.75) -> None:
    mid = (x0 + x1) / 2
    for x in range(x0, x1):
        dist = abs(x - mid) / max(1, (x1 - x0) / 2)
        alpha = max(0.0, (1 - dist) * max_alpha)
        draw.point((x, y), fill=blend(color, alpha))
        draw.point((x, y + 1), fill=blend(color, alpha * 0.7))


def draw_grid(base: Image.Image) -> None:
    draw = ImageDraw.Draw(base)
    for x in range(0, WIDTH, 34):
        draw.line((x, 0, x, HEIGHT), fill=GRID_RGB, width=1)
    for y in range(0, HEIGHT, 34):
        draw.line((0, y, WIDTH, y), fill=GRID_RGB, width=1)

    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    g.ellipse((-120, -250, WIDTH + 120, 420), fill=(*CYAN_RGB, 18))
    g.ellipse((-100, HEIGHT - 380, WIDTH + 100, HEIGHT + 220), fill=(*CYAN_RGB, 12))
    glow = glow.filter(ImageFilter.GaussianBlur(52))
    base.alpha_composite(glow)


def load_logo(path: str, size: int = 84) -> Image.Image | None:
    logo_path = local_path(path)
    if not logo_path.exists():
        return None

    logo = Image.open(logo_path).convert("RGB")
    logo = ImageOps.fit(logo, (size, size), method=Image.Resampling.LANCZOS, centering=(0.5, 0.5)).convert("RGBA")
    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.regular_polygon((size // 2, size // 2, size // 2 - 1), n_sides=6, rotation=30, fill=255)
    logo.putalpha(mask)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(logo, (0, 0))
    return canvas


def draw_logo(draw: ImageDraw.ImageDraw, image: Image.Image, x: int, y: int) -> None:
    logo_size = 112
    draw.regular_polygon((x + logo_size // 2, y + logo_size // 2, logo_size // 2), n_sides=6, rotation=30, outline=CYAN_RGB, width=3)
    draw.regular_polygon((x + logo_size // 2, y + logo_size // 2, 40), n_sides=6, rotation=30, outline=blend(CYAN_RGB, 0.55), width=2)
    logo = load_logo(LOGO_PATH, 86)
    if logo:
        image.alpha_composite(logo, (x + 13, y + 13))
    else:
        draw.text((x + 20, y + 17), "N", fill=CYAN_RGB, font=font(28, bold=True))


def make_qr_pattern(data: str, cells: int = 19) -> list[list[int]]:
    bits = hashlib.sha256(data.encode("utf-8")).digest()
    pattern = [[0 for _ in range(cells)] for _ in range(cells)]

    def finder(top: int, left: int) -> None:
        for r in range(7):
            for c in range(7):
                edge = r in (0, 6) or c in (0, 6)
                center = 2 <= r <= 4 and 2 <= c <= 4
                pattern[top + r][left + c] = 1 if edge or center else 0

    finder(0, 0)
    finder(0, cells - 7)
    finder(cells - 7, 0)

    bit_index = 0
    for r in range(cells):
        for c in range(cells):
            in_finder = (r < 7 and c < 7) or (r < 7 and c >= cells - 7) or (r >= cells - 7 and c < 7)
            if in_finder:
                continue
            byte = bits[(bit_index // 8) % len(bits)]
            bit = (byte >> (bit_index % 8)) & 1
            pattern[r][c] = bit ^ ((r * c + r + c) % 3 == 0)
            bit_index += 1
    return pattern


def draw_qr(draw: ImageDraw.ImageDraw, x: int, y: int, size: int, data: str) -> None:
    cells = 19
    pad = 10
    cell = (size - pad * 2) // cells
    draw.rectangle((x, y, x + size, y + size), fill=(3, 8, 9), outline=blend(CYAN_RGB, 0.45), width=2)
    pattern = make_qr_pattern(data, cells)
    for r, row in enumerate(pattern):
        for c, value in enumerate(row):
            if value:
                x0 = x + pad + c * cell
                y0 = y + pad + r * cell
                draw.rectangle((x0, y0, x0 + cell - 1, y0 + cell - 1), fill=CYAN_RGB)


def draw_metric_card(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    label: str,
    value: str,
    unit: str,
) -> None:
    x0, y0, x1, y1 = box
    clipped_box(draw, box, fill=blend(CYAN_RGB, 0.035), outline=blend(CYAN_RGB, 0.27), cut=13, width=1)
    draw_letterspaced(draw, (x0 + 17, y0 + 23), label.upper(), blend(CYAN_RGB, 0.7), FONTS["micro"], spacing=3)
    draw.text((x0 + 17, y0 + 63), value, fill=WHITE, font=FONTS["metric"])
    draw_letterspaced(draw, (x0 + 17, y1 - 38), unit.upper(), CYAN_RGB, FONTS["micro"], spacing=3)
    gradient_line(draw, x0 + 2, y1 - 3, x1 - 2, CYAN_RGB, max_alpha=0.55)


def draw_corner_marks(draw: ImageDraw.ImageDraw, margin: int = 24, length: int = 34) -> None:
    color = blend(CYAN_RGB, 0.75)
    x0, y0 = margin, margin
    x1, y1 = WIDTH - margin, HEIGHT - margin
    draw.line((x0, y0 + length, x0, y0, x0 + length, y0), fill=color, width=4)
    draw.line((x1 - length, y0, x1, y0, x1, y0 + length), fill=color, width=4)
    draw.line((x0, y1 - length, x0, y1, x0 + length, y1), fill=color, width=4)
    draw.line((x1 - length, y1, x1, y1, x1, y1 - length), fill=color, width=4)


def draw_certificate(args: argparse.Namespace) -> Image.Image:
    image = Image.new("RGBA", (WIDTH, HEIGHT), BACKGROUND_RGB + (255,))
    draw_grid(image)
    panel = Image.new("RGBA", (WIDTH - 34, HEIGHT - 34), DARK_RGB + (248,))
    image.alpha_composite(panel, (17, 17))
    draw = ImageDraw.Draw(image)

    draw_dashed_rectangle(draw, (24, 24, WIDTH - 24, HEIGHT - 24), blend(CYAN_RGB, 0.28), dash=10, gap=8, width=1)
    draw_corner_marks(draw, margin=8, length=34)

    left, right = 58, WIDTH - 58
    y = 54

    draw_logo(draw, image, left, y)
    draw_letterspaced(draw, (left + 136, y + 26), BRAND_NAME, CYAN_RGB, FONTS["brand"], spacing=5)
    draw_letterspaced(draw, (left + 136, y + 55), BRAND_SUBTITLE, blend(WHITE, 0.58), FONTS["micro"], spacing=3, stroke=False)

    draw.text((right - 104, y + 26), "EVENT ID", fill=blend(CYAN_RGB, 0.65), font=FONTS["micro"])
    draw.text((right - 104, y + 49), args.certificate_id, fill=blend(WHITE, 0.68), font=FONTS["tiny"])

    gradient_line(draw, left, 188, right, CYAN_RGB, max_alpha=0.6)

    draw_letterspaced(draw, (left, 216), "> PROOF OF PERFORMANCE", CYAN_RGB, FONTS["label"], spacing=5)
    title_layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    title_draw = ImageDraw.Draw(title_layer)
    title_draw.multiline_text((left, 252), "YOU\nSHOWED\nUP.", fill=WHITE + (255,), font=FONTS["title"], spacing=-4)
    soft_glow = title_layer.filter(ImageFilter.GaussianBlur(8))
    hard_glow = title_layer.filter(ImageFilter.GaussianBlur(3))
    image.alpha_composite(soft_glow)
    image.alpha_composite(hard_glow)
    image.alpha_composite(title_layer)
    draw = ImageDraw.Draw(image)
    draw.multiline_text(
        (left, 464),
        "YOUR BODY DIDN'T JUST MOVE.\nIT SPOKE. HERE'S WHAT IT SAID.",
        fill=blend(WHITE, 0.48),
        font=FONTS["body"],
        spacing=5,
    )

    y = 548
    draw.rectangle((left, y, right, y + 82), fill=blend(CYAN_RGB, 0.06), outline=blend(CYAN_RGB, 0.26), width=1)
    draw.text((left + 24, y + 17), "ATHLETE", fill=blend(CYAN_RGB, 0.55), font=FONTS["micro"])
    draw.text((left + 24, y + 44), args.name.upper(), fill=WHITE, font=FONTS["name"])
    draw.text((right - 74, y + 17), "DATE", fill=blend(CYAN_RGB, 0.55), font=FONTS["micro"])
    date_w = draw.textbbox((0, 0), args.date, font=FONTS["date"])[2]
    draw.text((right - 24 - date_w, y + 45), args.date, fill=blend(WHITE, 0.72), font=FONTS["date"])

    y = 675
    draw_letterspaced(draw, (left, y), f"-- {CHALLENGE_NAME} ----------------", blend(CYAN_RGB, 0.7), FONTS["micro"], spacing=4)

    metric_y = 720
    gap = 16
    card_w = (right - left - gap * 2) // 3
    metrics = [
        (EXERCISE_1_LABEL, args.plank, EXERCISE_1_UNIT),
        (EXERCISE_2_LABEL, args.squats, EXERCISE_2_UNIT),
        (EXERCISE_3_LABEL, args.pushups, EXERCISE_3_UNIT),
    ]
    for i, (label, value, unit) in enumerate(metrics):
        x0 = left + i * (card_w + gap)
        draw_metric_card(draw, (x0, metric_y, x0 + card_w, metric_y + 154), label, value, unit)

    gradient_line(draw, left, 930, right, CYAN_RGB, max_alpha=0.38)

    identity_box = (left, 968, right, 1248)
    clipped_box(draw, identity_box, fill=blend(CYAN_RGB, 0.025), outline=blend(CYAN_RGB, 0.3), cut=18, width=1)
    ix0, iy0, ix1, iy1 = identity_box
    draw_letterspaced(draw, (ix0 + 28, iy0 + 28), "YOUR MOVEMENT IDENTITY", CYAN_RGB, FONTS["micro"], spacing=4)
    draw.text((ix0 + 35, iy0 + 46), "?", fill=blend(CYAN_RGB, 0.48), font=FONTS["question"])
    draw.multiline_text(
        (ix0 + 34, iy0 + 172),
        "YOUR DATA HAS A STORY.\nYOU JUST HAVEN'T UNLOCKED IT\nYET.",
        fill=blend(WHITE, 0.66),
        font=FONTS["small"],
        spacing=6,
    )
    draw.multiline_text(
        (ix0 + 34, iy0 + 230),
        "SCAN TO FIND OUT WHAT\nYOUR BODY IS REALLY BUILT FOR ->",
        fill=blend(WHITE, 0.4),
        font=FONTS["micro"],
        spacing=4,
    )
    draw.text((ix0 + 34, iy0 + 256), WEBSITE, fill=blend(CYAN_RGB, 0.72), font=FONTS["micro"])
    qr_size = 138
    qr_x = ix1 - 34 - qr_size
    qr_y = iy0 + 52
    draw_qr(draw, qr_x, qr_y, qr_size, args.qr_data)
    draw.multiline_text((qr_x + 41, qr_y + qr_size + 17), "JOIN THE\nWAITLIST", fill=blend(CYAN_RGB, 0.65), font=FONTS["micro"], spacing=2, align="center")

    return image.convert("RGB")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Generate a Nereus performance certificate.")
    parser.add_argument("--name", required=True, help="Participant name shown on the certificate.")
    parser.add_argument("--plank", required=True, help="Plank metric, for example 01:47.")
    parser.add_argument("--squats", required=True, help="Squat reps, for example 34.")
    parser.add_argument("--pushups", required=True, help="Push-up reps, for example 22.")
    parser.add_argument("--date", default=date.today().strftime("%m.%d.%Y"), help="Certificate date. Defaults to today.")
    parser.add_argument("--certificate-id", default="NR-ABP-0001", help="Certificate identifier.")
    parser.add_argument("--qr-data", default=WAITLIST_URL, help="Data used to render the QR-style block.")
    parser.add_argument("--output", default=OUTPUT_PATH, help="Output image path.")
    return parser


def website_link_box() -> tuple[int, int, int, int]:
    x = 58 + 34
    y = 968 + 256
    bbox = ImageDraw.Draw(Image.new("RGB", (1, 1))).textbbox((x, y), WEBSITE, font=FONTS["micro"])
    pad = 3
    return bbox[0] - pad, bbox[1] - pad, bbox[2] + pad, bbox[3] + pad


def save_pdf_with_link(certificate: Image.Image, output: Path) -> None:
    buffer = io.BytesIO()
    certificate.save(buffer, format="PNG")
    buffer.seek(0)

    pdf = canvas.Canvas(str(output), pagesize=(WIDTH, HEIGHT))
    pdf.drawImage(ImageReader(buffer), 0, 0, width=WIDTH, height=HEIGHT)

    x0, y0, x1, y1 = website_link_box()
    pdf.linkURL(
        f"https://{WEBSITE}",
        (x0, HEIGHT - y1, x1, HEIGHT - y0),
        relative=0,
        thickness=0,
    )
    pdf.showPage()
    pdf.save()


def main(argv: Sequence[str] | None = None) -> None:
    args = build_parser().parse_args(argv)
    output = Path(args.output)
    if output.parent != Path("."):
        output.parent.mkdir(parents=True, exist_ok=True)
    certificate = draw_certificate(args)
    if output.suffix.lower() == ".pdf":
        save_pdf_with_link(certificate, output)
    else:
        certificate.save(output, quality=95)
    print(f"Generated certificate: {output.resolve()}")


if __name__ == "__main__":
    main()
