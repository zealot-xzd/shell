# Get-SoftwareLocation.ps1
# 功能：查询已安装软件的安装位置
# 使用方法：在PowerShell中运行此脚本，或双击运行

param(
    [Parameter(Mandatory=$false)]
    [string]$SoftwareName = ""
)

function Get-InstalledSoftware {
    param([string]$SearchPattern)
    
    $results = @()
    
    # 查询当前用户安装的软件 (HKCU)
    $userPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    # 查询所有用户安装的软件 (HKLM)
    $machinePaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    $allPaths = $userPaths + $machinePaths
    
    foreach ($path in $allPaths) {
        try {
            $items = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                # 过滤掉没有DisplayName的项目
                if (-not $item.DisplayName) { continue }
                
                $displayName = $item.DisplayName
                $installLocation = $item.InstallLocation
                $uninstallString = $item.UninstallString
                
                # 如果传入搜索关键词，进行过滤
                if ($SearchPattern -and $displayName -notlike "*$SearchPattern*") {
                    continue
                }
                
                # 尝试从InstallLocation获取路径
                $finalPath = $null
                if ($installLocation -and (Test-Path $installLocation)) {
                    $finalPath = $installLocation
                }
                # 如果InstallLocation为空，尝试从UninstallString中提取路径
                elseif ($uninstallString) {
                    # 匹配常见的路径模式
                    if ($uninstallString -match '"([^"]+\.exe)"' -or 
                        $uninstallString -match "([A-Za-z]:\\[^/\\]+\\[^/\\]+\.exe)" -or
                        $uninstallString -match "([A-Za-z]:\\[^ ]+\.exe)") {
                        $exePath = $matches[1]
                        $finalPath = Split-Path $exePath -Parent
                        if (-not (Test-Path $finalPath)) { $finalPath = $null }
                    }
                }
                # 如果还是找不到，尝试搜索常见的主程序
                if (-not $finalPath) {
                    $commonExes = @("$displayName.exe", "$($displayName -replace ' ','')*.exe")
                    foreach ($commonExe in $commonExes) {
                        $foundExe = Get-ChildItem -Path "C:\Program Files", "C:\Program Files (x86)" -Filter $commonExe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                        if ($foundExe) {
                            $finalPath = $foundExe.DirectoryName
                            break
                        }
                    }
                }
                
                $results += [PSCustomObject]@{
                    软件名称 = $displayName
                    版本 = $item.DisplayVersion
                    发布者 = $item.Publisher
                    安装路径 = if ($finalPath) { $finalPath } else { "未找到" }
                    卸载字符串 = $uninstallString
                }
            }
        }
        catch {
            # 忽略无法访问的路径
        }
    }
    
    return $results
}

# 主程序
Clear-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "        软件安装位置查询工具" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 如果命令行没有提供参数，则提示用户输入
if ([string]::IsNullOrEmpty($SoftwareName)) {
    Write-Host "请输入要搜索的软件名称（支持模糊匹配）:" -ForegroundColor Yellow
    Write-Host "提示：直接按回车键可列出所有软件" -ForegroundColor Gray
    $SoftwareName = Read-Host
}

Write-Host ""
Write-Host "正在搜索，请稍候..." -ForegroundColor Green
Write-Host ""

$results = Get-InstalledSoftware -SearchPattern $SoftwareName

if ($results.Count -eq 0) {
    Write-Host "未找到匹配的软件" -ForegroundColor Red
    
    if (-not [string]::IsNullOrEmpty($SoftwareName)) {
        Write-Host ""
        Write-Host "💡 提示：" -ForegroundColor Yellow
        Write-Host "  1. 请检查软件名称是否正确" -ForegroundColor Gray
        Write-Host "  2. 运行 '$ $SoftwareName' 参数在运行时直接指定搜索词" -ForegroundColor Gray
        Write-Host "  3. 不输入任何参数直接运行可列出所有软件" -ForegroundColor Gray
    }
}
else {
    Write-Host "找到 $($results.Count) 个匹配的软件：" -ForegroundColor Green
    Write-Host ""
    
    # 显示结果
    foreach ($app in $results) {
        Write-Host "────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "📦 软件名称: " -NoNewline -ForegroundColor White
        Write-Host $app.软件名称 -ForegroundColor Cyan
        
        if ($app.版本) {
            Write-Host "📌 版本号: " -NoNewline -ForegroundColor White
            Write-Host $app.版本 -ForegroundColor Gray
        }
        
        if ($app.发布者) {
            Write-Host "🏢 发布者: " -NoNewline -ForegroundColor White
            Write-Host $app.发布者 -ForegroundColor Gray
        }
        
        Write-Host "📍 安装路径: " -NoNewline -ForegroundColor White
        if ($app.安装路径 -ne "未找到") {
            Write-Host $app.安装路径 -ForegroundColor Green
        } else {
            Write-Host $app.安装路径 -ForegroundColor Red
        }
        
        # 如果有卸载字符串且用户需要，可以显示（注释掉避免信息过多）
        # Write-Host "🔧 卸载命令: " -NoNewline -ForegroundColor White
        # Write-Host $app.卸载字符串 -ForegroundColor Gray -NoNewline
    }
    Write-Host "────────────────────────────────────────" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "提示：" -ForegroundColor Yellow
Write-Host "• “安装路径”显示为“未找到”表示注册表中无此信息" -ForegroundColor Gray
Write-Host "• 部分便携版软件不会在注册表中留下路径信息" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
