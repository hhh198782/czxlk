@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo.
echo ============================================
echo   瓷砖SKU知识库采集系统 - 安装依赖
echo ============================================
echo.

echo [1/2] 正在安装 Python 依赖包...
python -m pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
if %errorlevel% neq 0 (
    echo 清华源失败，尝试默认源...
    python -m pip install -r requirements.txt
)

echo.
echo [2/2] 正在安装 Playwright 浏览器（Chromium）...
echo 这可能需要下载约180MB文件，请耐心等待...
python -m playwright install chromium

echo.
echo ============================================
echo           安装完成！
echo ============================================
echo.
echo 接下来请在管理控制台中配置大模型 API 密钥：
echo   访问 http://localhost:8000/admin
echo   或在 .env 文件中手动填写
echo.
pause