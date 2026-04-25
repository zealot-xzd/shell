# ============================================
# PowerShell 模块化配置安装脚本
# ============================================

# 1. 创建配置目录
$configDir = "$env:USERPROFILE\.config\powershell"
if (!(Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force
    Write-Host "✅ 创建配置目录: $configDir" -ForegroundColor Green
}

# 2. 创建 aliases.ps1（基础别名）
$aliasesFile = "$configDir\aliases.ps1"
$aliasesContent = @'
# ============================================
# 别名配置文件
# 文件: aliases.ps1
# 说明: 简单的命令别名映射
# ============================================

# ---------- 基础命令别名 ----------
Set-Alias -Name ls -Value Get-ChildItem
Set-Alias -Name ll -Value Get-ChildItem
Set-Alias -Name la -Value Get-ChildItem
Set-Alias -Name l -Value Get-ChildItem
Set-Alias -Name pwd -Value Get-Location
Set-Alias -Name mkdir -Value New-Item
Set-Alias -Name rmdir -Value Remove-Item
Set-Alias -Name rm -Value Remove-Item
Set-Alias -Name mv -Value Move-Item
Set-Alias -Name ps -Value Get-Process
Set-Alias -Name kill -Value Stop-Process
Set-Alias -Name grep -Value Select-String
Set-Alias -Name df -Value Get-Volume
Set-Alias -Name which -Value Get-Command
Set-Alias -Name ping -Value Test-Connection
Set-Alias -Name curl -Value Invoke-WebRequest
Set-Alias -Name clear -Value Clear-Host
Set-Alias -Name cls -Value Clear-Host
Set-Alias -Name tm -Value taskmgr.exe
# 4. 应用程序别名
Set-Alias np notepad
Set-Alias calc calc.exe

# ===== 网络相关命令 =====
function ip { ipconfig }
function ipa { ipconfig /all }
function ports { netstat -ano $args }

function wsll { wsl -l -v }

Write-Host "  ✅ 别名模块已加载" -ForegroundColor Gray
'@
Set-Content -Path $aliasesFile -Value $aliasesContent -Encoding UTF8
Write-Host "✅ 创建: aliases.ps1" -ForegroundColor Green

# 3. 创建 functions.ps1（增强函数）
$functionsFile = "$configDir\functions.ps1"
$functionsContent = @'
# ============================================
# 函数配置文件
# 文件: functions.ps1
# 说明: 增强功能的函数定义
# ============================================

# ---------- 目录操作增强 ----------
function ll { Get-ChildItem @args | Where-Object { -not ($_.Attributes -match 'Hidden') } }
function ld { Get-ChildItem @args | Where-Object { $_.PSIsContainer } }
function lf { Get-ChildItem @args | Where-Object { -not $_.PSIsContainer -and -not ($_.Attributes -match 'Hidden') } }
function la { Get-ChildItem -Force @args }
function lt { Get-ChildItem @args | Sort-Object LastWriteTime }
#function lt { Get-ChildItem @args | Sort-Object LastWriteTime -Descending }
function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }
function ~ { Set-Location ~ }
function mydata { Set-Location C:\mydata }
function tmp { Set-Location C:\mydata\tmp_dir }
function github { Set-Location C:\mydata\github }
function ram { Set-Location R:\ }

# 3. Git 快捷命令
function gst { git status }
function gad { git add $args }
function gci { git commit -m "$args" }
function gco { git checkout $args }
function gbr { git branch }
function glg { git log --oneline --graph --all --decorate }
# ===== 进程管理 =====
function kill { taskkill /f /pid "$args" }
# services: 打开服务管理器
function services { Start-Process services.msc }
# regedit: 打开注册表编辑器
function regedit { Start-Process regedit.exe }
# 查看开机启动项
function startup {
    Get-CimInstance -ClassName Win32_StartupCommand |
        Select-Object Name, Command, Location, User |
        Format-Table -AutoSize
}


