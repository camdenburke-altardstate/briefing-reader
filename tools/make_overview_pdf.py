#!/usr/bin/env python3
"""Builds docs/Briefing-Reader-Overview.pdf: purpose, UX flow, features, tech stack and status.

Uses the real screenshots in docs/screens (taken by the cloud simulator run). Needs reportlab.
    python tools/make_overview_pdf.py
No em dashes and no symbols outside the standard PDF fonts, so it renders the same everywhere.
"""
import os
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_LEFT, TA_CENTER
from reportlab.platypus import (BaseDocTemplate, PageTemplate, Frame, Paragraph, Spacer, Table, TableStyle,
                                PageBreak, KeepTogether, Flowable)
from reportlab.lib.utils import ImageReader

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SHOTS = os.path.join(ROOT, "docs", "screens")
OUT = os.path.join(ROOT, "docs", "Briefing-Reader-Overview.pdf")

INK = colors.HexColor("#363636")
GREY = colors.HexColor("#6b6b6b")
HAIR = colors.HexColor("#d9d9d9")
WELL = colors.HexColor("#f5f4f2")
GREEN = colors.HexColor("#2e7d4f")
AMBER = colors.HexColor("#a35f00")
BEZEL = colors.HexColor("#1d1d1f")

W, H = letter
M = 40
CW = W - 2 * M

# ---------- styles
body = ParagraphStyle("body", fontName="Helvetica", fontSize=9.5, leading=13.5, textColor=INK, spaceAfter=5)
small = ParagraphStyle("small", parent=body, fontSize=8, leading=10.5, textColor=GREY, spaceAfter=0)
cell = ParagraphStyle("cell", parent=body, fontSize=8.6, leading=11.5, spaceAfter=0)
cellb = ParagraphStyle("cellb", parent=cell, fontName="Helvetica-Bold")
h1 = ParagraphStyle("h1", fontName="Helvetica-Bold", fontSize=21, leading=25, textColor=INK, spaceAfter=4)
h2 = ParagraphStyle("h2", fontName="Helvetica-Bold", fontSize=12, leading=15, textColor=INK, spaceBefore=10, spaceAfter=4)
kicker = ParagraphStyle("kicker", fontName="Helvetica", fontSize=8.5, leading=11, textColor=GREY, spaceAfter=2)
cap = ParagraphStyle("cap", parent=small, alignment=TA_CENTER, spaceBefore=4)
bullet = ParagraphStyle("bullet", parent=body, leftIndent=12, bulletIndent=2, spaceAfter=3)
title = ParagraphStyle("title", fontName="Helvetica-Bold", fontSize=34, leading=38, textColor=INK)
sub = ParagraphStyle("sub", fontName="Helvetica", fontSize=14, leading=19, textColor=GREY)


def P(text, style=body):
    return Paragraph(text, style)


def bullets(items, style=bullet):
    return [Paragraph(t, style, bulletText="•") for t in items]


def page_title(kick, text):
    return [P(kick.upper(), kicker), P(text, h1), Rule(CW), Spacer(1, 8)]


class Rule(Flowable):
    def __init__(self, width, color=HAIR, thick=0.8):
        super().__init__()
        self.width, self.color, self.thick = width, color, thick

    def wrap(self, aw, ah):
        return self.width, 3

    def draw(self):
        self.canv.setStrokeColor(self.color)
        self.canv.setLineWidth(self.thick)
        self.canv.line(0, 1, self.width, 1)


class Shot(Flowable):
    """A screenshot inside a simple iPad bezel, at a given width."""

    def __init__(self, name, width):
        super().__init__()
        self.path = os.path.join(SHOTS, name + ".jpg")
        img = ImageReader(self.path)
        iw, ih = img.getSize()
        self.pad = 5
        self.iw = width - 2 * self.pad
        self.ih = self.iw * ih / iw
        self.width = width
        self.height = self.ih + 2 * self.pad

    def wrap(self, aw, ah):
        return self.width, self.height

    def draw(self):
        c = self.canv
        c.setFillColor(BEZEL)
        c.roundRect(0, 0, self.width, self.height, 9, stroke=0, fill=1)
        c.saveState()
        p = c.beginPath()
        p.roundRect(self.pad, self.pad, self.iw, self.ih, 5)
        c.clipPath(p, stroke=0, fill=0)
        c.drawImage(self.path, self.pad, self.pad, self.iw, self.ih)
        c.restoreState()


