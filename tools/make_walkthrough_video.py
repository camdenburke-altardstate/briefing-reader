#!/usr/bin/env python3
"""Turns the cloud recording into a captioned walkthrough video.

Input: the "walkthrough" artifact from a cloud run (walkthrough-raw.mp4, markers.txt, record-start.txt).
The simulator records its screen sideways in landscape, so landscape stretches are turned upright, the iPad
is shown beside a caption panel, and each step is cut to its caption using the real clock times in markers.txt.

    python tools/make_walkthrough_video.py <folder-with-the-artifact-files> <output.mp4>
        [--offset SECONDS]       how many seconds into the video the recorded clock starts (default 1.2)
        [--portrait-start S --portrait-len S]   the stretch shown in portrait (relative to the "portrait" marker)

Needs Pillow and imageio-ffmpeg (pip install --user pillow imageio-ffmpeg).
"""
import argparse
import os
import subprocess
import sys
import tempfile

import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()

CW, CH = 1280, 720
INK = (54, 54, 54)
PAPER = (245, 244, 242)
GREY = (107, 107, 107)
DEV = (40, 40, 640, 640)        # x, y of the iPad area, width available, height available (left side)

STEPS = {
    "library": ("1", "The library", "Today's meeting opens first. The agenda marks what is NOW and what is NEXT, with the materials beside it."),
    "open-book": ("2", "Open a board book", "One tap. It opens like a book, with no clutter on screen."),
    "spreads": ("3", "Turn the pages", "Tap the edge to turn. Turned sideways, the iPad shows two facing pages."),
    "bar": ("4", "Tools on demand", "Tap the middle for contents, search, bookmark, pen and notes, plus a slider for long documents."),
    "portrait": ("5", "Turn the iPad", "In portrait it shows one page, at the same place. Nothing to set up."),
    "long-report": ("6", "Long documents", "A 320-page report turns with the same taps, two pages at a time, with the slider to jump anywhere."),
    "photo": ("7", "Photos and charts", "Full screen, with pinch to zoom."),
    "manage": ("8", "The assistant's tools", "Load files from a USB or SD card, see what is on the iPad, and clear it all after the meeting."),
    "search": ("9", "Search everything", "Find a word or a name in every document on the iPad."),
    "end": ("", "Offline. Locked down. Wiped in one tap.", "Altar'd State  |  Briefing Reader"),
}


def font(size, bold=False):
    for name in (("segoeuib.ttf" if bold else "segoeui.ttf"), ("arialbd.ttf" if bold else "arial.ttf")):
        p = os.path.join(r"C:\Windows\Fonts", name)
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def wrap(draw, text, fnt, width):
    words, lines, cur = text.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if draw.textlength(t, font=fnt) <= width:
            cur = t
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def panel(step_key, path):
    """A full-canvas background with the caption panel drawn on the right."""
    num, head, text = STEPS[step_key]
    im = Image.new("RGB", (CW, CH), PAPER)
    d = ImageDraw.Draw(im)
    px = 930
    d.rectangle([px, 0, CW, CH], fill=INK)
    logo = Image.open(os.path.join(ROOT, "Brand", "logo-white.png")).convert("RGBA")
    lw = 250
    logo = logo.resize((lw, int(logo.height * lw / logo.width)), Image.LANCZOS)
    im.paste(logo, (px + 40, 52), logo)
    y = 190
    if num:
        d.text((px + 40, y), "STEP " + num, font=font(18, True), fill=(190, 190, 190))
        y += 36
    for ln in wrap(d, head, font(34, True), CW - px - 80):
        d.text((px + 40, y), ln, font=font(34, True), fill=(255, 255, 255))
        y += 44
    y += 14
    for ln in wrap(d, text, font(21), CW - px - 80):
        d.text((px + 40, y), ln, font=font(21), fill=(222, 222, 222))
        y += 31
    d.text((px + 40, CH - 52), "Sample content, not real data", font=font(15), fill=(150, 150, 150))
    im.save(path)