function ls-color {
    Get-ChildItem | ForEach-Object {
        if ($_.PSIsContainer) {
            Write-Host $_.Name -ForegroundColor Blue
        } else {
            Write-Host $_.Name -ForegroundColor White
        }
    }
}

# 在资源管理器中打开指定目录
        function op { param($path); explorer.exe $path }

# 在当前目录打开资源管理器并选中当前文件夹
        function os { explorer.exe /select,. }

# 打开用户目录
        function o~ { explorer.exe ~ }

# 查看所有环境变量
        function env { Get-ChildItem Env: }
        function envfind { param($keyword); Get-ChildItem Env:*$keyword* }

# ===== 代理管理函数 =====

# 开启代理
        function proxy {
            param(
                [string]$Type = "socks5",  # http, https, socks5
                [string]$Host_Ip = "127.0.0.1",
                [int]$Port = 1080
            )
            
            $proxyAddr = "${Type}://${Host_Ip}:${Port}"

            $env:HTTP_PROXY = $proxyAddr
            $env:HTTPS_PROXY = $proxyAddr
            $env:NO_PROXY = "localhost,127.0.0.1,::1"
            Write-Host "代理已开启: $proxyAddr" -ForegroundColor Green
        }

# 关闭代理
        function noproxy {
            Remove-Item Env:HTTP_PROXY -ErrorAction SilentlyContinue
            Remove-Item Env:HTTPS_PROXY -ErrorAction SilentlyContinue
            Remove-Item Env:NO_PROXY -ErrorAction SilentlyContinue
            Write-Host "代理已关闭" -ForegroundColor Yellow
        }

# 查看当前代理状态
        function ifproxy {
            if ($env:HTTP_PROXY) {
                Write-Host "HTTP_PROXY: $env:HTTP_PROXY" -ForegroundColor Cyan
                Write-Host "HTTPS_PROXY: $env:HTTPS_PROXY" -ForegroundColor Cyan
            } else {
                Write-Host "代理未设置" -ForegroundColor Gray
            }
        }

function cd {
    param([string]$Path)
    if ($Path) {
        Set-Location $Path
    } else {
        Set-Location ~
    }
    Get-ChildItem | Format-Wide -AutoSize
}

function .. {
    Set-Location ..
    Get-ChildItem | Format-Wide -AutoSize
}

function ... {
    Set-Location ..\..
    Get-ChildItem | Format-Wide -AutoSize
}

function .... {
    Set-Location ..\..\..
    Get-ChildItem | Format-Wide -AutoSize
}

function mkcd {
    param([string]$Path)
    New-Item -ItemType Directory -Path $Path -Force
    Set-Location $Path
    Write-Host "📁 已创建并进入: $Path" -ForegroundColor Green
}

# ---------- 文件操作增强 ----------
function rm {
    param(
        [string]$Path,
        [switch]$r
    )
    if ($r) {
        Write-Host "🗑️  删除目录: $Path" -ForegroundColor Yellow
        Remove-Item -Path $Path -Recurse -Force
    } else {
        Write-Host "🗑️  删除文件: $Path" -ForegroundColor Yellow
        Remove-Item -Path $Path -Force
    }
}

function cp {
    param(
        [string]$Source,
        [string]$Destination
    )
    Write-Host "📋 复制: $Source -> $Destination" -ForegroundColor Cyan
    Copy-Item -Path $Source -Destination $Destination -Recurse
}

function mv {
    param(
        [string]$Source,
        [string]$Destination
    )
    Write-Host "🚚 移动: $Source -> $Destination" -ForegroundColor Cyan
    Move-Item -Path $Source -Destination $Destination
}

function touch {
    param([string]$Path)
    if (Test-Path $Path) {
        (Get-Item $Path).LastWriteTime = Get-Date
        Write-Host "🕒 更新时间戳: $Path" -ForegroundColor Cyan
    } else {
        New-Item -ItemType File -Path $Path -Force | Out-Null
        Write-Host "📄 创建文件: $Path" -ForegroundColor Green
    }
}

