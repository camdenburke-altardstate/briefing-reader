<#
  office-to-pdf.ps1  (helper for Prep-Content.ps1, not meant to be run by hand)

  Converts ONE Office file to PDF using the Office on this PC, then exits. Prep-Content.ps1 runs this
  in its own process with a time limit, so an Office program that stalls cannot freeze the whole prep.
#>
param(
    [Parameter(Mandatory = $true)][ValidateSet('slides', 'word', 'sheet')][string]$Kind,
    [Parameter(Mandatory = $true)][string]$InFile,
    [Parameter(Mandatory = $true)][string]$OutPdf
)
$ErrorActionPreference = 'Stop'

switch ($Kind) {
    'word' {
        $app = New-Object -ComObject Word.Application
        $app.Visible = $false; $app.DisplayAlerts = 0
        $doc = $app.Documents.Open($InFile, $false, $true)          # no conversion prompt, read-only
        try { $doc.ExportAsFixedFormat($OutPdf, 17) } finally { $doc.Close($false); if ($app.Documents.Count -eq 0) { $app.Quit() } }
    }
    'slides' {
        $app = New-Object -ComObject PowerPoint.Application
        $doc = $app.Presentations.Open($InFile, -1, 0, 0)           # read-only, no window
        try { $doc.SaveAs($OutPdf, 32) } finally { $doc.Close(); if ($app.Presentations.Count -eq 0) { $app.Quit() } }
    }
    'sheet' {
        $app = New-Object -ComObject Excel.Application
        $app.Visible = $false; $app.DisplayAlerts = $false
        $doc = $app.Workbooks.Open($InFile, 0, $true)
        try { $doc.ExportAsFixedFormat(0, $OutPdf) } finally { $doc.Close($false); if ($app.Workbooks.Count -eq 0) { $app.Quit() } }
    }
}
