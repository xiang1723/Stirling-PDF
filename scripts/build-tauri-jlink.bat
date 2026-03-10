@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Build script for Tauri with JLink runtime bundling
REM This script creates a self-contained Java runtime for Stirling-PDF

echo [INFO] Building Stirling-PDF with JLink runtime for Tauri...

echo [INFO] Checking Java environment...
java -version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Java is not installed or not in PATH
    exit /b 1
)

jlink --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] jlink is not available. Please ensure you have a JDK (not just JRE) installed.
    exit /b 1
)

echo [INFO] Checking Java version...
set "JAVA_VERSION_STRING="
for /f "tokens=3" %%g in ('java -version 2^>^&1 ^| findstr /i "version"') do (
    set "JAVA_VERSION_STRING=%%g"
)
if not defined JAVA_VERSION_STRING (
    echo [ERROR] Unable to capture Java version string from "java -version"
    exit /b 1
)
set "JAVA_VERSION_STRING=%JAVA_VERSION_STRING:"=%"
set "JAVA_MAJOR_VERSION="
set "JAVA_MINOR_VERSION=0"
set "JAVA_EFFECTIVE_MAJOR="
for /f "tokens=1,2 delims=." %%a in ("%JAVA_VERSION_STRING%") do (
    set "JAVA_MAJOR_VERSION=%%a"
    set "JAVA_MINOR_VERSION=%%b"
    if "%%a"=="1" (
        set "JAVA_EFFECTIVE_MAJOR=%%b"
    ) else (
        set "JAVA_EFFECTIVE_MAJOR=%%a"
    )
)
if not defined JAVA_MAJOR_VERSION (
    echo [ERROR] Unable to determine Java major version from "%JAVA_VERSION_STRING%"
    exit /b 1
)
if not defined JAVA_EFFECTIVE_MAJOR (
    echo [ERROR] Unable to determine an effective Java major version from "%JAVA_VERSION_STRING%"
    exit /b 1
)
for /f "tokens=1 delims=.-" %%c in ("%JAVA_EFFECTIVE_MAJOR%") do set "JAVA_EFFECTIVE_MAJOR=%%c"
set /a "JAVA_EFFECTIVE_MAJOR_NUM=%JAVA_EFFECTIVE_MAJOR%" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Java major version "%JAVA_EFFECTIVE_MAJOR%" could not be parsed as an integer. Detected string: "%JAVA_VERSION_STRING%"
    exit /b 1
)
set "JAVA_EFFECTIVE_MAJOR=%JAVA_EFFECTIVE_MAJOR_NUM%"
if %JAVA_EFFECTIVE_MAJOR% LSS 21 (
    echo [ERROR] Java 21 or higher is required. Found Java %JAVA_EFFECTIVE_MAJOR%
    exit /b 1
)
echo [OK] Java %JAVA_EFFECTIVE_MAJOR% and jlink detected

echo [INFO] Building Stirling-PDF JAR...

set "DISABLE_ADDITIONAL_FEATURES=true"
call gradlew.bat clean bootJar --no-daemon
if errorlevel 1 (
    echo [ERROR] Failed to build Stirling-PDF JAR
    exit /b 1
)

REM Find the built JAR(s)
echo [INFO] Listing all built JAR files in app\core\build\libs:
dir /b app\core\build\libs\stirling-pdf-*.jar
for %%f in (app\core\build\libs\stirling-pdf-*.jar) do set "STIRLING_JAR=%%f"
if not exist "%STIRLING_JAR%" (
    echo [ERROR] No Stirling-PDF JAR found in app\core\build\libs
    exit /b 1
)

echo [OK] Built JAR: %STIRLING_JAR%

echo [INFO] Creating Tauri directories...
if not exist "frontend\src-tauri\libs" mkdir "frontend\src-tauri\libs"
if not exist "frontend\src-tauri\runtime" mkdir "frontend\src-tauri\runtime"

echo [INFO] Copying JAR to Tauri libs directory...
copy "%STIRLING_JAR%" "frontend\src-tauri\libs\" >nul
echo [OK] JAR copied to frontend\src-tauri\libs

REM Log all JAR files now in the Tauri libs directory
echo [INFO] Listing all JAR files in frontend\src-tauri\libs after copy:
dir /b frontend\src-tauri\libs\stirling-pdf-*.jar

echo [INFO] Creating custom JRE with jlink...
if exist "frontend\src-tauri\runtime\jre" rmdir /s /q "frontend\src-tauri\runtime\jre"