def run(cmd):
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if r.returncode != 0:
        sys.stderr.write(r.stderr.decode("utf8", "ignore")[-2500:])
        raise SystemExit("ffmpeg failed")
    return r


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder")
    ap.add_argument("output")
    ap.add_argument("--offset", type=float, default=1.2)
    ap.add_argument("--portrait-start", type=float, default=0.8)
    ap.add_argument("--portrait-len", type=float, default=7.5)
    ap.add_argument("--lead", type=float, default=4.0, help="seconds of launch to show before the first caption")
    ap.add_argument("--end-hold", type=float, default=3.5)
    a = ap.parse_args()

    raw = os.path.join(a.folder, "walkthrough-raw.mp4")
    marks = []
    for ln in open(os.path.join(a.folder, "markers.txt"), encoding="utf8").read().split("\n"):
        if ln.strip():
            name, t = ln.rsplit(" ", 1)
            marks.append((name, float(t)))
    rec_start = float(open(os.path.join(a.folder, "record-start.txt"), encoding="utf8").read().strip())
    vt = {n: (t - rec_start) - a.offset for n, t in marks}          # video time of each marker
    names = [n for n, _ in marks]
    print("markers in video time:", {n: round(vt[n], 1) for n in names})

    tmp = tempfile.mkdtemp(prefix="walk_")
    segs = []
    for i, key in enumerate(names):
        if key not in STEPS:
            continue
        start = vt[key] - (a.lead if i == 0 else 0)
        end = vt[names[i + 1]] if i + 1 < len(names) else start + a.end_hold
        if key == "end":
            end = start + a.end_hold
        pp = os.path.join(tmp, f"panel_{i}.png")
        panel(key, pp)
        pieces = []
        if key == "portrait":
            ps, pe = start + a.portrait_start, start + a.portrait_start + a.portrait_len
            pieces = [(start, ps, True), (ps, pe, False), (pe, end, True)]
        elif key == "end":
            pieces = []
        else:
            pieces = [(start, end, True)]
        if key == "end":
            # a closing card held on the last frame
            out = os.path.join(tmp, f"seg_{i}.mp4")
            run([FFMPEG, "-y", "-loop", "1", "-t", str(a.end_hold), "-i", pp, "-vf", "format=yuv420p", "-r", "30",
                 "-c:v", "libx264", "-preset", "fast", "-crf", "20", out])
            segs.append(out)
            continue
        for j, (s0, s1, landscape) in enumerate(pieces):
            if s1 - s0 < 0.2:
                continue
            out = os.path.join(tmp, f"seg_{i}_{j}.mp4")
            if landscape:
                rot = "transpose=2,"            # 90 degrees counter-clockwise
                h = DEV[3] - 50
                scale = f"scale=-2:{h}"
            else:
                rot = ""
                scale = f"scale=-2:{DEV[3]}"
            fc = (f"[0:v]{rot}{scale},setsar=1[dev];[1:v][dev]overlay=x=({DEV[0]}+({DEV[2]}+180-w)/2):y=({CH}-h)/2,"
                  f"format=yuv420p[v]")
            run([FFMPEG, "-y", "-ss", f"{max(s0, 0):.3f}", "-t", f"{s1 - s0:.3f}", "-i", raw, "-loop", "1", "-i", pp,
                 "-filter_complex", fc, "-map", "[v]", "-shortest", "-r", "30", "-c:v", "libx264", "-preset", "fast",
                 "-crf", "21", "-an", out])
            segs.append(out)

    lst = os.path.join(tmp, "list.txt")
    with open(lst, "w", encoding="utf8") as f:
        for s in segs:
            f.write("file '" + s.replace("\\", "/") + "'\n")
    run([FFMPEG, "-y", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", a.output])
    print("wrote", a.output)


if __name__ == "__main__":
    main()