def shot_cell(name, width, caption):
    return [Shot(name, width), P(caption, cap)]


def gallery(cells, widths):
    t = Table([cells], colWidths=widths)
    t.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("LEFTPADDING", (0, 0), (-1, -1), 4),
                           ("RIGHTPADDING", (0, 0), (-1, -1), 4), ("TOPPADDING", (0, 0), (-1, -1), 0)]))
    return t


class FlowDiagram(Flowable):
    """Four stages in a row with arrows, then who does what."""

    def __init__(self, width):
        super().__init__()
        self.width = width
        self.height = 150

    def wrap(self, aw, ah):
        return self.width, self.height

    def draw(self):
        c = self.canv
        stages = [
            ("1  PREPARE", "Assistant, on a PC", ["Files in one folder", "per meeting", "Optional agenda file"]),
            ("2  LOAD", "Assistant, on the iPad", ["Manage > Choose files", "or Choose a folder", "from USB or SD card"]),
            ("3  MEETING", "Executive", ["Library and agenda", "Open and read", "Notes, search, markup"]),
            ("4  WIPE", "Assistant", ["Manage > Remove", "or Clear everything", "Ready for the next one"]),
        ]
        n = len(stages)
        gap = 22
        bw = (self.width - gap * (n - 1)) / n
        for i, (head, who, lines) in enumerate(stages):
            x = i * (bw + gap)
            c.setFillColor(WELL)
            c.setStrokeColor(HAIR)
            c.roundRect(x, 10, bw, 130, 6, stroke=1, fill=1)
            c.setFillColor(INK)
            c.roundRect(x, 112, bw, 28, 6, stroke=0, fill=1)
            c.rect(x, 112, bw, 10, stroke=0, fill=1)
            c.setFillColor(colors.white)
            c.setFont("Helvetica-Bold", 10)
            c.drawString(x + 10, 122, head)
            c.setFillColor(GREY)
            c.setFont("Helvetica-Oblique", 8.5)
            c.drawString(x + 10, 96, who)
            c.setFillColor(INK)
            c.setFont("Helvetica", 9)
            y = 76
            for ln in lines:
                c.drawString(x + 10, y, ln)
                y -= 15
            if i < n - 1:
                ax = x + bw + 3
                c.setStrokeColor(INK)
                c.setFillColor(INK)
                c.setLineWidth(1.4)
                c.line(ax, 75, ax + gap - 9, 75)
                p = c.beginPath()
                p.moveTo(ax + gap - 5, 75)
                p.lineTo(ax + gap - 11, 79)
                p.lineTo(ax + gap - 11, 71)
                p.close()
                c.drawPath(p, stroke=0, fill=1)


class ScreenMap(Flowable):
    """Library in the middle, every screen it opens around it."""

    def __init__(self, width):
        super().__init__()
        self.width = width
        self.height = 158

    def wrap(self, aw, ah):
        return self.width, self.height

    def box(self, x, y, w, h, text, sub_text="", dark=False):
        c = self.canv
        c.setFillColor(INK if dark else WELL)
        c.setStrokeColor(INK if dark else HAIR)
        c.roundRect(x, y, w, h, 5, stroke=1, fill=1)
        c.setFillColor(colors.white if dark else INK)
        c.setFont("Helvetica-Bold", 9)
        c.drawCentredString(x + w / 2, y + h / 2 + (3 if sub_text else -3), text)
        if sub_text:
            c.setFillColor(colors.HexColor("#d0d0d0") if dark else GREY)
            c.setFont("Helvetica", 7.5)
            c.drawCentredString(x + w / 2, y + h / 2 - 8, sub_text)

    def link(self, x1, y1, x2, y2):
        c = self.canv
        c.setStrokeColor(GREY)
        c.setLineWidth(1)
        c.line(x1, y1, x2, y2)

    def draw(self):
        w = self.width
        cx, cy = w / 2, 75
        self.box(cx - 70, cy - 24, 140, 48, "LIBRARY", "agenda and materials", dark=True)
        bw, bh = 118, 36
        left = [("READER", "PDF books and decks", 118), ("PHOTO", "zoom and swipe", 72), ("VIDEO / AUDIO", "play and resume", 26)]
        right = [("NOTES", "typed, per meeting", 118), ("SEARCH", "every document", 72), ("MANAGE", "load, remove, wipe", 26)]
        for text, s, y in left:
            self.link(cx - 70, cy, 10 + bw, y + bh / 2 + 0)
            self.box(10, y - 4, bw, bh, text, s)
        for text, s, y in right:
            self.link(cx + 70, cy, w - 10 - bw, y + bh / 2)
            self.box(w - 10 - bw, y - 4, bw, bh, text, s)


