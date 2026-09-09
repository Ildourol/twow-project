<#
.SYNOPSIS
    Exports docs/COMMAND_REFERENCE.md to HTML and high-quality PDF.
.DESCRIPTION
    Uses Microsoft Edge headless to render COMMAND_REFERENCE.md into a beautifully styled,
    printable PDF with GitHub-inspired styling, proper UTF-8 box-drawing rendering, and table formatting.
#>
[CmdletBinding()]
param()

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
$DocsDir = Join-Path $ProjectRoot "docs"
$mdPath = Join-Path $DocsDir "COMMAND_REFERENCE.md"
$htmlPath = Join-Path $DocsDir "COMMAND_REFERENCE.html"
$pdfPath = Join-Path $DocsDir "COMMAND_REFERENCE.pdf"
$edgeExe = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

if (-not (Test-Path $edgeExe)) {
    Write-Error "Microsoft Edge not found at: $edgeExe"
    return
}

function Escape-Html($s) {
    return $s.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;")
}

function Process-Inline($line) {
    $line = [regex]::Replace($line, '\*\*(.+?)\*\*', '<strong>$1</strong>')
    $line = [regex]::Replace($line, '\*(.+?)\*', '<em>$1</em>')
    $line = [regex]::Replace($line, '`([^`]+)`', '<code>$1</code>')
    $line = [regex]::Replace($line, '\[([^\]]+)\]\(([^)]+)\)', '<a href="$2">$1</a>')
    return $line
}

$lines = [System.IO.File]::ReadAllLines($mdPath, [System.Text.Encoding]::UTF8)
$htmlBody = [System.Text.StringBuilder]::new()

$inCodeBlock = $false
$codeLang = ""
$codeBuffer = [System.Text.StringBuilder]::new()
$inTable = $false
$inList = $false
$inCallout = $false
$calloutType = ""
$calloutBuffer = [System.Text.StringBuilder]::new()

foreach ($line in $lines) {
    if ($line -match '^```(\w*)') {
        if ($inCodeBlock) {
            $inCodeBlock = $false
            $escaped = Escape-Html ($codeBuffer.ToString().TrimEnd())
            [void]$htmlBody.AppendLine("<pre><code class=""language-$codeLang"">$escaped</code></pre>")
            [void]$codeBuffer.Clear()
        } else {
            if ($inTable) { [void]$htmlBody.AppendLine("</tbody></table>"); $inTable = $false }
            if ($inList) { [void]$htmlBody.AppendLine("</ul>"); $inList = $false }
            if ($inCallout) {
                $cContent = $calloutBuffer.ToString().Trim()
                [void]$htmlBody.AppendLine("<div class=""alert alert-$calloutType""><span class=""alert-badge"">$calloutType</span><br>$cContent</div>")
                [void]$calloutBuffer.Clear()
                $inCallout = $false
            }
            $inCodeBlock = $true
            $codeLang = $Matches[1]
        }
        continue
    }

    if ($inCodeBlock) {
        [void]$codeBuffer.AppendLine($line)
        continue
    }

    if ($line -match '^>\s*\[!(TIP|NOTE|IMPORTANT|WARNING|CAUTION)\]') {
        if ($inTable) { [void]$htmlBody.AppendLine("</tbody></table>"); $inTable = $false }
        if ($inList) { [void]$htmlBody.AppendLine("</ul>"); $inList = $false }
        $inCallout = $true
        $calloutType = $Matches[1].ToLower()
        continue
    }

    if ($inCallout) {
        if ($line -match '^>\s?(.*)') {
            [void]$calloutBuffer.AppendLine((Process-Inline (Escape-Html $Matches[1])))
            continue
        } else {
            $inCallout = $false
            $cContent = $calloutBuffer.ToString().Trim()
            [void]$htmlBody.AppendLine("<div class=""alert alert-$calloutType""><span class=""alert-badge"">$calloutType</span><br>$cContent</div>")
            [void]$calloutBuffer.Clear()
        }
    }

    if ($line -match '^\|(.+)\|$') {
        $cells = ($line.Trim().Trim('|') -split '\|') | ForEach-Object { $_.Trim() }
        if ($cells[0] -match '^:?-+:?$') { continue }

        if (-not $inTable) {
            if ($inList) { [void]$htmlBody.AppendLine("</ul>"); $inList = $false }
            $inTable = $true
            [void]$htmlBody.AppendLine("<table class=""table""><thead><tr>")
            foreach ($c in $cells) {
                $processedCell = Process-Inline (Escape-Html $c)
                [void]$htmlBody.AppendLine("<th>$processedCell</th>")
            }
            [void]$htmlBody.AppendLine("</tr></thead><tbody>")
        } else {
            [void]$htmlBody.AppendLine("<tr>")
            foreach ($c in $cells) {
                $processedCell = Process-Inline (Escape-Html $c)
                [void]$htmlBody.AppendLine("<td>$processedCell</td>")
            }
            [void]$htmlBody.AppendLine("</tr>")
        }
        continue
    } else {
        if ($inTable) {
            [void]$htmlBody.AppendLine("</tbody></table>")
            $inTable = $false
        }
    }

    if ($line -match '^(#{1,6})\s+(.*)') {
        if ($inList) { [void]$htmlBody.AppendLine("</ul>"); $inList = $false }
        $hLevel = $Matches[1].Length
        $hText = Process-Inline (Escape-Html $Matches[2])
        [void]$htmlBody.AppendLine("<h$hLevel>$hText</h$hLevel>")
        continue
    }

    if ($line -match '^-{3,}$') {
        if ($inList) { [void]$htmlBody.AppendLine("</ul>"); $inList = $false }
        [void]$htmlBody.AppendLine("<hr>")
        continue
    }

    if ($line -match '^\s*[\*\-]\s+(.*)') {
        if (-not $inList) {
            $inList = $true
            [void]$htmlBody.AppendLine("<ul>")
        }
        $liText = Process-Inline (Escape-Html $Matches[1])
        [void]$htmlBody.AppendLine("<li>$liText</li>")
        continue
    } else {
        if ($inList) {
            [void]$htmlBody.AppendLine("</ul>")
            $inList = $false
        }
    }

    if ([string]::IsNullOrWhiteSpace($line)) { continue }

    $pText = Process-Inline (Escape-Html $line)
    [void]$htmlBody.AppendLine("<p>$pText</p>")
}

