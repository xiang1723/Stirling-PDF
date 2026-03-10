@echo off
setlocal EnableExtensions EnableDelayedExpansion

for %%I in ("%~dp0..") do set "ROOT_DIR=%%~fI"
set "FRONTEND_DIR=%ROOT_DIR%\frontend"
set "RELEASE_DIR=%FRONTEND_DIR%\src-tauri\target\release"
set "PORTABLE_ROOT=%FRONTEND_DIR%\src-tauri\target\portable"
set "PORTABLE_DIR=%PORTABLE_ROOT%\Stirling-PDF-portable"
set "ZIP_FILE=%PORTABLE_ROOT%\Stirling-PDF-portable.zip"

echo [1/5] Check prerequisites
call "%~dp0check-windows-portable-prereqs.bat"
if errorlevel 1 (
  echo ERROR: prerequisite check failed.
  exit /b 1
)

echo [2/5] Build backend JAR + bundled JRE
call "%~dp0build-tauri-jlink.bat"
if errorlevel 1 (
  echo ERROR: backend JAR/JRE preparation failed.
  exit /b 1
)

echo [3/5] Build Tauri desktop app (local-only mode)
set "VITE_DESKTOP_LOCAL_ONLY=true"
set "DISABLE_ADDITIONAL_FEATURES=false"

pushd "%FRONTEND_DIR%"
call npm run tauri-build-dev
if errorlevel 1 (
  popd
  echo ERROR: tauri build failed.
  exit /b 1
)
popd

if not exist "%RELEASE_DIR%" (
  echo ERROR: release directory not found: %RELEASE_DIR%
  exit /b 1
)

if exist "%PORTABLE_DIR%" rmdir /s /q "%PORTABLE_DIR%"
mkdir "%PORTABLE_DIR%"
if errorlevel 1 (
  echo ERROR: failed to create portable directory.
  exit /b 1
)

set "APP_EXE="
if exist "%RELEASE_DIR%\stirling-pdf.exe" set "APP_EXE=%RELEASE_DIR%\stirling-pdf.exe"
if not defined APP_EXE if exist "%RELEASE_DIR%\Stirling-PDF.exe" set "APP_EXE=%RELEASE_DIR%\Stirling-PDF.exe"

if not defined APP_EXE (
  echo ERROR: unable to locate built EXE in %RELEASE_DIR%
  dir /b "%RELEASE_DIR%\*.exe"
  exit /b 1
)

echo [4/5] Assemble portable folder
copy /Y "%APP_EXE%" "%PORTABLE_DIR%\Stirling-PDF.exe" >nul

if exist "%RELEASE_DIR%\resources" (
  xcopy "%RELEASE_DIR%\resources" "%PORTABLE_DIR%\resources\" /E /I /Y >nul
)

if exist "%RELEASE_DIR%\*.dll" copy /Y "%RELEASE_DIR%\*.dll" "%PORTABLE_DIR%\" >nul

for %%F in (icudtl.dat snapshot_blob.bin v8_context_snapshot.bin vk_swiftshader.dll vk_swiftshader_icd.json) do (
  if exist "%RELEASE_DIR%\%%F" copy /Y "%RELEASE_DIR%\%%F" "%PORTABLE_DIR%\" >nul
)

if not exist "%PORTABLE_DIR%\resources" mkdir "%PORTABLE_DIR%\resources"
if not exist "%PORTABLE_DIR%\resources\libs" mkdir "%PORTABLE_DIR%\resources\libs"
if not exist "%PORTABLE_DIR%\resources\runtime" mkdir "%PORTABLE_DIR%\resources\runtime"

if exist "%FRONTEND_DIR%\src-tauri\libs" (
  xcopy "%FRONTEND_DIR%\src-tauri\libs" "%PORTABLE_DIR%\resources\libs\" /E /I /Y >nul
)
if exist "%FRONTEND_DIR%\src-tauri\runtime" (
  xcopy "%FRONTEND_DIR%\src-tauri\runtime" "%PORTABLE_DIR%\resources\runtime\" /E /I /Y >nul
)

(
  echo @echo off
  echo setlocal EnableExtensions
  echo set "SCRIPT_DIR=%%~dp0"
  echo set "PORTABLE_DATA=%%SCRIPT_DIR%%data"
  echo set "APPDATA=%%PORTABLE_DATA%%\AppData\Roaming"
  echo set "LOCALAPPDATA=%%PORTABLE_DATA%%\AppData\Local"
  echo set "PROGRAMDATA=%%PORTABLE_DATA%%\ProgramData"
  echo set "WEBVIEW2_USER_DATA_FOLDER=%%PORTABLE_DATA%%\WebView2"
  echo if not exist "%%APPDATA%%" mkdir "%%APPDATA%%"
  echo if not exist "%%LOCALAPPDATA%%" mkdir "%%LOCALAPPDATA%%"
  echo if not exist "%%PROGRAMDATA%%" mkdir "%%PROGRAMDATA%%"
  echo if not exist "%%WEBVIEW2_USER_DATA_FOLDER%%" mkdir "%%WEBVIEW2_USER_DATA_FOLDER%%"
  echo start "" "%%SCRIPT_DIR%%Stirling-PDF.exe"
) > "%PORTABLE_DIR%\Start-Stirling-PDF.bat"

if not exist "%PORTABLE_ROOT%" mkdir "%PORTABLE_ROOT%"
if exist "%ZIP_FILE%" del /f /q "%ZIP_FILE%"

echo [5/5] Create zip package
powershell -NoProfile -Command "Compress-Archive -Path '%PORTABLE_DIR%\*' -DestinationPath '%ZIP_FILE%' -Force" >nul
if errorlevel 1 (
  echo ERROR: failed to create zip archive.
  exit /b 1
)

echo.
echo DONE
echo Portable folder: %PORTABLE_DIR%
echo Portable zip:    %ZIP_FILE%
echo.
echo Local-only mode is enabled. Desktop setup wizard, login flow, and SaaS routing are disabled.
echo App data and WebView2 user data will be written under portable\data.

exit /b 0