class ArchDiagram(Flowable):
    def __init__(self, width):
        super().__init__()
        self.width = width
        self.height = 182

    def wrap(self, aw, ah):
        return self.width, self.height

    def layer(self, y, label, items, h=46):
        c = self.canv
        c.setFillColor(INK)
        c.roundRect(0, y, 92, h, 5, stroke=0, fill=1)
        c.setFillColor(colors.white)
        c.setFont("Helvetica-Bold", 9)
        c.drawCentredString(46, y + h / 2 - 3, label)
        n = len(items)
        gap = 6
        bw = (self.width - 100 - gap * (n - 1)) / n
        for i, (name, note) in enumerate(items):
            x = 100 + i * (bw + gap)
            c.setFillColor(WELL)
            c.setStrokeColor(HAIR)
            c.roundRect(x, y, bw, h, 5, stroke=1, fill=1)
            c.setFillColor(INK)
            c.setFont("Helvetica-Bold", 8.3)
            c.drawCentredString(x + bw / 2, y + h - 18, name)
            c.setFillColor(GREY)
            c.setFont("Helvetica", 7.4)
            lines = note.split("|")
            yy = y + h - 30
            for ln in lines:
                c.drawCentredString(x + bw / 2, yy, ln)
                yy -= 9.5

    def draw(self):
        self.layer(136, "VIEWS", [("LibraryView", "agenda, cards|Continue row"), ("ReaderView", "PDF, spreads|bar, scrubber"),
                                  ("ViewerScreen", "photo, video|router"), ("ManageView", "load, wipe|PIN"),
                                  ("Search + Notes", "all documents|per meeting")])
        self.layer(73, "MODEL", [("LibraryStore", "scans folders|progress, bookmarks"), ("ContentManager", "import, remove|PIN, naming"),
                                 ("MarkupStore", "Pencil strokes|per page"), ("ThumbnailCache", "covers, photos|downsampled")])
        self.layer(10, "APP", [("BriefingReaderApp", "starts the library"), ("Branding", "colors, fonts|reading tones"),
                               ("Kiosk", "asks iPadOS for|Single App Mode")])


class PipeDiagram(Flowable):
    def __init__(self, width):
        super().__init__()
        self.width = width
        self.height = 78

    def wrap(self, aw, ah):
        return self.width, self.height

    def draw(self):
        c = self.canv
        steps = [("Source code", "on a Windows PC"), ("GitHub", "private repository"),
                 ("Cloud Mac", "Xcode 16.4, iPad simulator"), ("Checks", "build, 14 tests, screenshots"),
                 ("Signed .ipa", "needs Apple account")]
        n = len(steps)
        gap = 16
        bw = (self.width - gap * (n - 1)) / n
        for i, (a, b) in enumerate(steps):
            x = i * (bw + gap)
            last = i == n - 1
            c.setFillColor(colors.white if last else WELL)
            c.setStrokeColor(AMBER if last else HAIR)
            if last:
                c.setDash(3, 2)
            c.roundRect(x, 8, bw, 56, 5, stroke=1, fill=1)
            c.setDash()
            c.setFillColor(INK)
            c.setFont("Helvetica-Bold", 8.8)
            c.drawCentredString(x + bw / 2, 44, a)
            c.setFillColor(GREY)
            c.setFont("Helvetica", 7.4)
            c.drawCentredString(x + bw / 2, 30, b)
            if i < n - 1:
                ax = x + bw + 2
                c.setStrokeColor(INK)
                c.setFillColor(INK)
                c.setLineWidth(1.2)
                c.line(ax, 36, ax + gap - 7, 36)
                p = c.beginPath()
                p.moveTo(ax + gap - 3, 36)
                p.lineTo(ax + gap - 8, 39)
                p.lineTo(ax + gap - 8, 33)
                p.close()
                c.drawPath(p, stroke=0, fill=1)