# ---------- 文件查看增强 ----------
function cat {
    param(
        [string]$Path,
        [switch]$n
    )
    if ($n) {
        $lines = Get-Content $Path
        for ($i = 0; $i -lt $lines.Count; $i++) {
            Write-Host ("{0,6} {1}" -f ($i+1), $lines[$i])
        }
    } else {
        Get-Content $Path
    }
}

function head {
    param(
        [string]$Path,
        [int]$n = 10
    )
    Get-Content $Path -TotalCount $n
}

function tail {
    param(
        [string]$Path,
        [int]$n = 10
    )
    Get-Content $Path -Tail $n
}

# ---------- 搜索增强 ----------
function grep {
    param(
        [string]$Pattern,
        [string]$Path,
        [switch]$i,
        [switch]$n
    )
    $params = @{
        Pattern = $Pattern
        CaseSensitive = -not $i
    }
    if ($Path) { $params.Path = $Path }
    
    $matches = Get-ChildItem -Recurse -File | Select-String @params
    foreach ($match in $matches) {
        if ($n) {
            Write-Host ("{0}:{1}: {2}" -f $match.Filename, $match.LineNumber, $match.Line) -ForegroundColor Green
        } else {
            Write-Host ("{0}: {1}" -f $match.Filename, $match.Line) -ForegroundColor Green
        }
    }
}

function find {
    param(
        [string]$Name,
        [string]$Path = "."
    )
    Get-ChildItem -Path $Path -Recurse -Filter $Name -ErrorAction SilentlyContinue | Select-Object FullName
}

