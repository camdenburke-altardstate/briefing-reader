#!/usr/bin/env python3
"""Makes a copy of SampleDecks look "live" for the automated screenshots.

The sample meetings carry the dates they were made on. This moves the Weekly Leadership Sync to today
and shifts its agenda times so the second item is "NOW" and the third is "NEXT" at the moment the
screenshots are taken, and pushes the Board Meeting 19 days out. Standard library only.

    python3 tools/prepare_screenshot_content.py /tmp/BriefingSeed
"""
import datetime
import json
import re
import sys
from pathlib import Path


def to_minutes(text):
    m = re.match(r"\s*(\d{1,2}):(\d{2})\s*([AaPp][Mm])?\s*$", text or "")
    if not m:
        return None
    hour, minute, ap = int(m.group(1)), int(m.group(2)), (m.group(3) or "").lower()
    if ap == "pm" and hour < 12:
        hour += 12
    if ap == "am" and hour == 12:
        hour = 0
    return hour * 60 + minute


def to_text(minutes):
    minutes = max(0, min(minutes, 23 * 60 + 59))
    hour, minute = divmod(minutes, 60)
    ap = "AM" if hour < 12 else "PM"
    return f"{(hour % 12) or 12}:{minute:02d} {ap}"


def main(root):
    now = datetime.datetime.now()
    today = now.date()
    now_minutes = now.hour * 60 + now.minute

    for meeting in sorted(Path(root).glob("*/meeting.json")):
        data = json.loads(meeting.read_text(encoding="utf-8"))
        title = data.get("title", "")
        if "Weekly" in title:
            data["date"] = today.isoformat()
            agenda = data.get("agenda", [])
            times = [to_minutes(item.get("time")) for item in agenda]
            if len(agenda) >= 2 and times[1] is not None:
                shift = (now_minutes - 10) - times[1]      # item 2 started ten minutes ago
                for item, minutes in zip(agenda, times):
                    if minutes is not None:
                        item["time"] = to_text(minutes + shift)
                if times[0] is not None:
                    data["time"] = to_text(times[0] + shift)
        elif "Board" in title:
            data["date"] = (today + datetime.timedelta(days=19)).isoformat()
        meeting.write_text(json.dumps(data, indent=2), encoding="utf-8")
        print("prepared", meeting.parent.name, data.get("date"))


if __name__ == "__main__":
    main(sys.argv[1])