def table(rows, widths, header=True, zebra=True):
    t = Table(rows, colWidths=widths, repeatRows=1 if header else 0)
    style = [("VALIGN", (0, 0), (-1, -1), "TOP"), ("LEFTPADDING", (0, 0), (-1, -1), 6), ("RIGHTPADDING", (0, 0), (-1, -1), 6),
             ("TOPPADDING", (0, 0), (-1, -1), 4), ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
             ("LINEBELOW", (0, 0), (-1, -1), 0.5, HAIR)]
    if header:
        style += [("BACKGROUND", (0, 0), (-1, 0), INK), ("TEXTCOLOR", (0, 0), (-1, 0), colors.white)]
    if zebra:
        for r in range(1, len(rows)):
            if r % 2 == 0:
                style.append(("BACKGROUND", (0, r), (-1, r), WELL))
    t.setStyle(TableStyle(style))
    return t


def hdr(text):
    return Paragraph(text, ParagraphStyle("th", parent=cellb, textColor=colors.white))


def status(kind):
    if kind == "ok":
        return Paragraph('<font color="#2e7d4f"><b>Seen working</b></font> in the simulator', cell)
    if kind == "code":
        return Paragraph('<font color="#2e7d4f"><b>Checked</b></font> in the code', cell)
    if kind == "part":
        return Paragraph('<font color="#a35f00"><b>Built</b></font>, only partly exercised', cell)
    return Paragraph('<font color="#a35f00"><b>Built</b></font>, not yet tested', cell)


