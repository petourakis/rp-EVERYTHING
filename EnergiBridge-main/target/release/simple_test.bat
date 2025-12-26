@echo off
SETLOCAL EnableDelayedExpansion

echo ========================================
echo Simple Test - Each Project Once
echo Using paths from your original script
echo ========================================
echo.

:: --------------------------------------------
:: Paths (matching your original script)
:: --------------------------------------------
set "SCRIPT_DIR=%~dp0"
set "PROJECTS_DIR=%SCRIPT_DIR%brp-sustainability\projects"
set "MAVEN_CMD=%SCRIPT_DIR%apache-maven-3.8.6\bin\mvn.cmd"

echo Script directory: %SCRIPT_DIR%
echo Projects directory: %PROJECTS_DIR%
echo Maven command: %MAVEN_CMD%
echo.

:: --------------------------------------------
:: Verify paths exist
:: --------------------------------------------
echo Checking paths...

if not exist "%PROJECTS_DIR%" (
    echo.
    echo ERROR: Projects directory not found!
    echo Expected: %PROJECTS_DIR%
    echo.
    echo Please check:
    echo 1. Are you running this from the correct directory?
    echo 2. Is the brp-sustainability folder in the same directory as this script?
    echo.
    pause
    exit /b 1
)
echo ✓ Projects directory found

if not exist "%MAVEN_CMD%" (
    echo.
    echo ERROR: Maven not found!
    echo Expected: %MAVEN_CMD%
    echo.
    echo Please check:
    echo 1. Is apache-maven-3.8.6 folder in the same directory as this script?
    echo.
    pause
    exit /b 1
)
echo ✓ Maven found
echo.

:: --------------------------------------------
:: Force JDK 17
:: --------------------------------------------
set "JAVA_HOME=C:\Program Files\Java\jdk-17"
set "PATH=%JAVA_HOME%\bin;%PATH%"

echo Checking Java...
java -version 2>&1 | findstr "version"
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Java not found or not working
    echo Make sure JDK 17 is installed at: %JAVA_HOME%
    pause
    exit /b 1
)
echo ✓ Java OK
echo.

:: --------------------------------------------
:: Output directory
:: --------------------------------------------
for /f "tokens=2 delims==" %%I in ('WMIC OS GET LocalDateTime /VALUE') do set dt=%%I
set SESSION_TIMESTAMP=%dt:~0,4%%dt:~4,2%%dt:~6,2%_%dt:~8,2%%dt:~10,2%%dt:~12,2%
set "OUTPUT_DIR=%SCRIPT_DIR%results\simple_test_%SESSION_TIMESTAMP%"
mkdir "%OUTPUT_DIR%" >nul 2>&1

echo Output directory: %OUTPUT_DIR%
echo.
echo ==========================================
echo Starting tests...
echo NOTE: Each project may take 5-30 minutes
echo ==========================================
echo.
pause

set PASS_COUNT=0
set FAIL_COUNT=0

:: --------------------------------------------
:: Maven Projects
:: --------------------------------------------
echo.
echo ==========================================
echo Maven Projects (4/10)
echo ==========================================

REM Flink
echo.
echo [1/10] Flink (Maven)
echo ----------------------------------------
echo Directory: %PROJECTS_DIR%\flink
echo Started: %TIME%
echo Running SpotBugs with high effort...
echo (This may take 10-20 minutes)
echo.

if not exist "%PROJECTS_DIR%\flink" (
    echo ERROR: Flink directory not found!
    set /A FAIL_COUNT+=1
    goto :maven2
)

pushd "%PROJECTS_DIR%\flink"
"%MAVEN_CMD%" clean spotbugs:spotbugs -Dspotbugs.effort=max -Dspotbugs.includePlugins=com.h3xstream.findsecbugs:findsecbugs-plugin:1.12.0 > "%OUTPUT_DIR%\flink.log" 2>&1
set RESULT=%ERRORLEVEL%
popd

echo Finished: %TIME%
if !RESULT! EQU 0 (
    echo ✓ PASS
    set /A PASS_COUNT+=1
) else (
    echo ✗ FAIL (Error: !RESULT!) - Check flink.log
    set /A FAIL_COUNT+=1
)

:maven2
REM Maven
echo.
echo [2/10] Maven (Maven)
echo ----------------------------------------
echo Directory: %PROJECTS_DIR%\maven
echo Started: %TIME%
echo (This may take 5-10 minutes)
echo.

if not exist "%PROJECTS_DIR%\maven" (
    echo ERROR: Maven directory not found!
    set /A FAIL_COUNT+=1
    goto :maven3
)

pushd "%PROJECTS_DIR%\maven"
"%MAVEN_CMD%" clean spotbugs:spotbugs -Dspotbugs.effort=max -Dspotbugs.includePlugins=com.h3xstream.findsecbugs:findsecbugs-plugin:1.12.0 > "%OUTPUT_DIR%\maven.log" 2>&1
set RESULT=%ERRORLEVEL%
popd

echo Finished: %TIME%
if !RESULT! EQU 0 (
    echo ✓ PASS
    set /A PASS_COUNT+=1
) else (
    echo ✗ FAIL (Error: !RESULT!) - Check maven.log
    set /A FAIL_COUNT+=1
)

