@echo off
rem Opens the iPad mockup of Briefing Reader in your browser, using the PDFs in SampleDecks.
rem Needs Python. Close this window to stop the local server. Only this PC can reach it.
cd /d "%~dp0..\.."
start "" http://127.0.0.1:8765/tools/ipad-sim/index.html
where py >nul 2>&1 && (py -m http.server 8765 --bind 127.0.0.1) || (python -m http.server 8765 --bind 127.0.0.1)
