@echo off
setlocal EnableExtensions EnableDelayedExpansion

for %%I in ("%~dp0..") do set "ROOT_DIR=%%~fI"
set "FRONTEND_DIR=%ROOT_DIR%\frontend"
set "FAILED=0"

echo [Prereq] Checking Windows portable build prerequisites...

call :check_cmd java "Java runtime (JDK 21+ required)"
call :check_cmd jlink "jlink (must come from JDK, not JRE)"
call :check_cmd node "Node.js"
call :check_cmd npm "npm"
call :check_cmd rustc "Rust compiler"
call :check_cmd cargo "Cargo"
call :check_cmd powershell "PowerShell"

if not exist "%ROOT_DIR%\gradlew.bat" (
  echo [FAIL] gradlew.bat not found at %ROOT_DIR%
  set "FAILED=1"
) else (
  echo [ OK ] gradlew.bat found
)

if not exist "%FRONTEND_DIR%\package.json" (
  echo [FAIL] frontend\package.json not found at %FRONTEND_DIR%
  set "FAILED=1"
) else (
  echo [ OK ] frontend\package.json found
)

if not exist "%FRONTEND_DIR%\node_modules" (
  echo [FAIL] frontend\node_modules missing. Run: cd frontend ^&^& npm install
  set "FAILED=1"
) else (
  echo [ OK ] frontend\node_modules found
)

set "HAS_TAURI_BIN=0"
if exist "%FRONTEND_DIR%\node_modules\.bin\tauri.cmd" set "HAS_TAURI_BIN=1"
if exist "%FRONTEND_DIR%\node_modules\.bin\tauri" set "HAS_TAURI_BIN=1"
if "%HAS_TAURI_BIN%"=="1" (
  echo [ OK ] Tauri CLI found in frontend\node_modules\.bin
) else (
  echo [FAIL] Tauri CLI binary missing in frontend\node_modules\.bin. Run: cd frontend ^&^& npm install
  set "FAILED=1"
)

call :check_java_major

where cl >nul 2>&1
if errorlevel 1 (
  echo [WARN] MSVC cl.exe not found in PATH. Open "x64 Native Tools Command Prompt for VS" or install Visual Studio Build Tools.
) else (
  echo [ OK ] MSVC cl.exe found
)

where link >nul 2>&1
if errorlevel 1 (
  echo [WARN] MSVC link.exe not found in PATH. Open "x64 Native Tools Command Prompt for VS" or install Visual Studio Build Tools.
) else (
  echo [ OK ] MSVC link.exe found
)

echo.
if "%FAILED%"=="0" (
  echo [PASS] Prerequisite check passed.
  exit /b 0
) else (
  echo [FAIL] Prerequisite check failed.
  exit /b 1
)

:check_cmd
set "CMD=%~1"
set "DESC=%~2"
where "%CMD%" >nul 2>&1
if errorlevel 1 (
  echo [FAIL] %DESC% - command not found: %CMD%
  set "FAILED=1"
) else (
  echo [ OK ] %DESC%
)
exit /b 0

:check_java_major
set "JAVA_VERSION_STRING="
for /f "tokens=3" %%g in ('java -version 2^>^&1 ^| findstr /i "version"') do (
  set "JAVA_VERSION_STRING=%%g"
)

if not defined JAVA_VERSION_STRING (
  echo [FAIL] Unable to parse Java version from "java -version"
  set "FAILED=1"
  exit /b 0
)

set "JAVA_VERSION_STRING=%JAVA_VERSION_STRING:"=%"
set "JAVA_MAJOR_VERSION="
set "JAVA_EFFECTIVE_MAJOR="
for /f "tokens=1,2 delims=." %%a in ("%JAVA_VERSION_STRING%") do (
  set "JAVA_MAJOR_VERSION=%%a"
  if "%%a"=="1" (
    set "JAVA_EFFECTIVE_MAJOR=%%b"
  ) else (
    set "JAVA_EFFECTIVE_MAJOR=%%a"
  )
)

if not defined JAVA_EFFECTIVE_MAJOR (
  echo [FAIL] Unable to determine Java major version from "%JAVA_VERSION_STRING%"
  set "FAILED=1"
  exit /b 0
)

for /f "tokens=1 delims=.-" %%c in ("%JAVA_EFFECTIVE_MAJOR%") do set "JAVA_EFFECTIVE_MAJOR=%%c"
set /a "JAVA_EFFECTIVE_MAJOR_NUM=%JAVA_EFFECTIVE_MAJOR%" >nul 2>&1
if errorlevel 1 (
  echo [FAIL] Java major version "%JAVA_EFFECTIVE_MAJOR%" is not numeric
  set "FAILED=1"
  exit /b 0
)

set "JAVA_EFFECTIVE_MAJOR=%JAVA_EFFECTIVE_MAJOR_NUM%"
if %JAVA_EFFECTIVE_MAJOR% LSS 21 (
  echo [FAIL] Java 21 or newer required. Detected: %JAVA_EFFECTIVE_MAJOR%
  set "FAILED=1"
) else (
  echo [ OK ] Java version check passed (detected %JAVA_EFFECTIVE_MAJOR%)
)
exit /b 0
