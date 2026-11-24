<#
  Prep-Content.ps1  (runs on Windows, offline, no Mac needed)

  Turns a folder of meeting material into a folder ready to drag onto the iPads:
    - PDF, images, MP4/MOV/M4V video, MP3/M4A/WAV audio are copied across after checks
    - PowerPoint, Word and Excel files are converted to PDF using the Office on this PC
    - Formats the iPad cannot play are listed with how to convert them
    - Optionally writes a starter meeting.json (agenda) for each meeting folder

  Layout it expects: files directly in the source folder are the "Library"; each sub-folder is a
  meeting. The app reads one folder level, so deeper folders are flattened into their meeting folder.

  Usage:
    .\Prep-Content.ps1 -Source "C:\Meetings\Dec" -Destination "C:\Meetings\Dec-ready" -MeetingTemplates

  Nothing in -Source is changed. Office files are opened read-only.
#>
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination,
    [switch]$MeetingTemplates,
    [int]$LargeImageMB = 40,
    [int]$LargeVideoMB = 1500,
    [int]$TimeoutSec = 90      # how long one Office conversion may take before it is stopped
)

$ErrorActionPreference = 'Stop'
$Source = (Resolve-Path -LiteralPath $Source).Path
if (-not (Test-Path -LiteralPath $Destination)) { New-Item -ItemType Directory -Path $Destination | Out-Null }
$Destination = (Resolve-Path -LiteralPath $Destination).Path

$copyExt   = @{ pdf = 'PDF'; jpg = 'Image'; jpeg = 'Image'; png = 'Image'; heic = 'Image'; heif = 'Image'; gif = 'Image'; tif = 'Image'; tiff = 'Image'; webp = 'Image';
                mp4 = 'Video'; mov = 'Video'; m4v = 'Video'; mp3 = 'Audio'; m4a = 'Audio'; wav = 'Audio'; aac = 'Audio' }
$slideExt  = @('ppt', 'pptx', 'pps', 'ppsx')
$wordExt   = @('doc', 'docx', 'rtf', 'odt')
$sheetExt  = @('xls', 'xlsx', 'xlsm', 'csv')
$badVideo  = @{ mkv = 'ffmpeg -i "IN" -c:v libx264 -pix_fmt yuv420p -c:a aac "OUT.mp4"'; avi = 'ffmpeg -i "IN" -c:v libx264 -pix_fmt yuv420p -c:a aac "OUT.mp4"';
                wmv = 'ffmpeg -i "IN" -c:v libx264 -pix_fmt yuv420p -c:a aac "OUT.mp4"'; webm = 'ffmpeg -i "IN" -c:v libx264 -pix_fmt yuv420p -c:a aac "OUT.mp4"';
                flv = 'ffmpeg -i "IN" -c:v libx264 -pix_fmt yuv420p -c:a aac "OUT.mp4"' }

$ffprobe = Get-Command ffprobe -ErrorAction SilentlyContinue
$report = New-Object System.Collections.Generic.List[object]
function Add-Row($file, $result, $note) { $script:report.Add([pscustomobject]@{ File = $file; Result = $result; Note = $note }) }

# Office conversion runs in a separate PowerShell process with a time limit (office-to-pdf.ps1), so an
# Office program that stalls cannot freeze this script. On a timeout, only the Office process that the
# helper started is stopped; a Word or PowerPoint window you already had open is never touched.
$helper = Join-Path $PSScriptRoot 'office-to-pdf.ps1'
$procName = @{ word = 'WINWORD'; slides = 'POWERPNT'; sheet = 'EXCEL' }
$dead = @{ word = $false; slides = $false; sheet = $false }

function Convert-ToPdf($path, $kind, $outPdf) {
    if ($script:dead[$kind]) { throw "$($script:procName[$kind]) stalled earlier in this run, so it was not tried again" }
    $name = $script:procName[$kind]
    $before = @(Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    # Start-Process in Windows PowerShell 5.1 does not quote arguments that contain spaces, so do it here.
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $script:helper + '"'), '-Kind', $kind, '-InFile', ('"' + $path + '"'), '-OutPdf', ('"' + $outPdf + '"'))
    $child = Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -WindowStyle Hidden -PassThru
    if (-not $child.WaitForExit($script:TimeoutSec * 1000)) {
        try { Stop-Process -Id $child.Id -Force -ErrorAction SilentlyContinue } catch { }
        Get-Process -Name $name -ErrorAction SilentlyContinue | Where-Object { $before -notcontains $_.Id } | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
        $script:dead[$kind] = $true
        throw "$name did not respond within $($script:TimeoutSec) seconds and was stopped. Open that Office program once by hand, clear any first-run, sign-in or recovery prompt, then run this again"
    }
    if ($child.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $outPdf)) {
        throw "Office could not convert this file (it may be password protected or damaged)"
    }
}

