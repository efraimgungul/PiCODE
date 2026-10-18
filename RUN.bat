@echo off
setlocal EnableExtensions
chcp 65001 >nul
cd /d "%~dp0"

rem ======================================================================
rem  PiCODE - tek tikla kurulum ve baslatma (Windows)
rem
rem  1. Python 3.10+ (yoksa winget ile Python 3.12 kurar)
rem  2. .venv sanal ortami + backend\requirements.txt paketleri
rem  3. Ollama (yoksa winget ile kurar) ve Ollama sunucusu
rem  4. Gemma 4 modeli (yoksa indirir, yaklasik 8 GB)
rem  5. PiCODE sunucusu + tarayicida http://127.0.0.1:8000
rem
rem  Secenekler:
rem    RUN.bat --no-start        sadece kurulum, siteyi baslatmaz
rem    set PICODE_MODEL=...   baska bir Gemma 4 etiketi kullan
rem    set PICODE_PORT=...    baska bir port kullan (varsayilan 8000)
rem    set PICODE_NO_BROWSER=1  tarayiciyi otomatik acma
rem ======================================================================

if not defined PICODE_MODEL set "PICODE_MODEL=gemma4:12b"
if not defined PICODE_PORT set "PICODE_PORT=8000"
set "OLLAMA_URL=http://127.0.0.1:11434"
set "APP_URL=http://127.0.0.1:%PICODE_PORT%"

rem Bu dosya kendini arka planda tarayici acmak icin de cagirir.
if "%~1"=="__open_browser" goto open_browser

set "NO_START="
if /i "%~1"=="--no-start" set "NO_START=1"
set "HAVE_WINGET="
where winget >nul 2>&1 && set "HAVE_WINGET=1"
set "MODEL_READY="

title PiCODE
echo.
echo  ==============================================
echo    PiCODE - kurulum ve başlatma
echo  ==============================================
echo.

rem ---------------------------------------------------------------- 1. Python
echo [1/5] Python kontrol ediliyor...
call :find_python
if defined PY goto python_found
echo       Python bulunamadı.
if not defined HAVE_WINGET goto no_python
echo       winget ile Python 3.12 kuruluyor...
winget install -e --id Python.Python.3.12 --scope user --accept-package-agreements --accept-source-agreements
call :find_python
if not defined PY goto no_python
:python_found
%PY% -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>&1 || goto old_python
for /f "delims=" %%V in ('%PY% --version 2^>^&1') do echo       %%V bulundu.

rem ---------------------------------------------------------------- 2. venv + paketler
echo [2/5] Python paketleri kuruluyor...
if exist ".venv\Scripts\python.exe" goto venv_ready
echo       Sanal ortam oluşturuluyor: .venv
%PY% -m venv .venv || goto fail_venv
:venv_ready
set "VPY=%CD%\.venv\Scripts\python.exe"
"%VPY%" -m pip install --disable-pip-version-check -q -r backend\requirements.txt || goto fail_pip
echo       fastapi, uvicorn, httpx hazır.

rem ---------------------------------------------------------------- 3. Ollama
echo [3/5] Ollama kontrol ediliyor...
call :find_ollama
if defined OLLAMA goto ollama_found
echo       Ollama bulunamadı.
if not defined HAVE_WINGET goto no_ollama
echo       winget ile Ollama kuruluyor...
winget install -e --id Ollama.Ollama --accept-package-agreements --accept-source-agreements
call :find_ollama
if not defined OLLAMA goto no_ollama
:ollama_found
echo       Ollama: %OLLAMA%

curl -s -f "%OLLAMA_URL%/api/tags" >nul 2>&1 && goto ollama_running
echo       Ollama sunucusu başlatılıyor...
start "Ollama" /min "%OLLAMA%" serve
set /a TRIES=0
:wait_ollama
ping -n 2 127.0.0.1 >nul
curl -s -f "%OLLAMA_URL%/api/tags" >nul 2>&1 && goto ollama_running
set /a TRIES+=1
if %TRIES% lss 45 goto wait_ollama
echo       UYARI: Ollama 45 saniye içinde yanıt vermedi. Site demo modunda açılacak.
goto start_app
:ollama_running
echo       Ollama sunucusu çalışıyor: %OLLAMA_URL%