:maven3
REM SeaTunnel
echo.
echo [3/10] SeaTunnel (Maven)
echo ----------------------------------------
echo Directory: %PROJECTS_DIR%\SeaTunnel
echo Started: %TIME%
echo (This may take 5-10 minutes)
echo.

if not exist "%PROJECTS_DIR%\SeaTunnel" (
    echo ERROR: SeaTunnel directory not found!
    set /A FAIL_COUNT+=1
    goto :maven4
)

pushd "%PROJECTS_DIR%\SeaTunnel"
"%MAVEN_CMD%" clean spotbugs:spotbugs -Dspotbugs.effort=max -Dspotbugs.includePlugins=com.h3xstream.findsecbugs:findsecbugs-plugin:1.12.0 > "%OUTPUT_DIR%\seatunnel.log" 2>&1
set RESULT=%ERRORLEVEL%
popd

echo Finished: %TIME%
if !RESULT! EQU 0 (
    echo ✓ PASS
    set /A PASS_COUNT+=1
) else (
    echo ✗ FAIL (Error: !RESULT!) - Check seatunnel.log
    set /A FAIL_COUNT+=1
)

:maven4
REM Guava
echo.
echo [4/10] Guava (Maven)
echo ----------------------------------------
echo Directory: %PROJECTS_DIR%\guava
echo Started: %TIME%
echo (This may take 3-5 minutes)
echo.

if not exist "%PROJECTS_DIR%\guava" (
    echo ERROR: Guava directory not found!
    set /A FAIL_COUNT+=1
    goto :gradle_start
)

pushd "%PROJECTS_DIR%\guava"
"%MAVEN_CMD%" clean spotbugs:spotbugs -Dspotbugs.effort=max -Dspotbugs.includePlugins=com.h3xstream.findsecbugs:findsecbugs-plugin:1.12.0 > "%OUTPUT_DIR%\guava.log" 2>&1
set RESULT=%ERRORLEVEL%
popd

echo Finished: %TIME%
if !RESULT! EQU 0 (
    echo ✓ PASS
    set /A PASS_COUNT+=1
) else (
    echo ✗ FAIL (Error: !RESULT!) - Check guava.log
    set /A FAIL_COUNT+=1
)

:: --------------------------------------------
:: Gradle Projects
:: --------------------------------------------
:gradle_start
echo.
echo ==========================================
echo Gradle Projects (6/10)
echo ==========================================

REM cruise-control
echo.
echo [5/10] cruise-control (Gradle)
echo ----------------------------------------
echo Directory: %PROJECTS_DIR%\cruise-control
echo Started: %TIME%
echo (This may take 5-8 minutes)
echo.

if not exist "%PROJECTS_DIR%\cruise-control" (
    echo ERROR: cruise-control directory not found!
    set /A FAIL_COUNT+=1
    goto :gradle2
)

pushd "%PROJECTS_DIR%\cruise-control"
if not exist "gradlew.bat" (
    echo ERROR: gradlew.bat not found!
    set /A FAIL_COUNT+=1
    popd
    goto :gradle2
)

call gradlew.bat --no-daemon clean spotbugsMain -Pspotbugs.effort=max > "%OUTPUT_DIR%\cruise-control.log" 2>&1
set RESULT=%ERRORLEVEL%
popd

echo Finished: %TIME%
if !RESULT! EQU 0 (
    echo ✓ PASS
    set /A PASS_COUNT+=1
) else (
    echo ✗ FAIL (Error: !RESULT!) - Check cruise-control.log
    set /A FAIL_COUNT+=1
)

:gradle2
REM elasticsearch
echo.
echo [6/10] elasticsearch (Gradle)
echo ----------------------------------------
echo Directory: %PROJECTS_DIR%\elasticsearch
echo Started: %TIME%
echo (This may take 15-30 minutes - LARGE PROJECT)
echo.

if not exist "%PROJECTS_DIR%\elasticsearch" (
    echo ERROR: elasticsearch directory not found!
    set /A FAIL_COUNT+=1
    goto :gradle3
)

pushd "%PROJECTS_DIR%\elasticsearch"
if not exist "gradlew.bat" (
    echo ERROR: gradlew.bat not found!
    set /A FAIL_COUNT+=1
    popd
    goto :gradle3
)

call gradlew.bat --no-daemon clean spotbugsMain -Pspotbugs.effort=max > "%OUTPUT_DIR%\elasticsearch.log" 2>&1
set RESULT=%ERRORLEVEL%
popd

echo Finished: %TIME%
if !RESULT! EQU 0 (
    echo ✓ PASS
    set /A PASS_COUNT+=1
) else (
    echo ✗ FAIL (Error: !RESULT!) - Check elasticsearch.log
    set /A FAIL_COUNT+=1
)

:gradle3
REM junit-framework
echo.
echo [7/10] junit-framework (Gradle)
echo ----------------------------------------
echo Directory: %PROJECTS_DIR%\junit-framework
echo Started: %TIME%
echo (This may take 3-5 minutes)
echo.

