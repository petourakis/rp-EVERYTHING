@echo off
SETLOCAL EnableDelayedExpansion

echo === EnergiBridge Static Analysis Experiment Runner ===
echo WITH VULNERABILITY TRACKING
echo.

:: --------------------------------------------
:: Force JDK 17 for this experiment 
:: --------------------------------------------

set "JAVA_HOME=C:\Program Files\Java\jdk-17"
set "PATH=%JAVA_HOME%\bin;%PATH%"

echo Using JAVA_HOME=%JAVA_HOME%
java -version
set RUST_BACKTRACE=full
echo.

:: --------------------------------------------
:: Ask user which project to run
:: --------------------------------------------
set "PROJECTS_DIR=%~dp0\brp-sustainability\projects"

echo Available projects:
for /d %%P in ("%PROJECTS_DIR%\*") do echo   %%~nxP
echo.

set /p PROJECT="Enter project name: "

set "BASE_DIR=%PROJECTS_DIR%\%PROJECT%"

if not exist "%BASE_DIR%" (
    echo ERROR: Project directory not found: %BASE_DIR%
    pause
    exit /b
)

:: --------------------------------------------
:: Detect build tool and project-specific commands
:: --------------------------------------------
if exist "%BASE_DIR%\pom.xml" (
    set BUILD_TOOL=maven
) else if exist "%BASE_DIR%\gradlew.bat" (
    set BUILD_TOOL=gradle
) else (
    echo ERROR: No pom.xml or gradlew.bat in %BASE_DIR%
    pause
    exit /b
)

echo Detected build tool: %BUILD_TOOL%

:: Check if this is Spring Boot (needs special Gradle flags)
set IS_SPRING_BOOT=0
if /i "%PROJECT%"=="spring-boot" set IS_SPRING_BOOT=1

if %IS_SPRING_BOOT%==1 (
    echo Detected Spring Boot - using special compile exclusions
)
echo.

:: --------------------------------------------
:: EnergiBridge path
:: --------------------------------------------
set "ENERGIBRIDGE_EXE=%~dp0energibridge.exe"

if not exist "%ENERGIBRIDGE_EXE%" (
    echo ERROR: energibridge.exe not found in script directory.
    pause
    exit /b
)

:: --------------------------------------------
:: Define correct full paths for build tools
:: --------------------------------------------
set "MAVEN_CMD=%~dp0apache-maven-3.8.6\bin\mvn.cmd"
set "GRADLE_CMD=%BASE_DIR%\gradlew.bat"

:: --------------------------------------------
:: Experiment parameters
:: --------------------------------------------
set NUM_PER_CONFIG=30
set TOTAL_RUNS=90
set COOLDOWN_SECONDS=60

:: ============================================
:: CRITICAL FIX: Separate configs for Maven vs Gradle
:: ============================================

:: Maven uses -D (system properties)
:: Gradle uses -P (project properties)

:: MAVEN CONFIGS (use -D)
set MAVEN_CONFIG_A=-Pspotbugs -e -Dspotbugs.includePlugins=com.h3xstream.findsecbugs:findsecbugs-plugin:1.12.0
set MAVEN_CONFIG_B=-Pspotbugs -e -Dspotbugs.effort=max -Dspotbugs.includePlugins=com.h3xstream.findsecbugs:findsecbugs-plugin:1.12.0
set MAVEN_CONFIG_C=-Pspotbugs -e -Dspotbugs.threshold=Low -Dspotbugs.includePlugins=com.h3xstream.findsecbugs:findsecbugs-plugin:1.12.0

:: GRADLE CONFIGS (use -P, and FSB is in build.gradle already)
:: NOTE: For Gradle, FSB is configured in build.gradle, so we don't pass it here
set GRADLE_CONFIG_A=
set GRADLE_CONFIG_B=-Pspotbugs.effort=max
set GRADLE_CONFIG_C=-Pspotbugs.reportLevel=low

set CountA=0
set CountB=0
set CountC=0
set OverallRun=1

