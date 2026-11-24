<#
  Check-Decks.ps1  (runs on Windows, no Mac needed)

  Looks over a folder of PDFs before they are loaded onto the iPads and flags the
  things that cause trouble: password protection, very large files, files that are
  not really PDFs, and file names that will look odd as titles in the library grid.

  Usage:  .\Check-Decks.ps1 -Path "C:\path\to\decks"
#>
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [int]$LargeMB = 250
)

$files = Get-ChildItem -LiteralPath $Path -Filter *.pdf -File
if (-not $files) { Write-Host "No PDF files found in $Path"; exit 1 }

$rows = foreach ($f in $files) {
    $notes = @()
    $sizeMB = [math]::Round($f.Length / 1MB, 1)

    $fs = [System.IO.File]::OpenRead($f.FullName)
    try {
        $head = New-Object byte[] 5
        [void]$fs.Read($head, 0, 5)
        if ([System.Text.Encoding]::ASCII.GetString($head) -ne '%PDF-') { $notes += 'NOT A PDF (bad header)' }

        # The trailer / cross-reference dictionary sits at the end of the file and names /Encrypt.
        $tailLen = [int][math]::Min($fs.Length, 16384)
        [void]$fs.Seek(-$tailLen, [System.IO.SeekOrigin]::End)
        $tail = New-Object byte[] $tailLen
        [void]$fs.Read($tail, 0, $tailLen)
        if ([System.Text.Encoding]::GetEncoding(28591).GetString($tail) -match '/Encrypt') {
            $notes += 'ENCRYPTED: the app cannot open it, remove the password first'
        }
    } finally { $fs.Dispose() }

    if ($sizeMB -gt $LargeMB) { $notes += "large ($sizeMB MB): test scrolling on a real iPad" }
    if ($f.BaseName -match '[_]{2,}|\s{2,}|^\s|\s$') { $notes += 'file name has odd spacing or underscores (it is shown as the title)' }
    if ($f.BaseName.Length -gt 60) { $notes += 'long title (will be cut to two lines)' }

    [pscustomobject]@{
        File   = $f.Name
        SizeMB = $sizeMB
        Status = if ($notes.Count) { ($notes -join '; ') } else { 'ok' }
    }
}

$rows | Format-Table -AutoSize -Wrap
$total = [math]::Round(($files | Measure-Object Length -Sum).Sum / 1MB, 1)
Write-Host "$($files.Count) files, $total MB total (each iPad needs that much free space, plus room for covers)."
