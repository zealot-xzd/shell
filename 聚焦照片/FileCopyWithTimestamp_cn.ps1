# FileCopyWithAdvancedHash.ps1 - 增强版
# 支持手动重置哈希数据库、只拷贝新文件等高级功能
# 设置控制台编码

param(
    [string]$SourceDir = "C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\DesktopSpotlight\Assets\Images",
    [string]$TargetDir = "C:\mydata\picture\Assets",
    [string[]]$Extensions = @(".jpg", ".png"),
    [switch]$ResetHashDB,      # 重置哈希数据库（清空历史）
    [switch]$ForceCopy,         # 强制拷贝（忽略哈希去重）
    [switch]$VerifyHash,        # 验证已有文件完整性
    [switch]$NoTimestamp        # 不使用时间戳，保留原文件名
)

# 设置哈希数据库路径
$hashFilePath = "$TargetDir\file_hashes.json"
$integrityLogPath = "$TargetDir\integrity_check.log"

# 日志函数
function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$Message" -ForegroundColor $Color
}

# 初始化配置
Write-Log "========== 文件拷贝任务（持久化哈希去重）==========" -Color Cyan

# 重置哈希数据库
if ($ResetHashDB -and (Test-Path $hashFilePath)) {
    Write-Log "[操作] 重置哈希数据库" -Color Yellow
    Remove-Item $hashFilePath -Force
    if (Test-Path $integrityLogPath) { Remove-Item $integrityLogPath -Force }
}

# 检查源目录
if (-not (Test-Path $SourceDir)) {
    Write-Log "[错误] 源目录不存在: $SourceDir" -Color Red
    exit 1
}

# 创建目标目录
if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    Write-Log "[创建] 目标目录: $TargetDir" -Color Green
}

# ========== 哈希数据库管理 ==========
$hashDatabase = @{}

function Load-HashDatabase {
    if (Test-Path $hashFilePath) {
        try {
            $json = Get-Content $hashFilePath -Raw -Encoding UTF8
            if ($json) {
                $hashDatabase = $json | ConvertFrom-Json -AsHashtable
                Write-Log "[加载] 哈希数据库: $($hashDatabase.Count) 条记录" -Color Gray
            }
        } catch {
            Write-Log "[警告] 加载失败: $($_.Exception.Message)" -Color Yellow
        }
    } else {
        Write-Log "[信息] 未找到哈希数据库，将创建新文件" -Color Gray
    }
    return $hashDatabase
}

function Save-HashDatabase {
    try {
        $json = $hashDatabase | ConvertTo-Json -Depth 10
        $json | Out-File $hashFilePath -Encoding UTF8
        Write-Log "[保存] 哈希数据库: $($hashDatabase.Count) 条记录" -Color Gray
    } catch {
        Write-Log "[错误] 保存失败: $($_.Exception.Message)" -Color Red
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

# 验证已有文件的完整性
function Verify-ExistingFiles {
    Write-Log "`n[验证] 检查目标目录文件完整性..." -Color Cyan
    $verified = 0
    $failed = 0
    
    $targetFiles = Get-ChildItem -Path $TargetDir -File | Where-Object { $_.Extension -in $Extensions }
    
    foreach ($file in $targetFiles) {
        $currentHash = Get-FileHashValue -FilePath $file.FullName
        if ($currentHash) {
            # 检查哈希是否在数据库中
            $found = $false
            foreach ($hash in $hashDatabase.Keys) {
                if ($hashDatabase[$hash] -eq $file.Name) {
                    if ($hash -ne $currentHash) {
                        Write-Log "  [!] 文件已损坏: $($file.Name)" -Color Red
                        $failed++
                    } else {
                        $verified++
                    }
                    $found = $true
                    break
                }
            }
            if (-not $found) {
                Write-Log "  [?] 文件不在数据库中: $($file.Name)" -Color Yellow
                # 添加到数据库
                $hashDatabase[$currentHash] = $file.Name
            }
        }
    }
    Write-Log "[结果] 验证完成: $verified 个完整, $failed 个损坏" -Color Gray
    if ($failed -gt 0) {
        $failed | Out-File $integrityLogPath -Encoding UTF8
        Write-Log "[日志] 损坏文件列表已保存到: $integrityLogPath" -Color Yellow
    }
}

# ========== 主程序 ==========
$hashDatabase = Load-HashDatabase

if ($VerifyHash) {
    Verify-ExistingFiles
}

Write-Log "`n源目录: $SourceDir" -Color Gray
Write-Log "目标目录: $TargetDir" -Color Gray
Write-Log ""

# 统计变量
$stats = @{ Total = 0; Copied = 0; SkippedByHash = 0; SkippedByExist = 0; Failed = 0 }

# 收集所有文件
$allFiles = @()
foreach ($ext in $Extensions) {
    $allFiles += Get-ChildItem -Path $SourceDir -Filter "*$ext" -Recurse -File -ErrorAction SilentlyContinue
}
$stats.Total = $allFiles.Count

Write-Log "找到 $($stats.Total) 个文件待处理" -Color Yellow

foreach ($file in $allFiles) {
    Write-Log "`n处理: $($file.Name)" -Color Gray
    
    # 1. 计算哈希
    $fileHash = Get-FileHashValue -FilePath $file.FullName
    if (-not $fileHash) {
        $stats.Failed++
        continue
    }
    
    # 2. 哈希去重（除非强制拷贝）
    if (-not $ForceCopy -and $hashDatabase.ContainsKey($fileHash)) {
        Write-Log "  [跳过] 内容重复 (已存在: $($hashDatabase[$fileHash]))" -Color Gray
        $stats.SkippedByHash++
        continue
    }
    
    # 3. 生成目标文件名
    if ($NoTimestamp) {
        $newFileName = $file.Name
    } else {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmssfff"
        $newFileName = "${timestamp}_$($file.Name)"
    }
    $newFilePath = Join-Path $TargetDir $newFileName
    
    # 4. 检查文件存在性
    if (Test-Path $newFilePath) {
        Write-Log "  [跳过] 文件已存在: $newFileName" -Color Gray
        $stats.SkippedByExist++
        continue
    }
    
    # 5. 拷贝并验证
    try {
        Copy-Item -Path $file.FullName -Destination $newFilePath -ErrorAction Stop
        
        # 验证拷贝完整性
        $copiedHash = Get-FileHashValue -FilePath $newFilePath
        if ($copiedHash -eq $fileHash) {
            Write-Log "  [成功] $($file.Name) -> $newFileName" -Color Green
            $hashDatabase[$fileHash] = $newFileName
            $stats.Copied++
        } else {
            Write-Log "  [失败] 哈希验证失败: $($file.Name)" -Color Red
            Remove-Item $newFilePath -Force -ErrorAction SilentlyContinue
            $stats.Failed++
        }
    } catch {
        Write-Log "  [失败] 拷贝出错: $($_.Exception.Message)" -Color Red
        $stats.Failed++
    }
}

# 保存数据库
Save-HashDatabase

# 输出报告
Write-Log "`n========== 最终报告 ==========" -Color Cyan
Write-Log "总计: $($stats.Total) 个文件" -Color White
Write-Log "新增拷贝: $($stats.Copied) 个" -Color Green
Write-Log "跳过(重复内容): $($stats.SkippedByHash) 个" -Color Gray
Write-Log "跳过(文件已存在): $($stats.SkippedByExist) 个" -Color Gray
Write-Log "失败: $($stats.Failed) 个" -Color Red
Write-Log "哈希数据库: $hashFilePath" -Color White
Write-Log "==================================" -Color Cyan

Read-Host "`n按回车键退出"
