# skill_apply_style.ps1
# Apply Padda Demo & Sandbox style to an Emscripten-generated HTML file.
# Usage: powershell -ExecutionPolicy Bypass -File skill_apply_style.ps1 -FilePath "path\to\file.html" -Title "Demo Title"
#
# Parameters:
#   -FilePath    Path to the Emscripten-generated HTML file
#   -Title       The title text to display in the header (e.g. "Demo 01 — First Demo")
#   -BackHref    (optional) Relative path to index.html, default "../../index.html"
#   -BackLabel   (optional) Back button label, default "← 返回首页"

param(
    [Parameter(Mandatory=$true)] [string]$FilePath,
    [Parameter(Mandatory=$true)] [string]$Title,
    [string]$BackHref = "../../index.html",
    [string]$BackLabel = "&#8592; 返回首页"
)

if (-not (Test-Path -LiteralPath $FilePath)) {
    Write-Error "File not found: $FilePath"
    exit 1
}

Write-Output "Applying style to: $FilePath"
Write-Output "Title: $Title"

$content = [System.IO.File]::ReadAllText($FilePath)
$original = $content

# ============================================================
# 1. CSS modifications
# ============================================================

# 1a. Body: add dark background and white text
$content = $content -replace 'body\{font-family:arial;margin:0;padding:none\}',
    'body{font-family:arial;margin:0;padding:none;background-color:#111111;color:#fff}'

# 1a2. Hide scrollbar on textarea
$content = $content.Replace('</style>', '#output::-webkit-scrollbar{display:none}#output{-ms-overflow-style:none;scrollbar-width:none}</style>')

# 1b. div.emscripten: add background color
$content = $content -replace 'div\.emscripten\{text-align:center\}',
    'div.emscripten{text-align:center;background-color:#111111}'

# 1c. div.emscripten_border: change border color, add background
$content = $content -replace 'div\.emscripten_border\{border:1px solid #000\}',
    'div.emscripten_border{border:1px solid #333;background-color:#111111}'

# 1d. #status: reduce margin-top from 30px to 10px
$content = $content -replace '#status\{display:inline-block;vertical-align:top;margin-top:30px',
    '#status{display:inline-block;vertical-align:top;margin-top:10px'

# 1e. #output: full restyle (15px margin, #444 border, #111111 bg, auto height)
$content = $content -replace '#output\{width:100%;height:200px;margin:0 auto;margin-top:10px;border-left:0;border-right:0px;padding-left:0;padding-right:0;display:block;background-color:#000;color:#fff;font-family:''Lucida Console'',Monaco,monospace;outline:0\}',
    '#output{width:100%;height:auto;margin:0;border:1px solid #444;border-top:0;padding-left:15px;padding-right:0;display:block;background-color:#111111;color:#fff;font-family:Lucida Console,Monaco,monospace;outline:0}'

# ============================================================
# 2. Body HTML modifications
# ============================================================

# 2a. Remove emscripten logo link
$content = $content -replace '<a href=http://emscripten\.org><img id=emscripten_logo src=data:image/png;base64,[^>]*></a>', ''

# 2b. Remove controls span
$content = $content -replace '<span id=controls>.*?</span></span>', ''

# ============================================================
# 3. Insert custom header after <body>
# ============================================================

$header = @"
<div style="background:#111;padding:6px 10px 4px"><div style="text-align:center;font-size:20px;font-weight:bold;color:#ccc;font-family:Arial,sans-serif;padding-top:10px;padding-bottom:4px">$Title</div><div style="display:flex;justify-content:center;margin-top:10px"><a href="$BackHref" style="background:#333;color:#aaa;padding:4px 12px;text-decoration:none;font-family:Arial,sans-serif;font-size:13px">$BackLabel</a></div></div>
"@

$content = $content -replace '(<body>)', ('$1' + $header)

# ============================================================
# 4. Remove rows attribute and add auto-resize JS
# ============================================================

# 4a. Remove any rows attribute from textarea
$content = $content -replace ' rows=\d+', ''

# 4b. Add auto-resize script before </body>
$autoResizeJS = @'
<script>window.addEventListener("DOMContentLoaded",()=>{window.addEventListener("resize",function e(){var t=document.getElementById("output");if(!t)return;var n=t.getBoundingClientRect().top,a=window.innerHeight-n-25;a>50&&(t.style.height=a+"px")}),setTimeout(()=>window.dispatchEvent(new Event("resize")),500)})</script>
'@
$content = $content.Replace('</body>', $autoResizeJS + '</body>')

# ============================================================
# 5. Save
# ============================================================

if ($content -ne $original) {
    [System.IO.File]::WriteAllText($FilePath, $content)
    Write-Output "Done. Style applied successfully."
} else {
    Write-Output "No changes made (file may already be styled)."
}