if ($inTable) { [void]$htmlBody.AppendLine("</tbody></table>") }
if ($inList) { [void]$htmlBody.AppendLine("</ul>") }
if ($inCallout) {
    $cContent = $calloutBuffer.ToString().Trim()
    [void]$htmlBody.AppendLine("<div class=""alert alert-$calloutType""><span class=""alert-badge"">$calloutType</span><br>$cContent</div>")
}

$fullHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Tortoise-WoW Extended - Command Reference</title>
<style>
    @page {
        size: A4 portrait;
        margin: 12mm 12mm 12mm 12mm;
    }
    body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
        font-size: 10pt;
        line-height: 1.45;
        color: #24292f;
        background-color: #ffffff;
        margin: 0;
        padding: 5px;
    }
    h1 {
        font-size: 18pt;
        border-bottom: 2px solid #0969da;
        padding-bottom: 0.25em;
        margin-top: 0;
        margin-bottom: 12px;
        color: #0969da;
    }
    h2 {
        font-size: 13pt;
        border-bottom: 1px solid #d0d7de;
        padding-bottom: 0.25em;
        margin-top: 20px;
        margin-bottom: 10px;
        color: #1f2328;
    }
    h3 {
        font-size: 11pt;
        margin-top: 14px;
        margin-bottom: 6px;
        color: #24292f;
    }
    p, ul {
        margin-top: 0;
        margin-bottom: 8px;
    }
    code {
        font-family: "Consolas", "Courier New", monospace;
        font-size: 8.5pt;
        background-color: #f6f8fa;
        padding: 0.15em 0.35em;
        border-radius: 4px;
        color: #cf222e;
    }
    pre {
        background-color: #f6f8fa;
        border: 1px solid #d0d7de;
        border-radius: 6px;
        padding: 10px;
        overflow-x: auto;
        font-family: "Consolas", "Courier New", monospace;
        font-size: 8pt;
        line-height: 1.35;
        margin-top: 6px;
        margin-bottom: 10px;
        page-break-inside: avoid;
    }
    pre code {
        background-color: transparent;
        padding: 0;
        color: #1f2328;
    }
    table {
        border-collapse: collapse;
        width: 100%;
        margin-top: 10px;
        margin-bottom: 14px;
        font-size: 8pt;
        page-break-inside: avoid;
    }
    th, td {
        border: 1px solid #d0d7de;
        padding: 5px 7px;
        text-align: left;
        vertical-align: top;
    }
    th {
        background-color: #f6f8fa;
        font-weight: 600;
        color: #24292f;
    }
    tr:nth-child(even) {
        background-color: #fbfbfb;
    }
    hr {
        border: 0;
        height: 1px;
        background-color: #d0d7de;
        margin: 16px 0;
    }
    .alert {
        border-left: 4px solid #0969da;
        background-color: #ddf4ff;
        padding: 8px 12px;
        margin: 10px 0;
        border-radius: 0 6px 6px 0;
        font-size: 9.5pt;
    }
    .alert-tip {
        border-left-color: #1a7f37;
        background-color: #dafbe1;
    }
    .alert-badge {
        font-weight: bold;
        text-transform: uppercase;
        font-size: 7.5pt;
        letter-spacing: 0.5px;
    }
    a {
        color: #0969da;
        text-decoration: none;
    }
</style>
</head>
<body>
$($htmlBody.ToString())
</body>
</html>
"@

[System.IO.File]::WriteAllText($htmlPath, $fullHtml, [System.Text.Encoding]::UTF8)

# Print to PDF using headless Edge
$pdfArg = "--print-to-pdf=`"$pdfPath`""
$process = Start-Process -FilePath $edgeExe -ArgumentList "--headless", "--disable-gpu", "--no-pdf-header-footer", "--run-all-compositor-stages-before-draw", $pdfArg, "`"$htmlPath`"" -PassThru -Wait

if (Test-Path $pdfPath) {
    $size = (Get-Item $pdfPath).Length
    Write-Host "[SUCCESS] Exported COMMAND_REFERENCE.pdf ($size bytes)" -ForegroundColor Green
    Write-Host "Location: $pdfPath" -ForegroundColor Cyan
} else {
    Write-Error "PDF generation failed."
}
