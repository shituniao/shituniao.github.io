# auto_sync.ps1
# Auto-sync all demo pages: update titles, update index timestamp, commit to git.
# Usage: powershell -ExecutionPolicy Bypass -File auto_sync.ps1

$ErrorActionPreference = "Stop"

Write-Output "=== Auto Sync Script ==="

# ============================================================
# 1. Scan all demo folders under apps/
# ============================================================
$appsDir = Join-Path $PWD "apps"
$folders = Get-ChildItem -LiteralPath $appsDir -Directory | Sort-Object Name

if ($folders.Count -eq 0) {
    Write-Output "No app folders found."
    exit 0
}

Write-Output "Found $($folders.Count) app folders."

# ============================================================
# 2. Helper: convert CamelCase to spaced words
# ============================================================
function Convert-CamelToTitle($name) {
    # Insert space between lowercase->uppercase and uppercase->lowercase transitions
    $result = $name -creplace '([a-z])([A-Z])', '$1 $2'
    $result = $result -creplace '([A-Z])([A-Z][a-z])', '$1 $2'
    return $result
}

# ============================================================
# 3. Generate title from folder name
# ============================================================
function Get-TitleFromFolder($folderName) {
    if ($folderName -match '^(demo|sandbox)(\d+)_(.+)$') {
        $type = $Matches[1]
        $num = $Matches[2]
        $name = $Matches[3]
        $capType = $type.Substring(0,1).ToUpper() + $type.Substring(1)
        $spacedName = Convert-CamelToTitle $name
        return "$capType $num $([char]0x2014) $spacedName"
    }
    return $folderName
}

# ============================================================
# 4. Update each HTML file's title
# ============================================================
$updatedCount = 0

foreach ($folder in $folders) {
    $folderName = $folder.Name
    $htmlFiles = Get-ChildItem -LiteralPath $folder.FullName -Filter "*.html" -File
    if ($htmlFiles.Count -eq 0) {
        Write-Output "SKIP: $folderName (no HTML file)"
        continue
    }

    $htmlPath = $htmlFiles[0].FullName
    $title = Get-TitleFromFolder $folderName
    $content = [System.IO.File]::ReadAllText($htmlPath)

    $fixed = $false
    if ($content -match 'TITLE_PLACEHOLDER') {
        $content = $content.Replace('TITLE_PLACEHOLDER', $title)
        $fixed = $true
    } else {
        # Try to match the title div content (with or without style quotes)
        if ($content -match 'padding-bottom:4px[^>]*>([^<]+)</div>') {
            $oldTitle = $Matches[1]
            if ($oldTitle -ne $title) {
                $oldTitleEscaped = [regex]::Escape($oldTitle)
                $content = $content -replace $oldTitleEscaped, $title
                $fixed = $true
            }
        }
    }

    if ($fixed) {
        [System.IO.File]::WriteAllText($htmlPath, $content)
        Write-Output "OK: $folderName -> $title"
        $updatedCount++
    } else {
        Write-Output "SKIP: $folderName (title unchanged or not found)"
    }
}

# ============================================================
# 5. Update index.html timestamp (Beijing time UTC+8)
# ============================================================
$indexPath = Join-Path $PWD "index.html"
if (Test-Path -LiteralPath $indexPath) {
    $indexContent = [System.IO.File]::ReadAllText($indexPath)
    $beijingTime = (Get-Date).ToUniversalTime().AddHours(8)
    $timestampStr = $beijingTime.ToString("yyyy-MM-dd HH:mm")
    $newLine = "$([char]0x6700)$([char]0x540E)$([char]0x66F4)$([char]0x65B0)$([char]0xFF1A)$timestampStr ($([char]0x5317)$([char]0x4EAC)$([char]0x65F6)$([char]0x95F4))"

    # Search for the timestamp pattern: digits and surrounding context
    if ($indexContent -match '(\d{4}-\d{2}-\d{2} \d{2}:\d{2})') {
        $oldTimestamp = $Matches[1]
        $oldLineStart = $indexContent.LastIndexOf($([char]0x6700), $indexContent.IndexOf($oldTimestamp))
        if ($oldLineStart -ge 0) {
            $oldLineEnd = $indexContent.IndexOf('<', $oldLineStart)
            if ($oldLineEnd -lt 0) { $oldLineEnd = $indexContent.Length }
            $oldLine = $indexContent.Substring($oldLineStart, $oldLineEnd - $oldLineStart)

            if ($oldTimestamp -ne $timestampStr) {
                $indexContent = $indexContent.Replace($oldLine, $newLine)
                [System.IO.File]::WriteAllText($indexPath, $indexContent)
                Write-Output "Index timestamp updated: $timestampStr"
            } else {
                Write-Output "Index timestamp unchanged: $timestampStr"
            }
        } else {
            Write-Output "WARN: timestamp context not found"
        }
    } else {
        Write-Output "WARN: timestamp pattern not found in index.html"
    }
} else {
    Write-Output "WARN: index.html not found"
}

# ============================================================
# 6. Git commit
# ============================================================
Write-Output ""
Write-Output "=== Git Commit ==="
git add -A
$beijingTime = (Get-Date).ToUniversalTime().AddHours(8)
$commitTime = $beijingTime.ToString("yyyy-MM-dd HH:mm")
git commit -m "auto sync: $commitTime"
Write-Output "Commit done."

Write-Output ""
Write-Output "=== Sync Complete ==="
Write-Output "Updated $updatedCount app title(s)."
