# FileCopyWithTimestamp.ps1 - English version
param(
    [string]$SourceDir = "C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\DesktopSpotlight\Assets\Images",
    [string]$TargetDir = "C:\mydata\picture\Assets",
    [string[]]$Extensions = @(".jpg", ".png"),
    [switch]$ResetHashDB,
    [switch]$ForceCopy,
    [switch]$NoTimestamp
)

$hashFilePath = "$TargetDir\file_hashes.json"
$integrityLogPath = "$TargetDir\integrity_check.log"

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$timestamp $Message" -ForegroundColor $Color
}

Write-Log "========== File Copy Task (Hash Deduplication) ==========" -Color Cyan

if ($ResetHashDB -and (Test-Path $hashFilePath)) {
    Write-Log "[Action] Reset hash database" -Color Yellow
    Remove-Item $hashFilePath -Force
    if (Test-Path $integrityLogPath) { Remove-Item $integrityLogPath -Force }
}

if (-not (Test-Path $SourceDir)) {
    Write-Log "[ERROR] Source directory not found: $SourceDir" -Color Red
    exit 1
}

if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    Write-Log "[Created] Target directory: $TargetDir" -Color Green
}

$hashDatabase = @{}

function Load-HashDatabase {
    if (Test-Path $hashFilePath) {
        try {
            $json = Get-Content $hashFilePath -Raw -Encoding UTF8
            if ($json) {
                $obj = $json | ConvertFrom-Json
                $hashDatabase = @{}
                $obj.PSObject.Properties | ForEach-Object { $hashDatabase[$_.Name] = $_.Value }
                Write-Log "[Loaded] Hash database: $($hashDatabase.Count) records" -Color Gray
            }
        } catch {
            Write-Log "[WARNING] Load failed: $($_.Exception.Message)" -Color Yellow
        }
    } else {
        Write-Log "[INFO] Hash database not found, will create new" -Color Gray
    }
    return $hashDatabase
}

function Save-HashDatabase {
    try {
        $json = $hashDatabase | ConvertTo-Json -Depth 10
        $json | Out-File $hashFilePath -Encoding UTF8
        Write-Log "[Saved] Hash database: $($hashDatabase.Count) records" -Color Gray
    } catch {
        Write-Log "[ERROR] Save failed: $($_.Exception.Message)" -Color Red
    }
}

function Get-FileHashValue {
    param([string]$FilePath)
    try {
        return (Get-FileHash -Path $FilePath -Algorithm MD5).Hash
    } catch {
        return $null
    }
}

function Verify-ExistingFiles {
    Write-Log "`n[Verify] Checking target directory file integrity..." -Color Cyan
    $verified = 0
    $failed = 0
    
    $targetFiles = Get-ChildItem -Path $TargetDir -File | Where-Object { $_.Extension -in $Extensions }
    
    foreach ($file in $targetFiles) {
        $currentHash = Get-FileHashValue -FilePath $file.FullName
        if ($currentHash) {
            $found = $false
            foreach ($hash in $hashDatabase.Keys) {
                if ($hashDatabase[$hash] -eq $file.Name) {
                    if ($hash -ne $currentHash) {
                        Write-Log "  [!] File corrupted: $($file.Name)" -Color Red
                        $failed++
                    } else {
                        $verified++
                    }
                    $found = $true
                    break
                }
            }
            if (-not $found) {
                Write-Log "  [?] File not in database: $($file.Name)" -Color Yellow
                $hashDatabase[$currentHash] = $file.Name
            }
        }
    }
    Write-Log "[Result] Verification complete: $verified ok, $failed damaged" -Color Gray
    if ($failed -gt 0) {
        $failed | Out-File $integrityLogPath -Encoding UTF8
        Write-Log "[Log] Damaged file list saved to: $integrityLogPath" -Color Yellow
    }
}

$hashDatabase = Load-HashDatabase

Write-Log "`nSource: $SourceDir" -Color Gray
Write-Log "Target: $TargetDir" -Color Gray
Write-Log ""

$stats = @{ Total = 0; Copied = 0; SkippedByHash = 0; SkippedByExist = 0; Failed = 0 }

$allFiles = @()
foreach ($ext in $Extensions) {
    $allFiles += Get-ChildItem -Path $SourceDir -Filter "*$ext" -Recurse -File -ErrorAction SilentlyContinue
}
$stats.Total = $allFiles.Count

Write-Log "Found $($stats.Total) files to process" -Color Yellow

foreach ($file in $allFiles) {
    Write-Log "`nProcessing: $($file.Name)" -Color Gray
    
    $fileHash = Get-FileHashValue -FilePath $file.FullName
    if (-not $fileHash) {
        $stats.Failed++
        continue
    }
    
    if (-not $ForceCopy -and $hashDatabase.ContainsKey($fileHash)) {
        Write-Log "  [SKIP] Duplicate content (exists: $($hashDatabase[$fileHash]))" -Color Gray
        $stats.SkippedByHash++
        continue
    }
    
    if ($NoTimestamp) {
        $newFileName = $file.Name
    } else {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmssfff"
        $newFileName = "${timestamp}_$($file.Name)"
    }
    $newFilePath = Join-Path $TargetDir $newFileName
    
    if (Test-Path $newFilePath) {
        Write-Log "  [SKIP] File already exists: $newFileName" -Color Gray
        $stats.SkippedByExist++
        continue
    }
    
    try {
        Copy-Item -Path $file.FullName -Destination $newFilePath -ErrorAction Stop
        
        $copiedHash = Get-FileHashValue -FilePath $newFilePath
        if ($copiedHash -eq $fileHash) {
            Write-Log "  [OK] $($file.Name) -> $newFileName" -Color Green
            $hashDatabase[$fileHash] = $newFileName
            $stats.Copied++
        } else {
            Write-Log "  [FAIL] Hash verification failed: $($file.Name)" -Color Red
            Remove-Item $newFilePath -Force -ErrorAction SilentlyContinue
            $stats.Failed++
        }
    } catch {
        Write-Log "  [FAIL] Copy error: $($_.Exception.Message)" -Color Red
        $stats.Failed++
    }
}

Save-HashDatabase

Write-Log "`n========== FINAL REPORT ==========" -Color Cyan
Write-Log "Total files: $($stats.Total)" -Color White
Write-Log "Newly copied: $($stats.Copied)" -Color Green
Write-Log "Skipped (duplicate content): $($stats.SkippedByHash)" -Color Gray
Write-Log "Skipped (file exists): $($stats.SkippedByExist)" -Color Gray
Write-Log "Failed: $($stats.Failed)" -Color Red
Write-Log "Hash database: $hashFilePath" -Color White
Write-Log "==================================" -Color Cyan

Read-Host "`nPress Enter to exit"
