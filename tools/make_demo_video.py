"""
Builds Demo/Briefing-Reader-Demo.mp4 from the iPad mockup.

    python tools/make_demo_video.py            # capture every scene, then build the video
    python tools/make_demo_video.py capture    # only capture frames
    python tools/make_demo_video.py video      # only build the video from the captured frames

How it works: Microsoft Edge (headless) opens the mockup at tools/ipad-sim/index.html?demo=<scene>, which
puts the mockup in a known state, and screenshots it. Pillow adds captions, and ffmpeg joins the frames with
cross-fades. Needs: Edge, the local server running (start tools/ipad-sim/start-mockup.cmd), pillow,
imageio-ffmpeg. The video shows the BROWSER MOCKUP of the app, not the Swift app running on an iPad.
"""
import base64
import json
import os
import shutil
import socket
import struct
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FRAMES = ROOT / "Demo" / "frames"
OUT = ROOT / "Demo" / "Briefing-Reader-Demo.mp4"
URL = "http://127.0.0.1:8765/tools/ipad-sim/index.html?demo="
EDGE = next((p for p in (
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Google\Chrome\Application\chrome.exe") if Path(p).exists()), None)

W, H = 1920, 1080
INK = (54, 54, 54)
GRAY = (107, 107, 107)
PAPER = (255, 255, 255)
BACK = (245, 244, 242)

LAND = (1500, 1150)   # window used for landscape scenes
PORT = (1150, 1500)   # window used for portrait scenes

# (scene, window, seconds, headline, detail)
SCENES = [
    ("lib-land", LAND, 6, "Your meetings, ready to open",
     "Each meeting shows its agenda beside its materials. NOW and NEXT follow the iPad clock. "
     "Continue picks up the last thing you read."),
    ("port-lib", PORT, 5, "Portrait: agenda above, materials below",
     "Held upright, the library stacks the agenda over three columns of covers."),
    ("cover", LAND, 4, "Opens like a book",
     "Landscape, a report starts with the cover alone on the right. No toolbars in the way."),
    ("spread", LAND, 6, "Two pages, like Apple Books",
     "A soft spine shadow, \"Pages 8-9 of 31\", the time in the corner. Tap the edges or swipe to turn a whole spread."),
    ("port-read", PORT, 5, "Portrait: one page, like Kindle",
     "One page fills the width. A quiet footer shows where you are."),
    ("spread-bar", LAND, 6, "Tap the middle for the bar",
     "Contents, search, bookmark, notes, pen and display. Drag the scrubber to preview any page."),
    ("long-scrub", LAND, 6, "Built for 300-page documents",
     "The scrubber names the chapter under your finger: \"Page 213, Chapter 35\". The page jumps once, on release."),
    ("contents", LAND, 5, "Contents and bookmarks",
     "Every bookmark level, indented, with your own bookmarked pages on top."),
    ("slides", LAND, 5, "Slide decks stay a single page",
     "Wide pages fill the screen, the way Kindle shows them."),
    ("search", LAND, 6, "Search every document at once",
     "Find a figure when you do not know which file it is in. Tap a result to open it on that page."),
    ("pen", LAND, 6, "Write with Apple Pencil",
     "Pens, highlighter and eraser. Saved beside the PDF, never inside it, and cleared with the meeting."),
    ("night", LAND, 5, "Night tone for a dark room",
     "White, Warm or Night, plus a brightness slider, since Control Center is off in kiosk mode."),
    ("photos", LAND, 5, "Photos, full screen",
     "Swipe between a meeting's photos. Pinch or double-tap to zoom."),
    ("video", LAND, 5, "Video and audio, offline",
     "Plays from the iPad, remembers where you stopped, and cannot pop out of the locked app."),
    ("manage", LAND, 6, "Load and clear without technical help",
     "Plug in a USB drive or SD card, tap Manage, pick files or a folder. One button clears the iPad for the next meeting."),
    ("destination", LAND, 6, "Say which meeting the files belong to",
     "A new meeting or an existing one. PowerPoint and Word are declined with a plain explanation: save as PDF first."),
]


class Cdp:
    """A tiny Chrome DevTools Protocol client (plain sockets), so no extra packages are needed."""

    def __init__(self, ws_url):
        u = urllib.parse.urlparse(ws_url)
        self.sock = socket.create_connection((u.hostname, u.port), timeout=120)
        key = base64.b64encode(os.urandom(16)).decode()
        self.sock.sendall((f"GET {u.path} HTTP/1.1\r\nHost: {u.hostname}:{u.port}\r\nUpgrade: websocket\r\n"
                           f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n").encode())
        head = b""
        while b"\r\n\r\n" not in head:
            head += self.sock.recv(1024)
        self.buf = head.split(b"\r\n\r\n", 1)[1]
        self.n = 0

    def _exact(self, n):
        while len(self.buf) < n:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise EOFError("connection closed")
            self.buf += chunk
        data, self.buf = self.buf[:n], self.buf[n:]
        return data

    def _message(self):
        data = b""
        while True:
            b1, b2 = self._exact(2)
            fin, op, ln = b1 & 0x80, b1 & 0x0F, b2 & 0x7F
            if ln == 126:
                ln = struct.unpack(">H", self._exact(2))[0]
            elif ln == 127:
                ln = struct.unpack(">Q", self._exact(8))[0]
            payload = self._exact(ln)
            if op == 0x8:
                raise EOFError("closed")
            if op in (0x0, 0x1, 0x2):
                data += payload
                if fin:
                    return data

    def call(self, method, **params):
        self.n += 1
        msg = json.dumps({"id": self.n, "method": method, "params": params}).encode()
        mask = os.urandom(4)
        head = bytearray([0x81])
        if len(msg) < 126:
            head.append(0x80 | len(msg))
        elif len(msg) < 65536:
            head.append(0x80 | 126)
            head += struct.pack(">H", len(msg))
        else:
            head.append(0x80 | 127)
            head += struct.pack(">Q", len(msg))
        head += mask
        self.sock.sendall(bytes(head) + bytes(b ^ mask[i % 4] for i, b in enumerate(msg)))
        while True:
            reply = json.loads(self._message())
            if reply.get("id") == self.n:
                if "error" in reply:
                    raise RuntimeError(reply["error"])
                return reply.get("result", {})

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass


def _http(url, method="GET"):
    return json.load(urllib.request.urlopen(urllib.request.Request(url, method=method), timeout=30))


def capture(only=None):
    if not EDGE:
        sys.exit("Edge or Chrome not found")
    FRAMES.mkdir(parents=True, exist_ok=True)
    port = 9333
    profile = tempfile.mkdtemp(prefix="demo-edge-")
    subprocess.Popen([EDGE, "--headless=new", "--disable-gpu", "--no-first-run", "--hide-scrollbars",
                      "--no-default-browser-check", f"--user-data-dir={profile}",
                      f"--remote-debugging-port={port}", "about:blank"])
    version = None
    for _ in range(40):
        try:
            version = _http(f"http://127.0.0.1:{port}/json/version")
            break
        except Exception:
            time.sleep(1)
    if not version:
        sys.exit("Edge did not start")
    try:
        for scene, (w, h), *_ in SCENES:
            if only and scene != only:
                continue
            target = FRAMES / f"{scene}.png"
            t0 = time.time()
            tab = _http(f"http://127.0.0.1:{port}/json/new?about:blank", method="PUT")
            cdp = Cdp(tab["webSocketDebuggerUrl"])
            try:
                cdp.call("Page.enable")
                # A background headless tab gets no animation frames, which stops pdf.js painting pages.
                cdp.call("Page.addScriptToEvaluateOnNewDocument",
                         source="window.requestAnimationFrame = cb => setTimeout(() => cb(performance.now()), 16);")
                cdp.call("Emulation.setDeviceMetricsOverride", width=w, height=h, deviceScaleFactor=1, mobile=False)
                cdp.call("Page.navigate", url=URL + scene)
                cdp.call("Page.bringToFront")   # a tab in the background does not composite its canvases
                ready = False
                title = ""
                for _ in range(150):
                    title = str(cdp.call("Runtime.evaluate", expression="document.title", returnByValue=True)["result"].get("value", ""))
                    if title.startswith("READY"):
                        ready = True
                        break
                    time.sleep(1)
                time.sleep(1.2)   # let the last animation settle
                cdp.call("Page.bringToFront")
                shot = cdp.call("Page.captureScreenshot", format="png")
                target.write_bytes(base64.b64decode(shot["data"]))
                print(f"  {scene}: {title if ready else 'NEVER READY'} ({time.time() - t0:.0f}s)")
            finally:
                cdp.close()
                try:
                    _http(f"http://127.0.0.1:{port}/json/close/{tab['id']}")
                except Exception:
                    pass
    finally:
        try:
            Cdp(version["webSocketDebuggerUrl"]).call("Browser.close")
        except Exception:
            pass
        shutil.rmtree(profile, ignore_errors=True)


def font(size, bold=False):
    from PIL import ImageFont
    for name in (("segoeuib.ttf" if bold else "segoeui.ttf"), "arialbd.ttf" if bold else "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def wrap(draw, text, fnt, width):
    words, lines, line = text.split(), [], ""
    for word in words:
        trial = (line + " " + word).strip()
        if draw.textlength(trial, font=fnt) <= width:
            line = trial
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def card(title, sub, name, logo=True):
    from PIL import Image, ImageDraw
    img = Image.new("RGB", (W, H), INK)
    d = ImageDraw.Draw(img)
    mark = ROOT / "Brand" / "logo-white.png"
    if logo and mark.exists():
        m = Image.open(mark).convert("RGBA")
        m = m.resize((760, int(760 * m.height / m.width)))
        img.paste(m, ((W - m.width) // 2, 330), m)
    d.text((W // 2, 520), title, font=font(54, True), fill=PAPER, anchor="mm")
    y = 600
    for line in wrap(d, sub, font(30), 1200):
        d.text((W // 2, y), line, font=font(30), fill=(201, 201, 200), anchor="mm")
        y += 44
    path = FRAMES / f"slide-{name}.png"
    img.save(path)
    return path


def slide(scene, headline, detail):
    """A 1920x1080 slide: the screenshot on the right (or centered for portrait), the words on the left."""
    from PIL import Image, ImageDraw
    shot = Image.open(FRAMES / f"{scene}.png").convert("RGB")
    img = Image.new("RGB", (W, H), BACK)
    d = ImageDraw.Draw(img)
    portrait = shot.height > shot.width
    if portrait:
        box = (W - 640 - 90, 40, W - 90, H - 40)
        text_w = 760
    else:
        box = (600, 90, W - 50, H - 90)
        text_w = 470
    bw, bh = box[2] - box[0], box[3] - box[1]
    scale = min(bw / shot.width, bh / shot.height)
    fit = shot.resize((int(shot.width * scale), int(shot.height * scale)), Image.LANCZOS)
    x = box[0] + (bw - fit.width) // 2
    y = box[1] + (bh - fit.height) // 2
    img.paste(fit, (x, y))
    # headline and detail
    ty = 330 if not portrait else 380
    d.rectangle((70, ty - 28, 130, ty - 24), fill=INK)
    for line in wrap(d, headline, font(46, True), text_w):
        d.text((70, ty), line, font=font(46, True), fill=INK)
        ty += 62
    ty += 18
    for line in wrap(d, detail, font(27), text_w):
        d.text((70, ty), line, font=font(27), fill=GRAY)
        ty += 40
    d.text((70, H - 54), "Briefing Reader  |  mockup of the app screens, sample content", font=font(20), fill=(160, 160, 160))
    path = FRAMES / f"slide-{scene}.png"
    img.save(path)
    return path


def video():
    import imageio_ffmpeg
    ff = imageio_ffmpeg.get_ffmpeg_exe()
    parts = [(card("Briefing Reader", "An offline reading and meeting app for the executive iPads", "title"), 4)]
    for scene, _win, secs, head, detail in SCENES:
        if not (FRAMES / f"{scene}.png").exists():
            print(f"  skipping {scene}: no frame")
            continue
        parts.append((slide(scene, head, detail), secs))
    parts.append((card("What is real, and what is not",
                       "Everything shown is a browser mockup with sample content. The Swift app is written and reviewed "
                       "but has not been built or run on an iPad yet.", "end", logo=False), 6))

    fade = 0.6
    args = [ff, "-y", "-loglevel", "error"]
    for path, secs in parts:
        args += ["-loop", "1", "-t", str(secs + fade), "-i", str(path)]
    # chain cross-fades
    filters, last, offset = [], "[0:v]", 0.0
    for i in range(1, len(parts)):
        offset += parts[i - 1][1]
        out = f"[v{i}]"
        filters.append(f"{last}[{i}:v]xfade=transition=fade:duration={fade}:offset={offset:.2f}{out}")
        last = out
    args += ["-filter_complex", ";".join(filters), "-map", last, "-r", "30", "-c:v", "libx264", "-pix_fmt", "yuv420p",
             "-crf", "20", "-preset", "medium", "-movflags", "+faststart", str(OUT)]
    subprocess.run(args, check=True)
    total = sum(s for _, s in parts)
    print(f"wrote {OUT}  ({OUT.stat().st_size / 1024 / 1024:.1f} MB, about {total}s)")


if __name__ == "__main__":
    step = sys.argv[1] if len(sys.argv) > 1 else "all"
    if step in ("all", "capture"):
        capture(sys.argv[2] if len(sys.argv) > 2 else None)
    if step in ("all", "video"):
        video()