:: --------------------------------------------
:: Output directory
:: --------------------------------------------
for /f "tokens=2 delims==" %%I in ('WMIC OS GET LocalDateTime /VALUE') do set dt=%%I
set SESSION_TIMESTAMP=%dt:~0,4%%dt:~4,2%%dt:~6,2%_%dt:~8,2%%dt:~10,2%%dt:~12,2%
set "OUTPUT_DIR=%~dp0results\session_%SESSION_TIMESTAMP%"
mkdir "%OUTPUT_DIR%" >nul 2>&1

:: Create subdirectory for problems reports
set "PROBLEMS_BACKUP_DIR=%OUTPUT_DIR%\problems_reports"
mkdir "%PROBLEMS_BACKUP_DIR%" >nul 2>&1

echo Output: %OUTPUT_DIR%
echo Problems reports will be backed up to: %PROBLEMS_BACKUP_DIR%
echo.

:: Create vulnerability tracking file
echo Run,Config,Project,BuildTool,BugCount,Status > "%OUTPUT_DIR%\vulnerability_summary.csv"

:: --------------------------------------------
:: Main loop
:: --------------------------------------------
:LOOP
if %OverallRun% GTR %TOTAL_RUNS% goto END

:: Choose random config
set /A pick=(%RANDOM% %% 3) + 1
if %pick%==1 set CurrentConfig=A
if %pick%==2 set CurrentConfig=B
if %pick%==3 set CurrentConfig=C

:: Set CURRENT_ARGS based on build tool
if "%BUILD_TOOL%"=="maven" (
    call set CURRENT_ARGS=%%MAVEN_CONFIG_%CurrentConfig%%%
) else (
    call set CURRENT_ARGS=%%GRADLE_CONFIG_%CurrentConfig%%%
)

if %CurrentConfig%==A set CURRENT_COUNT=%CountA%
if %CurrentConfig%==B set CURRENT_COUNT=%CountB%
if %CurrentConfig%==C set CURRENT_COUNT=%CountC%

if %CURRENT_COUNT% GEQ %NUM_PER_CONFIG% goto LOOP

echo Run %OverallRun% / %TOTAL_RUNS%   Config %CurrentConfig%  Count=%CURRENT_COUNT%

set "CSV_OUT=%OUTPUT_DIR%\run_%OverallRun%_config_%CurrentConfig%.csv"

pushd "%BASE_DIR%"

:: -------------------------------------------------
:: MAVEN COMMAND
:: -------------------------------------------------
if "%BUILD_TOOL%"=="maven" (

    echo [MAVEN] Running: spotbugs:spotbugs %CURRENT_ARGS%
    
    "%ENERGIBRIDGE_EXE%" -i 200 -o "%CSV_OUT%" --summary "%MAVEN_CMD%" ^
        spotbugs:spotbugs ^
        %CURRENT_ARGS%

    set ERR=!ERRORLEVEL!
    
    REM Extract bug count from Maven SpotBugs XML report
    set BUG_COUNT=0
    if exist "target\spotbugsXml.xml" (
        REM Count BugInstance elements in the XML file
        for /f %%A in ('powershell -Command "(Select-String -Path 'target\spotbugsXml.xml' -Pattern '<BugInstance' -AllMatches).Matches.Count"') do set BUG_COUNT=%%A
    )

) else (

:: -------------------------------------------------
:: GRADLE COMMAND
:: -------------------------------------------------
    if %IS_SPRING_BOOT%==1 (
        echo [GRADLE/SPRING-BOOT] Running: spotbugsMain spotbugsTest %CURRENT_ARGS%
        
        REM Spring Boot projects need to skip compile tasks
        "%ENERGIBRIDGE_EXE%" -i 200 -o "%CSV_OUT%" --summary "%GRADLE_CMD%" ^
            spotbugsMain spotbugsTest ^
            -x compileJava -x compileTestJava -x compileTestFixturesJava ^
            -x compileKotlin -x compileTestKotlin -e ^
            %CURRENT_ARGS%
    ) else (
        echo [GRADLE] Running: spotbugsMain spotbugsTest %CURRENT_ARGS%
        
        REM Regular Gradle projects
        "%ENERGIBRIDGE_EXE%" -i 200 -o "%CSV_OUT%" --summary "%GRADLE_CMD%" ^
            spotbugsMain spotbugsTest ^
            %CURRENT_ARGS%
    )
    
    set ERR=!ERRORLEVEL!
    
    REM Extract bug count from Gradle SpotBugs XML report
    set BUG_COUNT=0
    REM Gradle reports are in build/reports/spotbugs/main.xml or similar
    if exist "build\reports\spotbugs\main.xml" (
        for /f %%A in ('powershell -Command "(Select-String -Path 'build\reports\spotbugs\main.xml' -Pattern '<BugInstance' -AllMatches).Matches.Count"') do set BUG_COUNT=%%A
    )
    
    REM Also check for test report
    set TEST_BUG_COUNT=0
    if exist "build\reports\spotbugs\test.xml" (
        for /f %%A in ('powershell -Command "(Select-String -Path 'build\reports\spotbugs\test.xml' -Pattern '<BugInstance' -AllMatches).Matches.Count"') do set TEST_BUG_COUNT=%%A
    )
    
    REM Add test bugs to total
    set /A BUG_COUNT=!BUG_COUNT! + !TEST_BUG_COUNT!
)

