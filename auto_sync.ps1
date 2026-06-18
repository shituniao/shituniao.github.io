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
    # Insert space before each uppercase letter (except first char)
    $result = $name -creplace '([A-Z])', ' $1'
    $result = $result.TrimStart()
    # Remove leading space before the first word
    return $result
}

# ============================================================
# 3. Generate title from folder name
# ============================================================
# Format: {type}{number}_{CamelCaseName}
# Output: {Capitalized Type} {number} — {Spaced Name}
function Get-TitleFromFolder($folderName) {
    if ($folderName -match '^(demo|sandbox)(\d+)_(.+)$') {
        $type = $Matches[1]
        $num = $Matches[2]
        $name = $Matches[3]

        $capType = $type.Substring(0,1).ToUpper() + $type.Substring(1)
        $spacedName = Convert-CamelToTitle $name

        return "$capType $num — $spacedName"
    }
    # Fallback: use folder name as-is
    return $folderName
}

# ============================================================
# 4. Update each HTML file's title
# ============================================================
$updatedCount = 0

foreach ($folder in $folders) {
    $folderName = $folder.Name
    # Find HTML file inside folder
    $htmlFiles = Get-ChildItem -LiteralPath $folder.FullName -Filter "*.html" -File
    if ($htmlFiles.Count -eq 0) {
        Write-Output "SKIP: $folderName (no HTML file)"
        continue
    }

    $htmlPath = $htmlFiles[0].FullName
    $title = Get-TitleFromFolder $folderName
    $content = [System.IO.File]::ReadAllText($htmlPath)

    # Replace TITLE_PLACEHOLDER or match existing title div content
    if ($content -match 'TITLE_PLACEHOLDER') {
        $content = $content.Replace('TITLE_PLACEHOLDER', $title)
        [System.IO.File]::WriteAllText($htmlPath, $content)
        Write-Output "OK: $folderName -> $title (placeholder replaced)"
        $updatedCount++
    } elseif ($content -match 'padding-bottom:4px">([^<]+)</div>') {
        $oldTitle = $Matches[1]
        if ($oldTitle -ne $title) {
            $content = $content -replace ([regex]::Escape($oldTitle)), $title
            [System.IO.File]::WriteAllText($htmlPath, $content)
            Write-Output "OK: $folderName -> $title (was: $oldTitle)"
            $updatedCount++
        } else {
            Write-Output "SKIP: $folderName (title unchanged)"
        }
    } else {
        Write-Output "WARN: $folderName (no title div found)"
    }
}

# ============================================================
# 5. Update index.html timestamp (Beijing time UTC+8)
# ============================================================
$indexPath = Join-Path $PWD "index.html"
if (Test-Path -LiteralPath $indexPath) {
    $indexContent = [System.IO.File]::ReadAllText($indexPath)
    $beijingTime = (Get-Date).ToUniversalTime().AddHours(8)
    $timestamp = $beijingTime.ToString("yyyy-MM-dd HH:mm")
    $newLine = "最后更新：$timestamp (北京时间)"

    if ($indexContent -match '最后更新：[^<]+') {
        $oldLine = $Matches[0]
        if ($oldLine -ne $newLine) {
            $indexContent = $indexContent.Replace($oldLine, $newLine)
            [System.IO.File]::WriteAllText($indexPath, $indexContent)
            Write-Output "Index timestamp updated: $timestamp"
        } else {
            Write-Output "Index timestamp unchanged: $timestamp"
        }
    } else {
        Write-Output "WARN: timestamp line not found in index.html"
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
$timestamp = $beijingTime.ToString("yyyy-MM-dd HH:mm")
git commit -m "auto sync: $timestamp"
Write-Output "Commit done."

Write-Output ""
Write-Output "=== Sync Complete ==="
Write-Output "Updated $updatedCount app title(s)."