if ($true) {
    $files = Get-ChildItem -LiteralPath $Source -Recurse -File
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($Source.Length).TrimStart('\')
        $parts = $rel.Split('\')
        # Top-level file stays at top level; anything inside a folder goes into that first folder.
        $folder = if ($parts.Count -gt 1) { $parts[0] } else { '' }
        $outDir = if ($folder) { Join-Path $Destination $folder } else { $Destination }
        if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
        $ext = $f.Extension.TrimStart('.').ToLower()
        $name = $f.Name
        $sizeMB = [math]::Round($f.Length / 1MB, 1)
        $deep = if ($parts.Count -gt 2) { ' (flattened out of a deeper folder)' } else { '' }
        $display = $rel

        if ($name -ieq 'meeting.json') { Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $outDir $name) -Force; Add-Row $display 'Copied' 'meeting agenda'; continue }

        if ($copyExt.ContainsKey($ext)) {
            $kind = $copyExt[$ext]; $notes = @()
            if ($kind -eq 'PDF') {
                $head = New-Object byte[] 5; $fs = [IO.File]::OpenRead($f.FullName)
                try {
                    [void]$fs.Read($head, 0, 5)
                    if ([Text.Encoding]::ASCII.GetString($head) -ne '%PDF-') { Add-Row $display 'SKIPPED' 'not a real PDF (bad header)'; continue }
                    $tailLen = [int][math]::Min($fs.Length, 16384); [void]$fs.Seek(-$tailLen, [IO.SeekOrigin]::End)
                    $tail = New-Object byte[] $tailLen; [void]$fs.Read($tail, 0, $tailLen)
                    if ([Text.Encoding]::GetEncoding(28591).GetString($tail) -match '/Encrypt') { Add-Row $display 'SKIPPED' 'password protected: the app cannot open it, remove the password first'; continue }
                } finally { $fs.Dispose() }
            }
            if ($kind -eq 'Image' -and $sizeMB -gt $LargeImageMB) { $notes += "large image ($sizeMB MB), will be downsampled on screen" }
            if ($kind -eq 'Video') {
                if ($sizeMB -gt $LargeVideoMB) { $notes += "very large video ($sizeMB MB), check free space on the iPad" }
                if ($ffprobe) {
                    $codec = (& ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=nw=1:nk=1 $f.FullName) | Select-Object -First 1
                    if ($codec -and $codec -notin @('h264', 'hevc')) { Add-Row $display 'SKIPPED' "video codec '$codec' will not play on iPad; re-encode: ffmpeg -i `"IN`" -c:v libx264 -pix_fmt yuv420p -c:a aac `"OUT.mp4`""; continue }
                } else { $notes += 'codec not checked (ffprobe not installed)' }
            }
            Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $outDir $name) -Force
            Add-Row $display 'Copied' ((@($kind) + $notes + $deep | Where-Object { $_ }) -join '; ')
            continue
        }

        $officeKind = if ($slideExt -contains $ext) { 'slides' } elseif ($wordExt -contains $ext) { 'word' } elseif ($sheetExt -contains $ext) { 'sheet' } else { $null }
        if ($officeKind) {
            $outPdf = Join-Path $outDir ([IO.Path]::GetFileNameWithoutExtension($name) + '.pdf')
            try {
                Convert-ToPdf $f.FullName $officeKind $outPdf
                $note = switch ($officeKind) { 'slides' { 'converted to PDF; animations and embedded video are lost, send videos separately' } 'sheet' { 'converted to PDF using the sheet''s print areas; check the pages' } default { 'converted to PDF' } }
                Add-Row $display 'Converted' ($note + $deep)
            } catch { Add-Row $display 'FAILED' ("could not convert (password, or Office missing): " + $_.Exception.Message.Split("`n")[0]) }
            continue
        }

        if ($badVideo.ContainsKey($ext)) { Add-Row $display 'SKIPPED' ("iPad cannot play .$ext. Convert: " + $badVideo[$ext]); continue }
        if ($ext -in @('key', 'pages', 'numbers')) { Add-Row $display 'SKIPPED' 'Apple format: export to PDF from Keynote, Pages or Numbers first'; continue }
        Add-Row $display 'SKIPPED' "not a supported type (.$ext)"
    }

    if ($MeetingTemplates) {
        foreach ($dir in Get-ChildItem -LiteralPath $Destination -Directory) {
            $mj = Join-Path $dir.FullName 'meeting.json'
            if (Test-Path -LiteralPath $mj) { continue }
            $agenda = @()
            foreach ($file in Get-ChildItem -LiteralPath $dir.FullName -File | Where-Object { $copyExt.ContainsKey($_.Extension.TrimStart('.').ToLower()) } | Sort-Object Name) {
                $agenda += [ordered]@{ time = ''; title = [IO.Path]::GetFileNameWithoutExtension($file.Name); presenter = ''; file = $file.Name }
            }
            $json = [ordered]@{ title = $dir.Name; date = (Get-Date).ToString('yyyy-MM-dd'); time = ''; location = ''; confidential = $true; note = ''; agenda = $agenda } | ConvertTo-Json -Depth 5
            [IO.File]::WriteAllText($mj, $json, (New-Object Text.UTF8Encoding($false)))
            Add-Row ($dir.Name + '\meeting.json') 'Created' 'starter agenda: fill in date, times, presenters, delete lines you do not want'
        }
    }
}

$report | Format-Table -AutoSize -Wrap
$counts = $report | Group-Object Result | ForEach-Object { "$($_.Count) $($_.Name.ToLower())" }
$totalMB = [math]::Round((Get-ChildItem -LiteralPath $Destination -Recurse -File | Measure-Object Length -Sum).Sum / 1MB, 1)
Write-Host ("Result: " + ($counts -join ', ') + ". Ready folder holds $totalMB MB (each iPad needs that much free space, plus room for covers).")
Write-Host "Drag the contents of '$Destination' into Finder > iPad > Files > Briefings."
