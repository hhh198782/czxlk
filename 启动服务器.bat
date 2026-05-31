@echo off
chcp 65001 >nul
cd /d "%~dp0"
title 瓷砖SKU知识库采集系统

:menu
cls
echo.
echo ============================================
echo    瓷砖SKU知识库采集系统 - 启动菜单
echo ============================================
echo    1. 安装依赖（首次运行）
echo    2. 启动 API 服务器
echo    3. 手动采集指定品牌
echo    4. 手动采集全部品牌
echo    5. 打开管理控制台
echo    6. 打开接口文档
echo    Q. 退出
echo ============================================
echo.
set /p choice=请输入选项编号 (1-6 或 Q): 

if "%choice%"=="1" goto install
if "%choice%"=="2" goto server
if "%choice%"=="3" goto crawl_one
if "%choice%"=="4" goto crawl_all
if "%choice%"=="5" goto admin
if "%choice%"=="6" goto docs
if /i "%choice%"=="Q" goto :eof
echo 无效选项，请重试...
timeout /t 2 >nul
goto menu

:install
echo.
echo 正在安装Python依赖...
call 安装依赖.bat
pause
goto menu

:server
echo.
echo 正在启动API服务器（端口8000）...
echo 启动后请勿关闭此窗口！
echo 按 Ctrl+C 停止服务器
echo.
python -m uvicorn api.main:app --host 0.0.0.0 --port 8000
pause
goto menu

:crawl_one
echo.
set /p brand=请输入品牌名称（罗斯福/金泰源/华硕/瑞阳）: 
if "%brand%"=="" goto menu
echo 正在采集品牌: %brand%...
python scheduler/daily_update.py --brand %brand%
pause
goto menu

:crawl_all
echo.
echo 正在采集所有品牌（罗斯福、金泰源、华硕、瑞阳）...
python scheduler/daily_update.py --all
pause
goto menu

:admin
echo.
echo 正在打开管理控制台...
start http://localhost:8000/admin
echo 如果浏览器未打开，请手动访问 http://localhost:8000/admin
pause
goto menu

:docs
echo.
echo 正在打开接口文档...
start http://localhost:8000/docs
echo 如果浏览器未打开，请手动访问 http://localhost:8000/docs
pause
goto menu