@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo 正在设置文件拷贝任务...

:: 设置参数 - 在这里修改路径和后缀
set "source_dir=C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\DesktopSpotlight\Assets\Images"
set "target_dir=C:\mydata\picture\Assets"
set "file_extensions=.jpg .png"

:: 创建目标目录
if not exist "%target_dir%" (
    echo 创建目标目录: %target_dir%
    mkdir "%target_dir%"
)

echo.
echo 源目录: %source_dir%
echo 目标目录: %target_dir%
echo 文件后缀: %file_extensions%
echo.

set file_count=0
echo 开始拷贝文件...

for %%e in (%file_extensions%) do (
    echo.
    echo 正在拷贝 %%e 文件...
    for /r "%source_dir%" %%f in (*%%e) do (

		set "timestamp=%date:~3,4%%date:~8,2%%date:~11,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
		set "timestamp=!timestamp: =0!"
		set "new_filename=!timestamp!_%%~nxf"
		echo  拷贝: %%~nxf to !new_filename!
        copy "%%f" "%target_dir%\!new_filename!" >nul
        set /a file_count+=1
    )
)

echo.
echo ================================
echo "文件拷贝完成！共拷贝 %file_count% 个文件"
echo "文件保存在: %target_dir%"
echo ================================
echo.

pause
