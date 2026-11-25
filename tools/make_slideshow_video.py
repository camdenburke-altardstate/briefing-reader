#!/usr/bin/env python3
"""A captioned walkthrough video made from the real simulator screenshots (no recording needed).

    python tools/make_slideshow_video.py <folder-of-screenshots> <output.mp4>

Looks for the files named in SHOTS inside the folder (the cloud run's "screenshots" artifact, straightened).
Uses the same caption panel as make_walkthrough_video.py.
"""
import os
import sys
import tempfile

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_walkthrough_video as mw  # noqa: E402

# (caption key, screenshot, seconds)
SHOTS = [
    ("library", "01-library-landscape", 7),
    ("open-book", "10-board-book-landscape-cover", 4),
    ("spreads", "11-board-book-landscape-spread", 5),
    ("spreads", "12-board-book-landscape-later", 4),
    ("bar", "13-board-book-landscape-bar", 6),
    ("portrait", "21-board-book-portrait-page", 5),
    ("portrait", "22-board-book-portrait-bar", 4),
    ("long-report", "31-long-report-after-turns", 6),
    ("photo", "50-photo", 4),
    ("manage", "60-manage", 6),
    ("search", "61-search", 5),
]


def find(folders, name):
    for f in folders:
        p = os.path.join(f, name + ".png")
        if os.path.exists(p):
            return p
    return None


def main():
    folders = sys.argv[1].split(";")
    out = sys.argv[2]
    tmp = tempfile.mkdtemp(prefix="slides_")
    segs = []
    for i, (key, name, secs) in enumerate(SHOTS):
        src = find(folders, name)
        if not src:
            print("missing", name)
            continue
        pp = os.path.join(tmp, f"panel_{i}.png")
        mw.panel(key, pp)
        im = Image.open(src).convert("RGB")
        landscape = im.width > im.height
        # re-save without metadata: the screenshots carry an orientation tag that the video encoder
        # would obey (turning them sideways) while the pixels are already upright
        clean = os.path.join(tmp, f"shot_{i}.png")
        im.save(clean)
        src = clean
        h = mw.DEV[3] - 50 if landscape else mw.DEV[3]
        seg = os.path.join(tmp, f"seg_{i}.mp4")
        # a slow push-in on the picture, so it feels alive rather than frozen
        fc = (f"[1:v]scale=-2:{h},setsar=1[dev];"
              f"[0:v][dev]overlay=x=({mw.DEV[0]}+({mw.DEV[2]}+180-w)/2):y=({mw.CH}-h)/2,format=yuv420p,"
              f"fade=t=in:st=0:d=0.4[v]")
        mw.run([mw.FFMPEG, "-y", "-loop", "1", "-t", str(secs), "-i", pp, "-loop", "1", "-t", str(secs), "-i", src,
                "-filter_complex", fc, "-map", "[v]", "-r", "30", "-c:v", "libx264", "-preset", "fast", "-crf", "21", seg])
        segs.append(seg)
    # closing card
    pp = os.path.join(tmp, "panel_end.png")
    mw.panel("end", pp)
    seg = os.path.join(tmp, "seg_end.mp4")
    mw.run([mw.FFMPEG, "-y", "-loop", "1", "-t", "3.5", "-i", pp, "-vf", "format=yuv420p", "-r", "30",
            "-c:v", "libx264", "-preset", "fast", "-crf", "20", seg])
    segs.append(seg)
    lst = os.path.join(tmp, "list.txt")
    with open(lst, "w", encoding="utf8") as f:
        for s in segs:
            f.write("file '" + s.replace("\\", "/") + "'\n")
    mw.run([mw.FFMPEG, "-y", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", out])
    print("wrote", out, os.path.getsize(out) // 1024, "KB")


if __name__ == "__main__":
    main()