rem ---------------------------------------------------------------- 4. Gemma 4 modeli
echo [4/5] Model kontrol ediliyor: %PICODE_MODEL%
"%OLLAMA%" list 2>nul | findstr /b /c:"%PICODE_MODEL% " >nul && goto model_found
echo       Model yüklü değil, indiriliyor. Bu işlem yaklaşık 8 GB indirir ve sürebilir...
echo       Not: 12B model için yaklaşık 8 GB boş bellek önerilir.
"%OLLAMA%" pull %PICODE_MODEL%
if errorlevel 1 goto model_failed
:model_found
set "MODEL_READY=1"
echo       %PICODE_MODEL% hazır.
goto start_app
:model_failed
echo       UYARI: Model indirilemedi. İnternet bağlantınızı ve model adını kontrol edin.
echo       Site yine açılır; yapay zeka analizi yerine demo modunu kullanabilirsiniz.

rem ---------------------------------------------------------------- 5. PiCODE
:start_app
if defined NO_START goto setup_done
echo [5/5] PiCODE başlatılıyor...
curl -s -f "%APP_URL%/api/config" >nul 2>&1 && goto already_running

if not defined PICODE_NO_BROWSER start "" /b "%~f0" __open_browser
echo.
echo  ----------------------------------------------
echo    PiCODE:  %APP_URL%
if defined MODEL_READY echo    Model:      %PICODE_MODEL% - Ollama üzerinden
if not defined MODEL_READY echo    Model:      hazır değil, demo modu kullanılabilir
echo    Durdurmak için bu pencerede Ctrl+C tuşlayın.
echo  ----------------------------------------------
echo.
"%VPY%" -m uvicorn backend.app:app --host 127.0.0.1 --port %PICODE_PORT%
echo.
echo PiCODE durduruldu.
pause
exit /b 0

:already_running
echo       PiCODE zaten çalışıyor: %APP_URL%
if not defined PICODE_NO_BROWSER start "" "%APP_URL%"
exit /b 0

:setup_done
echo.
echo Kurulum tamamlandı. Başlatmak için: RUN.bat
exit /b 0

rem ================================================================ yardımcılar

:find_python
set "PY="
py -3 --version >nul 2>&1 && set "PY=py -3" && goto :eof
python --version >nul 2>&1 && set "PY=python" && goto :eof
for %%V in (313 312 311 310) do if exist "%LOCALAPPDATA%\Programs\Python\Python%%V\python.exe" (
  set PY="%LOCALAPPDATA%\Programs\Python\Python%%V\python.exe"
  goto :eof
)
goto :eof

:find_ollama
set "OLLAMA="
for /f "delims=" %%P in ('where ollama 2^>nul') do if not defined OLLAMA set "OLLAMA=%%P"
if not defined OLLAMA if exist "%LOCALAPPDATA%\Programs\Ollama\ollama.exe" set "OLLAMA=%LOCALAPPDATA%\Programs\Ollama\ollama.exe"
goto :eof

:open_browser
rem Sunucu yanıt verene kadar bekler (en fazla 60 sn), sonra tarayıcıyı açar.
for /l %%i in (1,1,60) do (
  curl -s -f "%APP_URL%/api/config" >nul 2>&1 && (
    start "" "%APP_URL%"
    exit /b 0
  )
  ping -n 2 127.0.0.1 >nul
)
exit /b 0

rem ================================================================ hatalar

:no_python
echo.
echo HATA: Python 3.10 veya üstü bulunamadı ve otomatik kurulamadı.
echo       https://www.python.org/downloads/ adresinden kurun, ardından RUN.bat'ı tekrar çalıştırın.
pause
exit /b 1

:old_python
echo.
echo HATA: Python sürümü çok eski. PiCODE Python 3.10 veya üstünü gerektirir.
pause
exit /b 1

:fail_venv
echo.
echo HATA: .venv sanal ortamı oluşturulamadı.
pause
exit /b 1

:fail_pip
echo.
echo HATA: Python paketleri kurulamadı. İnternet bağlantınızı kontrol edin.
pause
exit /b 1

:no_ollama
echo       UYARI: Ollama kurulamadı. https://ollama.com/download adresinden kurabilirsiniz.
echo       Site yine açılır; yapay zeka analizi yerine demo modunu kullanabilirsiniz.
goto start_app
