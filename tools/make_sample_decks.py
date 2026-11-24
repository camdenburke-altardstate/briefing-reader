"""
Generates sample executive decks for testing Briefing Reader. Run on any PC:

    python tools/make_sample_decks.py                 # writes SampleDecks/
    python tools/make_sample_decks.py --stress 60     # also a heavy deck (60 pages of photo-like noise, ~80 MB)

Everything in these decks is made up. Every page says so, so nothing here can be mistaken for
real company data. Needs: pip install reportlab pillow
"""
import argparse
import io
import os
import random
from pathlib import Path

from reportlab.lib.colors import HexColor, white
from reportlab.pdfgen import canvas

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "SampleDecks"
LOGO = ROOT / "Brand" / "logo-charcoal.png"

INK = HexColor("#363636")
GRAY = HexColor("#6B6B6B")
HAIR = HexColor("#E3E1DE")
WELL = HexColor("#F7F6F4")
NOTE = "Sample content, not real data"

LETTER = (612, 792)
SLIDE = (960, 540)  # 16:9


def logo(c, x, y, width):
    if LOGO.exists():
        c.drawImage(str(LOGO), x, y, width=width, height=width * 68 / 640, mask="auto")


def footer(c, w, n, total, label):
    c.setStrokeColor(HAIR)
    c.setLineWidth(0.6)
    c.line(36, 40, w - 36, 40)
    c.setFillColor(GRAY)
    c.setFont("Helvetica", 8)
    c.drawString(36, 26, f"{label}   |   {NOTE}")
    c.drawRightString(w - 36, 26, f"{n} / {total}")


def bars(c, x, y, w, h, values, labels=None, seed=0):
    c.setFillColor(WELL)
    c.setStrokeColor(HAIR)
    c.rect(x, y, w, h, fill=1, stroke=1)
    gap = 10
    bw = (w - gap * (len(values) + 1)) / len(values)
    top = max(values)
    c.setFillColor(INK)
    for i, v in enumerate(values):
        bh = (h - 28) * v / top
        c.rect(x + gap + i * (bw + gap), y + 14, bw, bh, fill=1, stroke=0)
        if labels:
            c.setFillColor(GRAY)
            c.setFont("Helvetica", 7)
            c.drawCentredString(x + gap + i * (bw + gap) + bw / 2, y + 4, labels[i])
            c.setFillColor(INK)


def paragraph(c, x, y, lines, size=10, lead=15, color=INK):
    c.setFillColor(color)
    c.setFont("Helvetica", size)
    for i, line in enumerate(lines):
        c.drawString(x, y - i * lead, line)


LOREM = [
    "This paragraph is placeholder text used to fill the page so layout, zoom and",
    "page turning can be judged. It describes nothing real. Revenue, store counts,",
    "and percentages shown on these pages were generated at random for testing.",
    "Pinch to zoom, then swipe left or right to change page.",
]