# ---------- page furniture
def furniture(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(INK)
    canvas.rect(0, H - 24, W, 24, stroke=0, fill=1)
    canvas.setFillColor(colors.white)
    canvas.setFont("Helvetica-Bold", 8.5)
    canvas.drawString(M, H - 16, "ALTAR'D STATE")
    canvas.setFont("Helvetica", 8.5)
    canvas.drawRightString(W - M, H - 16, "Briefing Reader  |  Overview")
    canvas.setFillColor(GREY)
    canvas.setFont("Helvetica", 8)
    canvas.drawString(M, 22, "Offline executive reading for iPad. Sample content only, no real company data.")
    canvas.drawRightString(W - M, 22, "Page %d" % doc.page)
    canvas.restoreState()


def build():
    doc = BaseDocTemplate(OUT, pagesize=letter, leftMargin=M, rightMargin=M, topMargin=44, bottomMargin=40,
                          title="Briefing Reader: purpose, UX flow, features and tech stack",
                          author="Altar'd State", subject="Executive iPad reader overview")
    frame = Frame(M, 40, CW, H - 44 - 40, leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0, id="f")
    doc.addPageTemplates([PageTemplate(id="p", frames=[frame], onPage=furniture)])
    s = []

    # ===== 1 cover
    s += [Spacer(1, 40), P("ALTAR'D STATE  |  EXECUTIVE BRIEFINGS", kicker), Spacer(1, 6),
          P("Briefing Reader", title), Spacer(1, 6),
          P("An offline iPad reader for board books, decks, photos and video, built to feel like a book and locked down like a kiosk.", sub),
          Spacer(1, 22)]
    s.append(gallery([shot_cell("01-library-landscape", 330, "The library on a landscape iPad: today's agenda beside its materials"),
                      shot_cell("03-library-portrait", 175, "The same screen in portrait")], [CW - 190, 190]))
    s += [Spacer(1, 18), Rule(CW), Spacer(1, 8),
          P("This document covers why it exists, how people use it from start to finish, what it can do, and what it is built with. "
            "Every picture is the real app, captured by an automated run on a cloud Mac using Apple's iPad simulator.", body),
          P("<b>Honest status:</b> the app compiles, its 14 logic tests pass, and its main screens have been exercised in the simulator. "
            "It has not yet run on a physical iPad, so Apple Pencil, USB loading and the kiosk lock are still to be proven. "
            "Page 8 lists exactly what is and is not proven.", body), PageBreak()]

    # ===== 2 purpose
    s += page_title("Purpose", "Why it exists")
    s += [P("<b>The problem.</b> Board books and executive decks are printed for every meeting. That costs paper and time, "
            "the pages are out of date as soon as something changes, and loose paper copies of confidential material are hard to control."),
          P("<b>The idea.</b> Four executive iPads that run one app. The app opens board books and decks like a real book, shows photos and "
            "video, keeps each meeting's agenda and materials together, and works with no internet. An assistant loads the files before a "
            "meeting and wipes them afterwards, with no technical knowledge. Nothing is sent anywhere."),
          Spacer(1, 4)]
    rows = [[hdr("Who"), hdr("What they do"), hdr("What they need from the app")],
            [P("<b>Executives</b>", cell), P("Read the board book, follow the agenda, glance at photos and video, jot notes.", cell),
             P("Opens straight to reading, no clutter, remembers the page, never needs setup.", cell)],
            [P("<b>Assistant</b>", cell), P("Puts the right files on the iPads before a meeting and clears them after.", cell),
             P("One Manage screen: choose files or a folder from a USB or SD card, remove, clear everything.", cell)],
            [P("<b>IT</b>", cell), P("Signs and installs the app once a year, supervises the iPads, sets the lock.", cell),
             P("A signed build, a lock profile, and a clear list of what it stores.", cell)]]
    s += [table(rows, [80, 215, CW - 295]), Spacer(1, 10), P("Design principles", h2)]
    s += bullets(["<b>Offline.</b> No accounts, no cloud, no network use. Files go on by USB or SD card.",
                  "<b>Book-like.</b> Tap the edge to turn a page, tap the middle for tools, two pages side by side when the iPad is turned sideways. "
                  "Handles documents of 300 or more pages.",
                  "<b>Locked down.</b> Runs in Single App Mode on supervised iPads: no Home gesture, no screenshots, no AirDrop, no app removal.",
                  "<b>No training.</b> Load and wipe are two buttons, with plain words. Where it is risky (clear everything) it asks first, and a PIN can guard it.",
                  "<b>On brand.</b> Altar'd State wordmark, charcoal on white, quiet type, no decoration that competes with the content."])
    s += [Spacer(1, 6), P("What success looks like", h2)]
    s += bullets(["A meeting pack is loaded in minutes and every executive opens it without help.",
                  "After the meeting one action returns the iPad to empty, including notes and handwriting.",
                  "Fewer printed packs, and no confidential paper left behind."]) + [PageBreak()]

    # ===== 3 UX flow
    s += page_title("UX flow", "From the assistant's desk to the boardroom and back")
    s += [FlowDiagram(CW), Spacer(1, 10)]
    rows = [[hdr("Stage"), hdr("What happens on screen")],
            [P("<b>1 Prepare</b>", cell), P("On any PC: one folder per meeting holding the PDFs, photos and videos. An optional <i>meeting.json</i> gives the "
                                           "title, date, room, a confidential flag, and an agenda (time, item, presenter, linked file). A Windows prep tool "
                                           "converts Word, PowerPoint and Excel files to PDF.", cell)],
            [P("<b>2 Load</b>", cell), P("Plug a USB drive or SD card into the iPad. Manage > <i>Choose a folder</i> (or <i>Choose files</i>) copies it on with a progress "
                                        "count and shows free space. Files with the same name are replaced, which is how an update is sent. If the drive is "
                                        "pulled mid-copy, the earlier version is kept.", cell)],
            [P("<b>3 Meeting</b>", cell), P("Library opens to today's meeting. The agenda marks <b>NOW</b> and <b>NEXT</b> by the clock. Tap an agenda line or a card. "
                                           "A <b>Continue</b> row reopens the last document at the last page. In the reader the screen is all page; "
                                           "tap the middle for contents, search, bookmark, pen, notes and display tone, and a slider to jump anywhere.", cell)],
            [P("<b>4 Wipe</b>", cell), P("Manage lists each meeting with its size. Remove one meeting, remove finished meetings, or <i>Clear everything</i>. "
                                        "Notes, handwriting, bookmarks, reading positions and cached covers go too. An optional PIN guards this screen.", cell)]]
    s += [table(rows, [64, CW - 64]), Spacer(1, 10), P("Screen map", h2),
          P("The library is the home screen. Everything else opens from it and returns to it.", small), Spacer(1, 4), ScreenMap(CW), Spacer(1, 6)]
    s += [P("Inside the reader", h2)]
    s += bullets(["<b>Turn:</b> tap the right or left edge, or swipe. Turning a page hides the tools, like a book. "
                  "A quiet footer reads <i>Pages 6-7 of 31</i>; a slider with a page preview jumps through long documents.",
                  "<b>Rotate:</b> landscape shows two facing pages with the cover alone first; portrait shows one. The page number is kept.",
                  "<b>Zoom:</b> pinch to 4 times; while zoomed, taps only show or hide the tools so a pan never turns the page."]) + [PageBreak()]

    # ===== 4 screens 1
    s += page_title("The screens", "Library and reading, from the running app")
    s.append(gallery([shot_cell("11-board-book-landscape-spread", 262, "Landscape: two facing pages (pages 2-3 of 31)"),
                      shot_cell("13-board-book-landscape-bar", 262, "Tap the middle: contents, search, pen, bookmark, notes, tone; page slider below")],
                     [CW / 2, CW / 2]))
    s.append(Spacer(1, 8))
    s.append(gallery([shot_cell("21-board-book-portrait-page", 170, "Portrait: one page, quiet footer"),
                      shot_cell("22-board-book-portrait-bar", 170, "Portrait with the tools showing"),
                      shot_cell("04-library-portrait-scrolled", 170, "A confidential board meeting with its agenda and materials")],
                     [CW / 3, CW / 3, CW / 3]))
    s.append(PageBreak())

    # ===== 5 screens 2
    s += page_title("The screens", "Long documents, media and the assistant's tools")
    s.append(gallery([shot_cell("31-long-report-after-turns", 262, "A 320-page report, two pages at a time"),
                      shot_cell("40-slide-deck-landscape", 262, "A slide deck fills the width")], [CW / 2, CW / 2]))
    s.append(Spacer(1, 8))
    s.append(gallery([shot_cell("50-photo", 262, "Photos and charts open full screen, with zoom"),
                      shot_cell("60-manage", 262, "Manage: add from USB or SD, see what is on the iPad, remove")], [CW / 2, CW / 2]))
    s.append(Spacer(1, 8))
    s.append(gallery([shot_cell("61-search", 262, "Search every document on the iPad"),
                      [P("<b>Not shown:</b> video playback and Apple Pencil handwriting. The video screen opens in the simulator, but a real video and a real Pencil "
                         "need a physical iPad to judge.", small)]], [CW / 2, CW / 2]))
    s.append(PageBreak())

    # ===== 6 features
    s += page_title("Features", "What it can do, and how sure we are")
    s += [P("Status words: <font color='#2e7d4f'><b>Seen working</b></font> means it was visible in the cloud simulator run; <font color='#2e7d4f'><b>Checked</b></font> means confirmed by reading the code. "
            "<font color='#a35f00'><b>Built</b></font> means the code exists, passes the compile and logic tests, and has not been seen working on screen.", small),
          Spacer(1, 5)]
    F = [[hdr("Area"), hdr("Feature"), hdr("Status")],
         [P("<b>Reading</b>", cell), P("Book-like paging: edge taps, swipes, tools hidden until asked", cell), status("ok")],
         ["", P("Two facing pages in landscape, one in portrait, page number kept on rotate", cell), status("ok")],
         ["", P("300+ page documents; slider with page preview; table of contents; page and chapter label", cell), status("part")],
         ["", P("Bookmarks with a ribbon; reopens at the last page; reading tone and brightness", cell), status("part")],
         [P("<b>Meetings</b>", cell), P("Folder per meeting, optional agenda file, NOW and NEXT by the clock, confidential tag, date order", cell), status("ok")],
         ["", P("Continue row; progress bars on cards; NEW tag until opened", cell), status("ok")],
         ["", P("Typed notes per meeting, saved on the iPad", cell), status("part")],
         [P("<b>Content</b>", cell), P("PDF, images (zoom, swipe), video and audio with resume", cell), status("part")],
         ["", P("Cover thumbnails for every file, built in the background", cell), status("ok")],
         [P("<b>Search</b>", cell), P("One search across the text of every PDF and the names of photos and videos; opens at the right page", cell), status("part")],
         [P("<b>Markup</b>", cell), P("Apple Pencil handwriting on any page, kept per page, a finger still turns pages", cell), status("none")],
         [P("<b>Loading</b>", cell), P("Manage screen: choose files or a folder from USB or SD, copy with progress, replace updated files safely", cell), status("part")],
         ["", P("Remove a meeting, remove finished meetings, clear everything; free-space readout (the list and sizes were seen; the removals were not run)", cell), status("part")],
         ["", P("Optional PIN for Manage, with lockout after repeated wrong tries", cell), status("part")],
         [P("<b>Security</b>", cell), P("Single App Mode lock (needs a supervised iPad), restrictions profile: no AirDrop, screenshots, app removal", cell), status("none")],
         ["", P("No network use at all (the code calls no networking APIs); files stay in the app; Finder file sharing for IT retrieval", cell), status("code")],
         [P("<b>Brand</b>", cell), P("Altar'd State wordmark and palette, consistent type, placeholder app icon pending Marketing sign-off", cell), status("ok")]]
    s += [table(F, [62, CW - 62 - 120, 120], zebra=False)]
    s += [Spacer(1, 8), P("Still to build", h2)]
    s += bullets(["Export a marked-up PDF, and mirror to a screen wirelessly (wired HDMI works; Control Center is blocked in the lock).",
                  "A final app icon and a sign-off on the logo and colors from Marketing."]) + [PageBreak()]

    # ===== 7 tech stack
    s += page_title("Tech stack", "What it is built with")
    T = [[hdr("Layer"), hdr("Choice"), hdr("Used for")],
         [P("<b>Language</b>", cell), P("Swift, Swift 5 language mode (Xcode 16.4)", cell), P("The whole app. Native, no web view, no third-party libraries.", cell)],
         [P("<b>Interface</b>", cell), P("SwiftUI, iPadOS 16 and later, iPad only", cell), P("Library, agenda, sheets, reader bar. UIKit bridges the PDF view, photo zoom, player and file picker.", cell)],
         [P("<b>PDF</b>", cell), P("PDFKit", cell), P("Page rendering, two-up spreads, outline, text search, page overlays for handwriting.", cell)],
         [P("<b>Handwriting</b>", cell), P("PencilKit", cell), P("A drawing layer per page, saved as small JSON files.", cell)],
         [P("<b>Media</b>", cell), P("AVKit, AVFoundation, ImageIO", cell), P("Video and audio, cover frames, memory-safe photo downsizing.", cell)],
         [P("<b>Security</b>", cell), P("CryptoKit, Single App Mode", cell), P("Salted PIN hash; the lock is requested from iPadOS and enforced by a supervised-device profile.", cell)],
         [P("<b>Project</b>", cell), P("XcodeGen (project.yml)", cell), P("The Xcode project is generated from one text file, so it can be built on a cloud Mac.", cell)],
         [P("<b>Tests</b>", cell), P("XCTest and XCUITest", cell), P("14 logic tests (agenda times, file naming, PIN, agenda file) plus UI tests that drive the app and take pictures.", cell)],
         [P("<b>Build</b>", cell), P("GitHub Actions, macOS runner", cell), P("Compiles, tests, screenshots and records the app in an iPad simulator on every push.", cell)],
         [P("<b>Delivery</b>", cell), P("Ad Hoc .ipa, Apple Configurator, .mobileconfig", cell), P("Signed app to four registered iPads, plus the kiosk profile. Needs an Apple Developer account.", cell)],
         [P("<b>PC tools</b>", cell), P("Python, PowerShell", cell), P("Sample deck generator; a prep tool that turns Office files into PDFs.", cell)]]
    s += [table(T, [66, 150, CW - 216]), Spacer(1, 8), P("How the code is organised", h2), ArchDiagram(CW), Spacer(1, 4)]
    s += [P("What is stored on the iPad", h2)]
    s += bullets(["<b>Documents/&lt;Meeting&gt;/</b> holds that meeting's files and its agenda file. Loose files in Documents are the Library.",
                  "<b>Notes/</b> typed notes, one text file per meeting. <b>Annotations/</b> handwriting, one small file per document.",
                  "Reading positions, bookmarks and cached covers live in the app's own settings and cache. Clearing everything removes all of it."]) + [PageBreak()]

    # ===== 8 status
    s += page_title("Status and next steps", "What is proven, what is not, and what is needed")
    s += [P("From source code to an iPad", h2), PipeDiagram(CW), Spacer(1, 4)]
    cols = [[P("<b>Proven</b>", cellb)] + bullets([
        "The Swift compiles with Apple's current Xcode.",
        "14 logic tests pass.",
        "Library, reader, spreads, portrait, long document, photo, slide deck, Manage and Search screens render and respond in an iPad simulator.",
        "A bug found this way (landscape spreads skipping every other page) was fixed and re-checked.",
        "Hosted in a private GitHub repository, rebuilt on every change."], style=ParagraphStyle("b2", parent=bullet, fontSize=8.8, leading=12)),
            [P("<b>Not yet proven</b>", cellb)] + bullets([
        "Anything on a physical iPad (speed, battery, how the tools feel under a finger).",
        "Apple Pencil handwriting staying lined up when zoomed.",
        "Loading from a real USB drive or SD card.",
        "The kiosk lock (needs a supervised iPad).",
        "Typing notes, video playback, the page slider drag, contents and in-document search."],
                                          style=ParagraphStyle("b3", parent=bullet, fontSize=8.8, leading=12))]
    ct = Table([cols], colWidths=[CW / 2 - 4, CW / 2 - 4], hAlign="LEFT")
    ct.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("BOX", (0, 0), (0, 0), 0.6, GREEN), ("BOX", (1, 0), (1, 0), 0.6, AMBER),
                            ("LEFTPADDING", (0, 0), (-1, -1), 8), ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                            ("TOPPADDING", (0, 0), (-1, -1), 7), ("BOTTOMPADDING", (0, 0), (-1, -1), 6)]))
    s += [ct, Spacer(1, 8), P("What is needed to put it on the four iPads", h2)]
    N = [[hdr("Item"), hdr("Detail"), hdr("Owner")],
         [P("Apple Developer Program account", cell), P("Paid membership; the app ID com.altardstate.briefingreader is registered under it. Renewal each year.", cell), P("To decide", cell)],
         [P("The four iPads", cell), P("Model and iPadOS version (needs iPadOS 16 or later), UDIDs, and whether each has an Apple Pencil.", cell), P("IT", cell)],
         [P("Signing files", cell), P("A signing certificate and an Ad Hoc provisioning profile, stored as private repository secrets. Then one cloud step produces the .ipa.", cell), P("Account owner", cell)],
         [P("Supervision and the lock", cell), P("Apple Configurator on a Mac supervises each iPad and installs the lock profile. Not needed for the app itself to run.", cell), P("IT", cell)],
         [P("Brand sign-off", cell), P("Logo, colors and the app icon.", cell), P("Marketing", cell)],
         [P("Data protection review", cell), P("Turn on iOS Data Protection (files unreadable while the iPad is locked) and run a formal review before real board material goes on.", cell), P("IT security", cell)]]
    s += [table(N, [128, CW - 128 - 74, 74]), Spacer(1, 8),
          P("Where the work lives: a private GitHub repository (the build runs on every change; each run keeps its screenshots and logs), and the source folder "
            "<i>iPadReader</i> on the PC, which also holds the setup guides: DEPLOYMENT, ASSISTANT-GUIDE, EXECUTIVE-QUICKSTART, FIRST-BUILD-CHECKLIST and CLOUD-BUILD.", small)]

    doc.build(s)
    print("wrote", OUT)


if __name__ == "__main__":
    build()