# ---------- 系统信息增强 ----------
function du {
    param([string]$Path = ".")
    $items = Get-ChildItem $Path
    foreach ($item in $items) {
        if ($item.PSIsContainer) {
            $size = (Get-ChildItem $item.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            if ($size -gt 1MB) {
                Write-Host ("{0,10:N2} MB  {1}" -f ($size/1MB), $item.Name) -ForegroundColor Yellow
            } elseif ($size -gt 1KB) {
                Write-Host ("{0,10:N2} KB  {1}" -f ($size/1KB), $item.Name) -ForegroundColor Cyan
            } else {
                Write-Host ("{0,10} B   {1}" -f $size, $item.Name)
            }
        } else {
            $size = $item.Length
            Write-Host ("{0,10} B   {1}" -f $size, $item.Name)
        }
    }
}

function ps {
    Get-Process | Sort-Object -Property WS -Descending | Select-Object -First 20 -Property Id, ProcessName, CPU, @{Name="Memory(MB)";Expression={[math]::Round($_.WS/1MB,2)}} | Format-Table -AutoSize
}

function which {
    param([string]$Command)
    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if ($cmd) {
        Write-Host $cmd.Source -ForegroundColor Green
    } else {
        Write-Host "未找到命令: $Command" -ForegroundColor Red
    }
}

Write-Host "  ✅ 函数模块已加载" -ForegroundColor Gray
'@
Set-Content -Path $functionsFile -Value $functionsContent -Encoding UTF8
Write-Host "✅ 创建: functions.ps1" -ForegroundColor Green

# 4. 创建 environment.ps1（环境变量）
$environmentFile = "$configDir\environment.ps1"
$environmentContent = @'
# ============================================
# 环境变量配置文件
# 文件: environment.ps1
# 说明: 环境变量和路径设置
# ============================================

# ---------- PowerShell 设置 ----------
# 历史记录设置
$env:PSHISTORY_PATH = "$env:USERPROFILE\.config\powershell\history.clixml"

# 临时目录
$env:USER_TEMP = "$env:TEMP\powershell"

# ===== 行编辑快捷键配置 =====

# 行跳转
        Set-PSReadLineKeyHandler -Chord Ctrl+a -Function BeginningOfLine
        Set-PSReadLineKeyHandler -Chord Ctrl+e -Function EndOfLine

# 行删除
        Set-PSReadLineKeyHandler -Chord Ctrl+u -Function BackwardKillLine
        Set-PSReadLineKeyHandler -Chord Ctrl+k -Function KillLine

# 历史命令导航
        Set-PSReadLineKeyHandler -Chord Ctrl+p -Function PreviousHistory
        Set-PSReadLineKeyHandler -Chord Ctrl+n -Function NextHistory

# 光标移动
        Set-PSReadLineKeyHandler -Chord Ctrl+b -Function BackwardChar
        Set-PSReadLineKeyHandler -Chord Ctrl+f -Function ForwardChar

# 删除字符
    Set-PSReadLineKeyHandler -Chord Ctrl+d -Function DeleteChar

# 粘贴剪切板内容 (Ctrl+Y)
        Set-PSReadLineKeyHandler -Chord Ctrl+y -Function Yank

# ---------- 工具路径（示例，根据需要取消注释）----------
# $env:PYTHON_PATH = "C:\Python39"
# $env:NODE_PATH = "C:\Program Files\nodejs"
# $env:JAVA_HOME = "C:\Program Files\Java\jdk-17"

# 添加到 PATH（示例）
# $env:PATH += ";$env:PYTHON_PATH"
# $env:PATH += ";$env:NODE_PATH"

# ---------- 语言设置 ----------
# $env:LANG = 'zh_CN.UTF-8'
# $env:LC_ALL = 'zh_CN.UTF-8'

# ---------- 其他实用环境变量 ----------
# 禁用 PowerShell 问候语
# $env:PROMPT_NO_GREETING = $true

# PowerShell 模块路径（添加自定义模块目录）
$customModules = "$env:USERPROFILE\.config\powershell\modules"
if (Test-Path $customModules) {
    $env:PSModulePath += ";$customModules"
}

# replace 'Ctrl+t' and 'Ctrl+r' with your preferred bindings:
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

Write-Host "  ✅ 环境变量模块已加载" -ForegroundColor Gray
'@
Set-Content -Path $environmentFile -Value $environmentContent -Encoding UTF8
Write-Host "✅ 创建: environment.ps1" -ForegroundColor Green

# 5. 创建 prompt.ps1（提示符主题）
$promptFile = "$configDir\prompt.ps1"
$promptContent = @'
# ============================================
# 提示符配置文件
# 文件: prompt.ps1
# 说明: 自定义 PowerShell 提示符
# ============================================

# 多种提示符主题可供选择
# 取消注释你喜欢的主题

# ---------- 主题 1: 简约风格（默认）----------
<#
function prompt {
    $path = (Get-Location).Path
    $user = $env:USERNAME
    $hostname = $env:COMPUTERNAME
    
    # 将用户目录替换为 ~
    $path = $path -replace [regex]::Escape($env:USERPROFILE), '~'
    
    # 判断管理员权限
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $adminSymbol = if ($isAdmin) { '#' } else { '$' }
    
    # 设置颜色
    Write-Host "[$user@$hostname" -NoNewline -ForegroundColor Cyan
    Write-Host ":" -NoNewline -ForegroundColor White
    Write-Host "$path" -NoNewline -ForegroundColor Green
    Write-Host "]" -NoNewline -ForegroundColor White
    Write-Host "$adminSymbol " -NoNewline -ForegroundColor Yellow
    
    return " "
}
#>

# ---------- 主题 2: Git 风格（显示 Git 分支）----------
<#
function prompt {
    $path = (Get-Location).Path
    $path = $path -replace [regex]::Escape($env:USERPROFILE), '~'
    
    # Git 分支检测
    $gitBranch = ""
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        if ($branch) {
            $gitBranch = " on [$branch]"
        }
    }
    
    Write-Host "┌[$path]" -NoNewline -ForegroundColor Green
    if ($gitBranch) {
        Write-Host "$gitBranch" -NoNewline -ForegroundColor Magenta
    }
    Write-Host ""
    Write-Host "└─λ " -NoNewline -ForegroundColor Cyan
    return ""
}
#>