if not exist "%PROJECTS_DIR%\junit-framework" (
    echo ERROR: junit-framework directory not found!
    set /A FAIL_COUNT+=1
    goto :gradle4
)

pushd "%PROJECTS_DIR%\junit-framework"
if not exist "gradlew.bat" (
    echo ERROR: gradlew.bat not found!
    set /A FAIL_COUNT+=1
    popd
    goto :gradle4
)

call gradlew.bat --no-daemon clean spotbugsMain -Pspotbugs.effort=max > "%OUTPUT_DIR%\junit-framework.log" 2>&1
set RESULT=%ERRORLEVEL%
popd

echo Finished: %TIME%
if !RESULT! EQU 0 (
    echo ✓ PASS
    set /A PASS_COUNT+=1
) else (
    echo ✗ FAIL (Error: !RESULT!) - Check junit-framework.log
    set /A FAIL_COUNT+=1
)

:gradle4
REM openems
echo.
echo [8/10] openems (Gradle)
echo ----------------------------------------
echo Directory: %PROJECTS_DIR%\openems
echo Started: %TIME%
echo (This may take 8-12 minutes)
echo.

if not exist "%PROJECTS_DIR%\openems" (
    echo ERROR: openems directory not found!
    set /A FAIL_COUNT+=1
    goto :gradle5
)

pushd "%PROJECTS_DIR%\openems"
if not exist "gradlew.bat" (
    echo ERROR: gradlew.bat not found!
    set /A FAIL_COUNT+=1
    popd
    goto :gradle5
)

call gradlew.bat --no-daemon clean spotbugsMain -Pspotbugs.effort=max > "%OUTPUT_DIR%\openems.log" 2>&1
set RESULT=%ERRORLEVEL%
popd

echo Finished: %TIME%
if !RESULT! EQU 0 (
    echo ✓ PASS
    set /A PASS_COUNT+=1
) else (
    echo ✗ FAIL (Error: !RESULT!) - Check openems.log
    set /A FAIL_COUNT+=1
)

:gradle5
REM spring-boot
echo.
echo [9/10] spring-boot (Gradle)
echo ----------------------------------------
echo Directory: %PROJECTS_DIR%\spring-boot
echo Started: %TIME%
echo (This may take 20-40 minutes - VERY LARGE PROJECT)
echo.

if not exist "%PROJECTS_DIR%\spring-boot" (
    echo ERROR: spring-boot directory not found!
    set /A FAIL_COUNT+=1
    goto :gradle6
)

pushd "%PROJECTS_DIR%\spring-boot"
if not exist "gradlew.bat" (
    echo ERROR: gradlew.bat not found!
    set /A FAIL_COUNT+=1
    popd
    goto :gradle6
)

call gradlew.bat --no-daemon clean spotbugsMain -Pspotbugs.effort=max > "%OUTPUT_DIR%\spring-boot.log" 2>&1
set RESULT=%ERRORLEVEL%
popd

echo Finished: %TIME%
if !RESULT! EQU 0 (
    echo ✓ PASS
    set /A PASS_COUNT+=1
) else (
    echo ✗ FAIL (Error: !RESULT!) - Check spring-boot.log
    set /A FAIL_COUNT+=1
)

:gradle6
REM spring-framework
echo.
echo [10/10] spring-framework (Gradle)
echo ----------------------------------------
echo Directory: %PROJECTS_DIR%\spring-framework
echo Started: %TIME%
echo (This may take 15-30 minutes - LARGE PROJECT)
echo.

if not exist "%PROJECTS_DIR%\spring-framework" (
    echo ERROR: spring-framework directory not found!
    set /A FAIL_COUNT+=1
    goto :summary
)

pushd "%PROJECTS_DIR%\spring-framework"
if not exist "gradlew.bat" (
    echo ERROR: gradlew.bat not found!
    set /A FAIL_COUNT+=1
    popd
    goto :summary
)

call gradlew.bat --no-daemon clean spotbugsMain -Pspotbugs.effort=max > "%OUTPUT_DIR%\spring-framework.log" 2>&1
set RESULT=%ERRORLEVEL%
popd

echo Finished: %TIME%
if !RESULT! EQU 0 (
    echo ✓ PASS
    set /A PASS_COUNT+=1
) else (
    echo ✗ FAIL (Error: !RESULT!) - Check spring-framework.log
    set /A FAIL_COUNT+=1
)

:: --------------------------------------------
:: Summary
:: --------------------------------------------
:summary
echo.
echo ==========================================
echo Test Complete!
echo ==========================================
echo.
echo Results:
echo   Passed: %PASS_COUNT% / 10
echo   Failed: %FAIL_COUNT% / 10
echo.
echo Logs saved to: %OUTPUT_DIR%
echo.

if %FAIL_COUNT% EQU 0 (
    echo ✓✓✓ ALL TESTS PASSED! ✓✓✓
    echo You are ready to run the full experiment!
) else (
    echo ✗✗✗ SOME TESTS FAILED ✗✗✗
    echo Check the log files for details
)
echo.

pause
ENDLOCAL