REM Use predefined module list for Windows (jdeps may not be available)
set "MODULES=java.base,java.compiler,java.desktop,java.instrument,java.logging,java.management,java.naming,java.net.http,java.prefs,java.rmi,java.scripting,java.security.jgss,java.security.sasl,java.sql,java.transaction.xa,java.xml,java.xml.crypto,jdk.crypto.ec,jdk.crypto.cryptoki,jdk.unsupported"

echo [INFO] Creating JLink runtime with modules: %MODULES%

jlink ^
    --add-modules %MODULES% ^
    --strip-debug ^
    --compress=2 ^
    --no-header-files ^
    --no-man-pages ^
    --output "frontend\src-tauri\runtime\jre"

if not exist "frontend\src-tauri\runtime\jre" (
    echo [ERROR] Failed to create JLink runtime
    exit /b 1
)

echo [OK] JLink runtime created at frontend\src-tauri\runtime\jre

echo [INFO] Creating launcher scripts for testing...

REM Create Windows launcher script
echo @echo off > "frontend\src-tauri\runtime\launch-stirling.bat"
echo REM Launcher script for Stirling-PDF with bundled JRE >> "frontend\src-tauri\runtime\launch-stirling.bat"
echo. >> "frontend\src-tauri\runtime\launch-stirling.bat"
echo set SCRIPT_DIR=%%~dp0 >> "frontend\src-tauri\runtime\launch-stirling.bat"
echo set JRE_DIR=%%SCRIPT_DIR%%jre >> "frontend\src-tauri\runtime\launch-stirling.bat"
echo set LIBS_DIR=%%SCRIPT_DIR%%..\libs >> "frontend\src-tauri\runtime\launch-stirling.bat"
echo. >> "frontend\src-tauri\runtime\launch-stirling.bat"
echo REM Find the Stirling-PDF JAR >> "frontend\src-tauri\runtime\launch-stirling.bat"
echo for %%%%f in ("%%LIBS_DIR%%\Stirling-PDF-*.jar") do set STIRLING_JAR=%%%%f >> "frontend\src-tauri\runtime\launch-stirling.bat"
echo. >> "frontend\src-tauri\runtime\launch-stirling.bat"
echo if not exist "%%STIRLING_JAR%%" ^( >> "frontend\src-tauri\runtime\launch-stirling.bat"
echo     echo [ERROR] Stirling-PDF JAR not found in %%LIBS_DIR%% >> "frontend\src-tauri\runtime\launch-stirling.bat"
echo     exit /b 1 >> "frontend\src-tauri\runtime\launch-stirling.bat"
echo ^) >> "frontend\src-tauri\runtime\launch-stirling.bat"
echo. >> "frontend\src-tauri\runtime\launch-stirling.bat"
echo REM Launch with bundled JRE >> "frontend\src-tauri\runtime\launch-stirling.bat"
echo "%%JRE_DIR%%\bin\java.exe" ^^ >> "frontend\src-tauri\runtime\launch-stirling.bat"
echo     -Xmx2g ^^ >> "frontend\src-tauri\runtime\launch-stirling.bat"
echo     -DBROWSER_OPEN=true ^^ >> "frontend\src-tauri\runtime\launch-stirling.bat"
echo     -jar "%%STIRLING_JAR%%" ^^ >> "frontend\src-tauri\runtime\launch-stirling.bat"
echo     %%* >> "frontend\src-tauri\runtime\launch-stirling.bat"

echo [OK] Created launcher scripts for testing

echo [INFO] Testing bundled JRE...
"frontend\src-tauri\runtime\jre\bin\java.exe" --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Bundled JRE test failed
    exit /b 1
) else (
    echo [OK] Bundled JRE works correctly
)

echo.
echo [OK] JLink build setup completed successfully
echo.
echo [INFO] Summary:
echo    - JAR: %STIRLING_JAR%
echo    - Runtime: frontend\src-tauri\runtime\jre
echo    - Modules: %MODULES%
echo.
echo [INFO] Next steps:
echo    1. cd frontend
echo    2. npm run tauri-build
echo.
echo [INFO] Testing:
echo    - Test bundled runtime: frontend\src-tauri\runtime\launch-stirling.bat
echo    - Tauri configuration already updated to include bundled JRE
echo.
echo [INFO] Benefits:
echo    - No external JRE dependency
echo    - Smaller distribution size with custom runtime
echo    - Better security with minimal required modules
echo    - Consistent Java version across all deployments
echo.
echo [OK] The application will now run without requiring users to install Java

exit /b 0