# ---------- 主题 3: 极简风格 ----------
<#
function prompt {
    $path = (Get-Location).Path
    $path = $path -replace [regex]::Escape($env:USERPROFILE), '~'
    Write-Host "PS $path> " -NoNewline -ForegroundColor Green
    return ""
}
#>

# ---------- 主题 4: 多彩风格 ----------
<# 
function prompt {
    $path = (Get-Location).Path
    $path = $path -replace [regex]::Escape($env:USERPROFILE), '~'
    
    # 不同路径使用不同颜色
    $color = 'Green'
    if ($path -eq '~') { $color = 'Yellow' }
    elseif ($path -match 'Desktop') { $color = 'Cyan' }
    elseif ($path -match 'Projects') { $color = 'Magenta' }
    
    # 获取当前时间
    $time = Get-Date -Format 'HH:mm:ss'
    
    # 计算终端宽度
    $terminalWidth = $Host.UI.RawUI.WindowSize.Width
    if ($terminalWidth -lt 80) { $terminalWidth = 80 }
    
    # 构建第一行：路径 + 右对齐的时间
    $pathDisplay = "$path "
    $padding = $terminalWidth - $pathDisplay.Length - $time.Length - 2
    $spaces = if ($padding -gt 0) { " " * $padding } else { " " }
    
    # 第一行：路径在左，时间在右
    Write-Host $pathDisplay -NoNewline -ForegroundColor $color
    Write-Host "$spaces" -NoNewline
    Write-Host "[$time]" -ForegroundColor DarkGray
    
    # 第二行：提示符
    Write-Host "❯" -NoNewline -ForegroundColor Red
    
    return " "
}
#>

Write-Host "  ✅ 提示符模块已加载" -ForegroundColor Gray
'@
Set-Content -Path $promptFile -Value $promptContent -Encoding UTF8
Write-Host "✅ 创建: prompt.ps1" -ForegroundColor Green

# 6. 创建 profile.ps1（主配置文件）
$profileMain = "$configDir\profile.ps1"
$profileMainContent = @'
# ============================================
# PowerShell 主配置文件
# 文件: profile.ps1
# 说明: 主配置入口，按顺序加载各模块
# ============================================

# 获取配置目录路径
$configDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 按顺序加载配置文件
$modules = @(
    'aliases.ps1',      # 1. 基础别名
    'functions.ps1',    # 2. 增强函数
    'environment.ps1',  # 3. 环境变量
    'prompt.ps1'        # 4. 提示符主题
)

foreach ($module in $modules) {
    $modulePath = Join-Path $configDir $module
    if (Test-Path $modulePath) {
        . $modulePath
    } else {
        Write-Warning "找不到模块: $modulePath"
    }
}

# 自定义初始化代码
Write-Host "`n🎉 PowerShell 配置加载完成！" -ForegroundColor Green
Write-Host "📖 输入 'help-me' 查看可用命令" -ForegroundColor Cyan
Write-Host ""

# 创建帮助函数
function help-me {
    Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║                    PowerShell 配置帮助                       ║
╠══════════════════════════════════════════════════════════════╣
║  命令               说明                                     ║
╠══════════════════════════════════════════════════════════════╣
║  help-me           显示此帮助信息                            ║
║  edit-profile      编辑主配置文件                            ║
║  edit-aliases      编辑别名配置                              ║
║  edit-functions    编辑函数配置                              ║
║  edit-environment  编辑环境变量配置                          ║
║  edit-prompt       编辑提示符配置                            ║
║  reload-profile    重新加载所有配置                          ║
║  myaliases         查看所有可用别名                          ║
║  myfunctions       查看所有自定义函数                        ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
}

# 编辑配置文件的快捷函数
function edit-profile { 
    subl "$configDir\profile.ps1"
}
function edit-aliases { 
    subl "$configDir\aliases.ps1"
}
function edit-functions { 
    subl "$configDir\functions.ps1"
}
function edit-environment { 
    subl "$configDir\environment.ps1"
}
function edit-prompt { 
    subl "$configDir\prompt.ps1"
}