:: -------------------------------------------------
:: BACKUP PROBLEMS REPORT HTML
:: -------------------------------------------------
REM Get current timestamp for this specific run
for /f "tokens=2 delims==" %%I in ('WMIC OS GET LocalDateTime /VALUE') do set run_dt=%%I
set RUN_TIMESTAMP=%run_dt:~0,4%%run_dt:~4,2%%run_dt:~6,2%_%run_dt:~8,2%%run_dt:~10,2%%run_dt:~12,2%

REM Check if problems-report.html exists and back it up
if exist "build\reports\problems\problems-report.html" (
    set "PROBLEMS_BACKUP=%PROBLEMS_BACKUP_DIR%\problems-report_run%OverallRun%_config%CurrentConfig%_%RUN_TIMESTAMP%.html"
    copy "build\reports\problems\problems-report.html" "!PROBLEMS_BACKUP!" >nul 2>&1
    if !ERRORLEVEL! EQU 0 (
        echo [INFO] Problems report backed up to: problems-report_run%OverallRun%_config%CurrentConfig%_%RUN_TIMESTAMP%.html
    )
)

popd

REM Log vulnerability count
if NOT "!ERR!"=="0" (
    echo [WARNING] Run %OverallRun% failed with error !ERR!
    echo Run %OverallRun%,Config %CurrentConfig%,Error !ERR! >> "%OUTPUT_DIR%\failed_runs.log"
    echo %OverallRun%,%CurrentConfig%,%PROJECT%,%BUILD_TOOL%,N/A,FAILED >> "%OUTPUT_DIR%\vulnerability_summary.csv"
    REM Don't increment config counter - this config still needs this run
) else (
    echo [INFO] Bugs found: !BUG_COUNT!
    echo %OverallRun%,%CurrentConfig%,%PROJECT%,%BUILD_TOOL%,!BUG_COUNT!,SUCCESS >> "%OUTPUT_DIR%\vulnerability_summary.csv"
    
    REM Only increment config counters on success
    if %CurrentConfig%==A set /A CountA+=1
    if %CurrentConfig%==B set /A CountB+=1
    if %CurrentConfig%==C set /A CountC+=1
)

REM Always increment overall run counter
set /A OverallRun+=1

:: Cooldown
if %OverallRun% LEQ %TOTAL_RUNS% (
    echo Waiting %COOLDOWN_SECONDS% seconds...
    timeout /T %COOLDOWN_SECONDS% /NOBREAK >nul
)

goto LOOP

:END
echo ==========================================
echo Experiment complete!
echo Total runs attempted: %TOTAL_RUNS%
echo Config A: %CountA% successful runs
echo Config B: %CountB% successful runs
echo Config C: %CountC% successful runs
if exist "%OUTPUT_DIR%\failed_runs.log" (
    echo.
    echo WARNING: Some runs failed. Check failed_runs.log
)
echo.
echo Vulnerability data saved to: vulnerability_summary.csv
echo Problems reports backed up to: %PROBLEMS_BACKUP_DIR%
echo ==========================================
pause
ENDLOCAL