# ---------------------------------------------------------------- Board book (portrait, bookmarks, links)
def board_book(path):
    c = canvas.Canvas(str(path), pagesize=LETTER, pageCompression=1)
    c.setTitle("Sample Q4 Board Book")
    w, h = LETTER
    sections = [
        ("Executive Summary", ["Highlights", "Risks and Watch Items"]),
        ("Financial Performance", ["Revenue", "Margin", "Cash and Inventory"]),
        ("Stores and Operations", ["Store Performance", "Supply Chain", "Technology"]),
        ("People", ["Headcount", "Hiring Plan"]),
        ("Outlook", ["Holiday", "Next Year"]),
    ]
    # Lay out pages first so the contents page can link to them.
    pages = [("cover", None, None)]
    pages.append(("contents", None, None))
    for si, (sec, subs) in enumerate(sections):
        pages.append(("divider", si, sec))
        for sub in subs:
            pages.append(("content", si, sub))
            pages.append(("content", si, sub + " (detail)"))
    total = len(pages)
    rng = random.Random(7)

    key_for = {}
    for idx, (kind, si, name) in enumerate(pages, start=1):
        if kind == "divider":
            key_for[("sec", si)] = f"sec{si}"
        if kind == "content" and not name.endswith("(detail)"):
            key_for[("sub", si, name)] = f"sub{si}_{name}"

    for n, (kind, si, name) in enumerate(pages, start=1):
        if kind == "cover":
            c.setFillColor(white)
            c.rect(0, 0, w, h, fill=1, stroke=0)
            logo(c, 72, h - 220, 300)
            c.setStrokeColor(HAIR)
            c.line(72, h - 245, w - 72, h - 245)
            c.setFillColor(INK)
            c.setFont("Helvetica-Light" if False else "Helvetica", 34)
            c.drawString(72, h - 310, "Q4 Board Book")
            c.setFillColor(GRAY)
            c.setFont("Helvetica", 13)
            c.drawString(72, h - 340, "Sample deck for testing Briefing Reader")
            c.drawString(72, 90, "CONFIDENTIAL   |   " + NOTE)
            c.bookmarkPage("cover")
            c.addOutlineEntry("Cover", "cover", 0)
        elif kind == "contents":
            c.bookmarkPage("contents")
            c.addOutlineEntry("Contents", "contents", 0)
            c.setFillColor(INK)
            c.setFont("Helvetica", 22)
            c.drawString(56, h - 80, "Contents")
            y = h - 130
            for sj, (sec, subs) in enumerate(sections):
                page_no = 1 + 1 + sum(1 + 2 * len(sections[k][1]) for k in range(sj)) + 1
                c.setFont("Helvetica-Bold", 12)
                c.setFillColor(INK)
                c.drawString(56, y, sec)
                c.drawRightString(w - 56, y, str(page_no))
                c.linkRect("", f"sec{sj}", (56, y - 4, w - 56, y + 12), relative=0, thickness=0)
                y -= 20
                offset = 1
                for sub in subs:
                    sub_no = page_no + offset
                    c.setFont("Helvetica", 11)
                    c.setFillColor(GRAY)
                    c.drawString(76, y, sub)
                    c.drawRightString(w - 56, y, str(sub_no))
                    c.linkRect("", f"sub{sj}_{sub}", (76, y - 4, w - 56, y + 11), relative=0, thickness=0)
                    y -= 17
                    offset += 2
                y -= 10
            c.setFillColor(GRAY)
            c.setFont("Helvetica-Oblique", 9)
            c.drawString(56, 70, "Tap a line above to jump to that section.")
        elif kind == "divider":
            c.bookmarkPage(f"sec{si}")
            c.addOutlineEntry(name, f"sec{si}", 0)
            c.setFillColor(WELL)
            c.rect(0, 0, w, h, fill=1, stroke=0)
            c.setFillColor(INK)
            c.setFont("Helvetica", 12)
            c.drawString(72, h / 2 + 40, f"SECTION {si + 1}")
            c.setFont("Helvetica", 34)
            c.drawString(72, h / 2, name)
        else:
            key = f"sub{si}_{name}"
            detail = name.endswith("(detail)")
            if not detail:
                c.bookmarkPage(key)
                c.addOutlineEntry(name, key, 1)
            c.setFillColor(INK)
            c.setFont("Helvetica", 22)
            c.drawString(56, h - 80, name)
            c.setStrokeColor(HAIR)
            c.line(56, h - 94, w - 56, h - 94)
            bars(c, 56, h - 340, w - 112, 220, [rng.randint(30, 100) for _ in range(12)],
                 ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"])
            paragraph(c, 56, h - 380, LOREM)
            paragraph(c, 56, h - 460, LOREM[::-1])
            c.setFont("Helvetica-Bold", 28)
            c.setFillColor(INK)
            c.drawString(56, 150, f"{rng.randint(100, 999) / 10:.1f}%")
            c.setFont("Helvetica", 9)
            c.setFillColor(GRAY)
            c.drawString(56, 135, "Sample metric")
        if kind not in ("cover",):
            footer(c, w, n, total, "Q4 Board Book")
        c.showPage()
    c.save()


# ---------------------------------------------------------------- Slide decks (landscape)
def slide_deck(path, title, slide_titles, bookmarks=True, seed=1):
    c = canvas.Canvas(str(path), pagesize=SLIDE, pageCompression=1)
    c.setTitle("Sample " + title)
    w, h = SLIDE
    rng = random.Random(seed)
    total = len(slide_titles) + 1
    # cover
    c.setFillColor(INK)
    c.rect(0, 0, w, h, fill=1, stroke=0)
    c.setFillColor(white)
    c.setFont("Helvetica", 44)
    c.drawString(72, h / 2 + 10, title)
    c.setFont("Helvetica", 14)
    c.setFillColor(HexColor("#C9C9C8"))
    c.drawString(72, h / 2 - 24, "Sample deck for testing Briefing Reader   |   " + NOTE)
    if bookmarks:
        c.bookmarkPage("s0")
        c.addOutlineEntry("Title", "s0", 0)
    c.showPage()
    for i, name in enumerate(slide_titles, start=1):
        if bookmarks:
            c.bookmarkPage(f"s{i}")
            c.addOutlineEntry(name, f"s{i}", 0)
        c.setFillColor(white)
        c.rect(0, 0, w, h, fill=1, stroke=0)
        c.setFillColor(INK)
        c.setFont("Helvetica", 30)
        c.drawString(56, h - 72, name)
        c.setStrokeColor(HAIR)
        c.line(56, h - 90, w - 56, h - 90)
        style = i % 3
        if style == 0:
            bars(c, 56, 90, 520, 330, [rng.randint(30, 100) for _ in range(8)],
                 ["W1", "W2", "W3", "W4", "W5", "W6", "W7", "W8"])
            c.setFont("Helvetica-Bold", 64)
            c.setFillColor(INK)
            c.drawString(620, 300, f"{rng.randint(100, 990) / 10:.1f}%")
            c.setFont("Helvetica", 14)
            c.setFillColor(GRAY)
            c.drawString(620, 270, "Sample headline metric")
        elif style == 1:
            for k in range(3):
                x = 56 + k * 300
                c.setFillColor(WELL)
                c.setStrokeColor(HAIR)
                c.rect(x, 140, 270, 260, fill=1, stroke=1)
                c.setFillColor(INK)
                c.setFont("Helvetica-Bold", 44)
                c.drawString(x + 20, 320, f"{rng.randint(10, 99)}")
                c.setFont("Helvetica", 13)
                c.setFillColor(GRAY)
                c.drawString(x + 20, 290, ["Stores", "Regions", "Initiatives"][k] + " (sample)")
                paragraph(c, x + 20, 250, ["Placeholder detail text", "for layout testing only."], size=11)
        else:
            paragraph(c, 56, h - 140, ["Key points (sample)"] + [f"{j}.  Placeholder statement number {j}" for j in range(1, 6)],
                      size=18, lead=34)
        footer(c, w, i + 1, total, title)
        c.showPage()
    c.save()


# ---------------------------------------------------------------- One page
def one_pager(path):
    c = canvas.Canvas(str(path), pagesize=LETTER, pageCompression=1)
    c.setTitle("Sample One Page Brief")
    w, h = LETTER
    logo(c, 56, h - 90, 240)
    c.setStrokeColor(HAIR)
    c.line(56, h - 110, w - 56, h - 110)
    c.setFillColor(INK)
    c.setFont("Helvetica", 26)
    c.drawString(56, h - 160, "One Page Brief")
    paragraph(c, 56, h - 200, LOREM, size=11, lead=17)
    bars(c, 56, 300, w - 112, 200, [40, 62, 55, 80, 73, 90], ["A", "B", "C", "D", "E", "F"])
    footer(c, w, 1, 1, "One Page Brief")
    c.showPage()
    c.save()


# ---------------------------------------------------------------- Long report (hundreds of pages)
BODY = [
    "Placeholder paragraph text for layout testing. None of these sentences describe anything real,",
    "and every figure on these pages was produced by a random number generator.",
    "The purpose of this page is to be long enough to look like a dense report page, so that",
    "reading position, page turning speed and the contents list can be judged on a deck",
    "that runs to hundreds of pages. Pinch to zoom in, and swipe to move between pages.",
    "A second paragraph begins here and continues for a few more lines of filler text so the",
    "page is not mostly empty. Section and chapter names appear in the running header above,",
    "and the page number appears at the foot of every page for easy reference when scrubbing.",
]


def long_report(path, parts=8, chapters=6, sections=3, pages_per_section=2, appendix=22):
    c = canvas.Canvas(str(path), pagesize=LETTER, pageCompression=1)
    c.setTitle("Sample Annual Report")
    w, h = LETTER
    rng = random.Random(11)

    specs = [("cover", None), ("contents", None)]
    for p in range(parts):
        specs.append(("part", (p,)))
        for ch in range(chapters):
            for s in range(sections):
                for k in range(pages_per_section):
                    specs.append(("body", (p, ch, s, k)))
    for a in range(appendix):
        specs.append(("appendix", (a,)))
    total = len(specs)

    def first_page_of(kind, key):
        for i, (k, kk) in enumerate(specs, start=1):
            if k == kind and kk[: len(key)] == key:
                return i
        return 1

    for n, (kind, key) in enumerate(specs, start=1):
        if kind == "cover":
            c.setFillColor(INK)
            c.rect(0, 0, w, h, fill=1, stroke=0)
            c.setFillColor(white)
            c.setFont("Helvetica", 40)
            c.drawString(72, h / 2 + 20, "Annual Report")
            c.setFont("Helvetica", 14)
            c.setFillColor(HexColor("#C9C9C8"))
            c.drawString(72, h / 2 - 14, f"Sample long document, {total} pages   |   {NOTE}")
            c.bookmarkPage("cover")
            c.addOutlineEntry("Cover", "cover", 0)
        elif kind == "contents":
            c.bookmarkPage("contents")
            c.addOutlineEntry("Contents", "contents", 0)
            c.setFillColor(INK)
            c.setFont("Helvetica", 22)
            c.drawString(56, h - 80, "Contents")
            y = h - 130
            for p in range(parts):
                pg = first_page_of("part", (p,))
                c.setFont("Helvetica-Bold", 13)
                c.setFillColor(INK)
                c.drawString(56, y, f"Part {p + 1}")
                c.drawRightString(w - 56, y, str(pg))
                c.linkRect("", f"part{p}", (56, y - 4, w - 56, y + 13), relative=0, thickness=0)
                y -= 24
            pg = first_page_of("appendix", (0,))
            c.setFont("Helvetica-Bold", 13)
            c.drawString(56, y, "Appendix")
            c.drawRightString(w - 56, y, str(pg))
            c.linkRect("", "appendix0", (56, y - 4, w - 56, y + 13), relative=0, thickness=0)
        elif kind == "part":
            (p,) = key
            c.bookmarkPage(f"part{p}")
            c.addOutlineEntry(f"Part {p + 1}", f"part{p}", 0)
            c.setFillColor(WELL)
            c.rect(0, 0, w, h, fill=1, stroke=0)
            c.setFillColor(INK)
            c.setFont("Helvetica", 12)
            c.drawString(72, h / 2 + 40, "PART")
            c.setFont("Helvetica", 44)
            c.drawString(72, h / 2 - 5, f"Part {p + 1}")
        elif kind == "body":
            p, ch, s, k = key
            if k == 0:
                bm = f"p{p}c{ch}s{s}"
                c.bookmarkPage(bm)
                if s == 0:
                    c.addOutlineEntry(f"Chapter {p * chapters + ch + 1}", bm, 1)
                else:
                    c.addOutlineEntry(f"Section {p + 1}.{ch + 1}.{s + 1}", bm, 2)
            c.setFillColor(GRAY)
            c.setFont("Helvetica", 8)
            c.drawString(56, h - 40, f"Part {p + 1}  /  Chapter {p * chapters + ch + 1}  /  Section {p + 1}.{ch + 1}.{s + 1}")
            c.setFillColor(INK)
            c.setFont("Helvetica", 18)
            c.drawString(56, h - 80, f"Section {p + 1}.{ch + 1}.{s + 1}" + ("" if k == 0 else " (continued)"))
            c.setStrokeColor(HAIR)
            c.line(56, h - 92, w - 56, h - 92)
            yy = h - 120
            for _ in range(3):
                paragraph(c, 56, yy, BODY, size=10, lead=14)
                yy -= 8 * 14 + 14
            if k == 0:
                bars(c, 56, 90, w - 112, 130, [rng.randint(30, 100) for _ in range(10)])
        else:
            (a,) = key
            if a == 0:
                c.bookmarkPage("appendix0")
                c.addOutlineEntry("Appendix", "appendix0", 0)
            c.setFillColor(INK)
            c.setFont("Helvetica", 18)
            c.drawString(56, h - 80, f"Appendix table A-{a + 1}")
            c.setStrokeColor(HAIR)
            c.line(56, h - 92, w - 56, h - 92)
            c.setFont("Helvetica", 9)
            for r in range(46):
                yy = h - 120 - r * 14
                c.setFillColor(WELL if r % 2 == 0 else white)
                c.rect(56, yy - 3, w - 112, 14, fill=1, stroke=0)
                c.setFillColor(INK)
                c.drawString(62, yy, f"Row {r + 1}")
                for col in range(4):
                    c.drawRightString(230 + col * 95, yy, f"{rng.randint(1000, 99999):,}")
        if kind != "cover":
            footer(c, w, n, total, "Annual Report")
        c.showPage()
    c.save()


# ---------------------------------------------------------------- Stress deck
def stress(path, pages):
    from PIL import Image  # noqa: WPS433

    c = canvas.Canvas(str(path), pagesize=SLIDE, pageCompression=0)
    c.setTitle("Sample Stress Test")
    w, h = SLIDE
    for n in range(1, pages + 1):
        img = Image.frombytes("RGB", (1600, 900), os.urandom(1600 * 900 * 3))
        buf = io.BytesIO()
        img.save(buf, "JPEG", quality=85)
        buf.seek(0)
        from reportlab.lib.utils import ImageReader

        c.drawImage(ImageReader(buf), 0, 0, width=w, height=h)
        c.setFillColor(white)
        c.rect(40, h - 100, 520, 60, fill=1, stroke=0)
        c.setFillColor(INK)
        c.setFont("Helvetica", 24)
        c.drawString(56, h - 80, f"Stress page {n} of {pages}")
        c.bookmarkPage(f"p{n}")
        if n % 10 == 1:
            c.addOutlineEntry(f"Page {n}", f"p{n}", 0)
        c.showPage()
    c.save()


# ---------------------------------------------------------------- Images and video
def make_images(folder):
    """Three made-up pictures: a floor plan, a heat map and a lookbook page."""
    from PIL import Image, ImageDraw, ImageFont

    def font(size):
        for name in ("arial.ttf", "Arial.ttf", "DejaVuSans.ttf"):
            try:
                return ImageFont.truetype(name, size)
            except OSError:
                continue
        return ImageFont.load_default()

    def caption(draw, w, h, text):
        draw.rectangle([0, h - 80, w, h], fill=(255, 255, 255))
        draw.text((40, h - 62), f"{text}   |   {NOTE}", fill=(54, 54, 54), font=font(30))

    w, h = 2400, 1600
    # Floor plan
    img = Image.new("RGB", (w, h), (247, 246, 244))
    d = ImageDraw.Draw(img)
    d.rectangle([160, 140, w - 160, h - 220], outline=(54, 54, 54), width=8)
    rng = random.Random(21)
    for _ in range(14):
        x, y = rng.randint(220, w - 700), rng.randint(200, h - 520)
        d.rectangle([x, y, x + rng.randint(200, 420), y + rng.randint(120, 260)], outline=(107, 107, 107), width=5)
    d.text((200, 170), "Flagship Floor Plan", fill=(54, 54, 54), font=font(64))
    caption(d, w, h, "Sample image")
    img.save(folder / "Sample - Flagship Floor Plan.jpg", quality=88)

    # Heat map
    img = Image.new("RGB", (w, h), (255, 255, 255))
    d = ImageDraw.Draw(img)
    cols, rows = 12, 7
    cw, ch = (w - 320) // cols, (h - 420) // rows
    for r in range(rows):
        for c in range(cols):
            shade = rng.randint(60, 235)
            d.rectangle([160 + c * cw, 200 + r * ch, 160 + (c + 1) * cw - 6, 200 + (r + 1) * ch - 6], fill=(shade, shade, shade))
    d.text((160, 90), "Weekly Sales Heat Map", fill=(54, 54, 54), font=font(64))
    caption(d, w, h, "Sample image")
    img.save(folder / "Sample - Sales Heat Map.png")

    # Lookbook page (soft gradient)
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(0, w, 1):
            t = (x / w) * 0.6 + (y / h) * 0.4
            px[x, y] = (int(236 - 60 * t), int(228 - 50 * t), int(220 - 45 * t))
    d = ImageDraw.Draw(img)
    d.text((200, 560), "Spring Lookbook", fill=(54, 54, 54), font=font(150))
    caption(d, w, h, "Sample image")
    img.save(folder / "Sample - Spring Lookbook.jpg", quality=88)


def make_video(folder):
    """A 12 second test clip, only if ffmpeg is installed. iPads play H.264 in an MP4."""
    import shutil
    import subprocess

    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        try:  # pip install imageio-ffmpeg bundles a copy
            import imageio_ffmpeg

            ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
        except Exception:
            ffmpeg = None
    if not ffmpeg:
        print("note: ffmpeg not found, so no sample video was made. Run `pip install imageio-ffmpeg` (or `winget install ffmpeg`) and rerun.")
        return None
    target = folder / "Sample - Store Walkthrough.mp4"
    subprocess.run(
        [ffmpeg, "-y", "-loglevel", "error",
         "-f", "lavfi", "-i", "testsrc2=duration=12:size=1280x720:rate=30",
         "-f", "lavfi", "-i", "sine=frequency=440:duration=12",
         "-c:v", "libx264", "-pix_fmt", "yuv420p", "-profile:v", "high",
         "-c:a", "aac", "-shortest", "-movflags", "+faststart", str(target)],
        check=True)
    return target.name


def write_meeting(folder, **fields):
    import json

    (folder / "meeting.json").write_text(json.dumps(fields, indent=2), encoding="utf-8")


def main():
    import datetime
    import shutil

    ap = argparse.ArgumentParser()
    ap.add_argument("--stress", type=int, default=0, help="also write a heavy deck with this many pages")
    args = ap.parse_args()

    # SampleDecks is owned by this script: it is rebuilt from scratch each run.
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir()

    today = datetime.date.today()
    board_day = today + datetime.timedelta(days=19)
    board = OUT / f"Board Meeting - {board_day:%b %d}"
    sync = OUT / "Weekly Leadership Sync"
    board.mkdir()
    sync.mkdir()

    # Loose files (the "Library"): one long document and one image-free one-pager
    long_report(OUT / "Sample - Annual Report (long).pdf")

    # Board meeting: upcoming, confidential, agenda linked to files
    board_book(board / "Sample - Q4 Board Book.pdf")
    slide_deck(
        board / "Sample - Store Performance Review.pdf",
        "Store Performance Review",
        ["Network Overview", "Traffic Trends", "Conversion", "Average Order Value", "Top Regions",
         "Regions Needing Support", "Staffing", "Inventory Position", "Technology Health", "Customer Feedback",
         "Initiatives", "Risks", "Priorities by Quarter", "Investment Plan", "Decisions Needed"],
        bookmarks=True, seed=3)
    make_images(board)
    video = make_video(board)

    agenda = [
        {"time": "9:00 AM", "title": "Welcome and approvals", "presenter": "Chair"},
        {"time": "9:15 AM", "title": "Q4 results", "presenter": "Finance", "file": "Sample - Q4 Board Book.pdf"},
        {"time": "10:00 AM", "title": "Store performance", "presenter": "Operations", "file": "Sample - Store Performance Review.pdf"},
        {"time": "10:45 AM", "title": "Flagship layout", "presenter": "Real Estate", "file": "Sample - Flagship Floor Plan.jpg"},
    ]
    if video:
        agenda.append({"time": "11:15 AM", "title": "Store walkthrough film", "presenter": "Marketing", "file": video})
    agenda.append({"time": "11:45 AM", "title": "Decisions and close", "presenter": "Chair"})
    write_meeting(board, title="Board Meeting (sample)", date=f"{board_day:%Y-%m-%d}", time="9:00 AM",
                  location="Boardroom", confidential=True,
                  note="Sample meeting. Read the Q4 Board Book beforehand.", agenda=agenda)

    # Weekly sync: dated today, so NOW and NEXT follow the clock; no confidential tag
    slide_deck(
        sync / "Sample - Holiday Plan 2026.pdf",
        "Holiday Plan 2026",
        ["Calendar", "Promotions", "Staffing Plan", "Inventory Flow", "Store Hours", "Contingency"],
        bookmarks=False, seed=5)  # no bookmarks on purpose: the Contents button must not appear
    one_pager(sync / "Sample - One Page Brief.pdf")
    make_images(sync)
    for extra in ("Sample - Flagship Floor Plan.jpg", "Sample - Spring Lookbook.jpg"):
        (sync / extra).unlink()
    write_meeting(sync, title="Weekly Leadership Sync (sample)", date=f"{today:%Y-%m-%d}", time="8:30 AM",
                  location="Room 4",
                  agenda=[
                      {"time": "8:30 AM", "title": "Priorities for the week", "presenter": "CEO"},
                      {"time": "9:30 AM", "title": "Holiday plan check", "presenter": "Merchandising", "file": "Sample - Holiday Plan 2026.pdf"},
                      {"time": "11:00 AM", "title": "Sales heat map", "presenter": "Analytics", "file": "Sample - Sales Heat Map.png"},
                      {"time": "1:00 PM", "title": "One page brief", "presenter": "Strategy", "file": "Sample - One Page Brief.pdf"},
                      {"time": "3:00 PM", "title": "Open items", "presenter": "All"},
                      {"time": "4:30 PM", "title": "Wrap up", "presenter": "CEO"},
                  ])

    if args.stress:
        stress(OUT / f"Sample - Stress Test {args.stress} pages.pdf", args.stress)

    for p in sorted(OUT.rglob("*")):
        if p.is_file():
            print(f"{str(p.relative_to(OUT)):70} {p.stat().st_size / 1024 / 1024:.2f} MB")


if __name__ == "__main__":
    main()