function reload-profile {
    . $PROFILE
    Write-Host "✅ 所有配置已重新加载" -ForegroundColor Green
}

function myaliases {
    Write-Host "========== 命令别名 ==========" -ForegroundColor Cyan
    Get-Alias | Where-Object { $_.Name -in @('ls','ll','la','l','cd','pwd','mkdir','rmdir','rm','cp','mv','cat','grep','ps','kill','df','du','which','clear','cls','echo') } | Format-Table Name, DisplayName -AutoSize
}

function myfunctions {
    Write-Host "========== 自定义函数 ==========" -ForegroundColor Cyan
    Get-ChildItem Function: | Where-Object { $_.Name -in @('ll','la','l','ls-color','cd','..','...','....','mkcd','rm','cp','mv','touch','cat','head','tail','grep','find','du','df','ps','which','help-me','edit-profile','edit-aliases','edit-functions','edit-environment','edit-prompt','reload-profile','myaliases','myfunctions') } | Format-Table Name, Definition -Wrap
}
'@
Set-Content -Path $profileMain -Value $profileMainContent -Encoding UTF8
Write-Host "✅ 创建: profile.ps1" -ForegroundColor Green

# 7. 配置 $PROFILE 导入主配置
if (!(Test-Path $PROFILE)) {
    New-Item -Path $PROFILE -ItemType File -Force | Out-Null
    Write-Host "✅ 创建 PowerShell 配置文件: $PROFILE" -ForegroundColor Green
}

# 备份原配置
if (Test-Path $PROFILE) {
    Copy-Item $PROFILE "$PROFILE.backup" -Force
    Write-Host "📦 已备份原配置到: $PROFILE.backup" -ForegroundColor Yellow
}

# 写入新的 $PROFILE（只包含导入语句）
$profileContent = @'
# ============================================
# PowerShell 用户配置文件
# 说明: 此文件仅用于导入模块化配置
# ============================================

# 导入主配置文件
if (Test-Path "$env:USERPROFILE\.config\powershell\profile.ps1") {
    . "$env:USERPROFILE\.config\powershell\profile.ps1"
} else {
    Write-Warning "找不到主配置文件: ~/.config/powershell/profile.ps1"
}
'@

Set-Content -Path $PROFILE -Value $profileContent -Encoding UTF8
Write-Host "✅ 更新 $PROFILE 配置文件" -ForegroundColor Green

# 8. 立即加载配置
. $PROFILE

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                    🎉 配置完成！                             ║" -ForegroundColor Green
Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Green
Write-Host "║  配置目录: ~/.config/powershell/                             ║" -ForegroundColor Yellow
Write-Host "║                                                              ║" -ForegroundColor Yellow
Write-Host "║  配置文件清单:                                               ║" -ForegroundColor Cyan
Write-Host "║    ├── profile.ps1      # 主配置文件（入口）                 ║" -ForegroundColor White
Write-Host "║    ├── aliases.ps1      # 别名配置                           ║" -ForegroundColor White
Write-Host "║    ├── functions.ps1    # 函数配置                           ║" -ForegroundColor White
Write-Host "║    ├── environment.ps1  # 环境变量配置                       ║" -ForegroundColor White
Write-Host "║    └── prompt.ps1       # 提示符主题配置                     ║" -ForegroundColor White
Write-Host "║                                                              ║" -ForegroundColor Yellow
Write-Host "║  常用命令:                                                   ║" -ForegroundColor Cyan
Write-Host "║    help-me            # 显示帮助                             ║" -ForegroundColor White
Write-Host "║    edit-xxx           # 编辑各配置文件                       ║" -ForegroundColor White
Write-Host "║    reload-profile     # 重新加载配置                         ║" -ForegroundColor White
Write-Host "║    myaliases          # 查看别名                             ║" -ForegroundColor White
Write-Host "║    myfunctions        # 查看函数                             ║" -ForegroundColor White
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

