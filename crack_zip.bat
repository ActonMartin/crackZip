@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: ZIP Password Cracker (John the Ripper)
:: ------------------------------------------------------------
:: Version : 1.1
:: Requires: John the Ripper (jumbo) at .\john\JtR\run
::           Windows PowerShell (built-in on Win7+)
:: Usage   : crack_zip.bat [zip_file_path]
:: Example : crack_zip.bat no1.zip
:: Notes   : Paths resolve relative to this script, so the whole
::           folder can be moved anywhere. Passwords containing
::           ! : & $ etc. are extracted via PowerShell so they
::           display correctly.
:: ============================================================

:: ---- Config ----
:: Paths are resolved relative to this script's location so it works anywhere.
set "WORK_DIR=%~dp0"
if "%WORK_DIR:~-1%"=="\" set "WORK_DIR=%WORK_DIR:~0,-1%"
set "JOHN_DIR=%WORK_DIR%\john\JtR\run"
set "TMP_DIR=%WORK_DIR%\tmp"
if not exist "%TMP_DIR%" mkdir "%TMP_DIR%"
set "FORMAT=PKZIP"
:: FORMAT will be auto-detected: PKZIP for $pkzip$, ZIP for $zip2$ (AES)
:: ----------------

:: Get target ZIP file path
set "ZIP_FILE=%~1"
if "%ZIP_FILE%"=="" (
    set /p "ZIP_FILE=Enter ZIP file path (press Enter for default no1.zip): "
    if "!ZIP_FILE!"=="" set "ZIP_FILE=%WORK_DIR%\no1.zip"
)

:: Remove surrounding quotes if any
set "ZIP_FILE=%ZIP_FILE:"=%"

:: Check file exists
if not exist "%ZIP_FILE%" (
    echo [ERROR] File not found: %ZIP_FILE%
    pause
    exit /b 1
)

:: Verify John the Ripper is present; if not, print setup instructions
set "NEED_SETUP=0"
if not exist "%JOHN_DIR%\john.exe" set "NEED_SETUP=1"
if not exist "%JOHN_DIR%\zip2john.exe" set "NEED_SETUP=1"
if "!NEED_SETUP!"=="1" (
    echo [ERROR] John the Ripper not found.
    echo.
    echo John the Ripper is not bundled with this script. To set it up:
    echo.
    echo   1. Download the Windows build ^(jumbo^) from:
    echo      https://github.com/openwall/john-packages/releases
    echo.
    echo   2. Extract it so that the following files exist:
    echo      %JOHN_DIR%\john.exe
    echo      %JOHN_DIR%\zip2john.exe
    echo.
    echo   3. Re-run this script.
    echo.
    echo Expected layout:
    echo   %WORK_DIR%\
    echo     crack_zip.bat
    echo     john\JtR\run\john.exe
    echo     john\JtR\run\zip2john.exe
    echo.
    pause
    exit /b 1
)

:: Extract filename for session name
for %%F in ("%ZIP_FILE%") do set "ZIP_NAME=%%~nF"
set "HASH_FILE=%TMP_DIR%\hash_!ZIP_NAME!.txt"
set "HASH_CLEAN=%TMP_DIR%\hash_!ZIP_NAME!_clean.txt"
set "RESULT_FILE=%TMP_DIR%\result_!ZIP_NAME!.txt"

echo ============================================================
echo  ZIP Password Cracker
echo ============================================================
echo  Target file : %ZIP_FILE%
echo  Hash file   : %HASH_CLEAN%
echo ============================================================
echo.

:: Step 1: Change to John directory
cd /d "%JOHN_DIR%"
echo [1/5] Working dir: %JOHN_DIR%

:: Step 2: Extract hash (try -c first for checksum-only, fallback to full)
echo [2/5] Extracting hash...
zip2john.exe -c "%ZIP_FILE%" > "%HASH_FILE%" 2>&1
if !errorlevel! NEQ 0 (
    echo [WARN] -c option failed, trying standard mode...
    zip2john.exe "%ZIP_FILE%" > "%HASH_FILE%" 2>&1
)

:: Step 3: Clean (extract hash line - try $zip2$ first, then $pkzip$)
echo [3/5] Cleaning hash file...
findstr /C:"$zip2$" "%HASH_FILE%" > "%HASH_CLEAN%" 2>nul
set "FILE_SIZE=0"
for %%A in ("%HASH_CLEAN%") do set "FILE_SIZE=%%~zA"
if "!FILE_SIZE!"=="0" (
    :: Try $pkzip$ (traditional encryption)
    findstr /C:"$pkzip" "%HASH_FILE%" > "%HASH_CLEAN%" 2>nul
    for %%A in ("%HASH_CLEAN%") do set "FILE_SIZE=%%~zA"
)

:: Verify the hash line was found
if "!FILE_SIZE!"=="0" (
    echo [ERROR] Hash extraction failed! Check if file is encrypted.
    echo.
    echo Raw output:
    type "%HASH_FILE%"
    pause
    exit /b 1
)

:: Auto-detect format: ZIP for AES ($zip2$), PKZIP for traditional ($pkzip$)
findstr /C:"$zip2$" "%HASH_CLEAN%" >nul 2>&1
if !errorlevel! EQU 0 (
    echo       Encryption: WinZip AES (^$zip2$^)
    :: Probe OpenCL: try ZIP-opencl self-test, fall back to CPU ZIP if unavailable
    john.exe --format=ZIP-opencl --test=0 >nul 2>&1
    if !errorlevel! EQU 0 (
        set "FORMAT=ZIP-opencl"
        set "USE_GPU=1"
        echo       Using GPU: YES ^(ZIP-opencl^)
    ) else (
        set "FORMAT=ZIP"
        set "USE_GPU=0"
        echo       Using GPU: NO  ^(OpenCL unavailable, falling back to CPU ZIP^)
    )
) else (
    set "FORMAT=PKZIP"
    set "USE_GPU=0"
    echo       Encryption: Traditional PKZIP (^$pkzip$^)
    echo       Using GPU: NO  ^(CPU only, no OpenCL kernel for PKZIP^)
)
echo       Hash saved: %HASH_CLEAN%
echo       John format: !FORMAT!
echo.

:: Step 4: Select cracking mode
echo [4/5] Select cracking mode:
echo ============================================================
echo   [1]  Digits only            (1-8 chars, 0-9)         Fast
echo   [2]  Digits only            (1-12 chars, 0-9)        Medium
echo   [3]  Lowercase letters      (1-6 chars, a-z)         Fast
echo   [4]  Lowercase + digits      (1-6 chars, a-z0-9)     Medium
echo   [5]  Lower + Upper + digits  (1-6 chars, a-zA-Z0-9)  Slow
echo   [6]  All printable chars     (1-6 chars)              Slow
echo   [7]  Custom mask             (input your own)         User
echo   [8]  Dictionary attack       (password.lst)           Fast
echo   [9]  Custom dictionary       (input dict path)        User
echo  [10]  Incremental mode        (all chars, very slow)   Very Slow
echo  [11]  Phone number             (11 digits)              Fast
echo  [12]  Birthday                 (8 digits YYYYMMDD)      Fast
echo ============================================================
set /p "MODE=Select mode [1-12] (default 1): "
if "!MODE!"=="" set "MODE=1"

:: Validate mode is a number 1-12
set "VALID_MODE=0"
for %%N in (1 2 3 4 5 6 7 8 9 10 11 12) do if "!MODE!"=="%%N" set "VALID_MODE=1"
if "!VALID_MODE!"=="0" (
    echo [ERROR] Invalid mode: "!MODE!"
    pause
    exit /b 1
)

:: Build command based on mode
set "CRACK_CMD="
set "MODE_DESC="

if "!MODE!"=="1"  ( set "CRACK_CMD=--mask=?d --min-length=1 --max-length=8"           & set "MODE_DESC=Digits 1-8" )
if "!MODE!"=="2"  ( set "CRACK_CMD=--mask=?d --min-length=1 --max-length=12"           & set "MODE_DESC=Digits 1-12" )
if "!MODE!"=="3"  ( set "CRACK_CMD=--mask=?l --min-length=1 --max-length=6"            & set "MODE_DESC=Lowercase 1-6" )
if "!MODE!"=="4"  ( set "CRACK_CMD=--mask=?l?d --min-length=1 --max-length=6"          & set "MODE_DESC=Lower+digits 1-6" )
if "!MODE!"=="5"  ( set "CRACK_CMD=--mask=?l?u?d --min-length=1 --max-length=6"        & set "MODE_DESC=Lower+Upper+digits 1-6" )
if "!MODE!"=="6"  ( set "CRACK_CMD=--mask=?a --min-length=1 --max-length=6"            & set "MODE_DESC=All chars 1-6" )
if "!MODE!"=="7"  goto :custom_mask
if "!MODE!"=="8"  ( set "CRACK_CMD=--wordlist=password.lst"                            & set "MODE_DESC=Dictionary (password.lst)" )
if "!MODE!"=="9"  goto :custom_dict
if "!MODE!"=="10" ( set "CRACK_CMD=--incremental"                                       & set "MODE_DESC=Incremental (all)" )
if "!MODE!"=="11" ( set "CRACK_CMD=--mask=?d?d?d?d?d?d?d?d?d?d?d"                      & set "MODE_DESC=Phone (11 digits)" )
if "!MODE!"=="12" ( set "CRACK_CMD=--mask=?d?d?d?d?d?d?d?d"                             & set "MODE_DESC=Birthday (8 digits)" )

goto :run_crack

:custom_mask
echo.
echo Mask placeholders:
echo   ?d = digits (0-9)
echo   ?l = lowercase (a-z)
echo   ?u = uppercase (A-Z)
echo   ?a = all printable
echo   ?s = special chars
echo   ?h = hex (0-9a-f)
echo.
echo Examples:
echo   ?d?d?d?d?d?d        = 6 digits
echo   ?l?l?d?d?d?d        = 2 letters + 4 digits
echo   password?d?d        = "password" + 2 digits
echo   ?l?l?l?l?l?l?l?l     = 8 lowercase letters
echo.
set /p "CUSTOM_MASK=Enter your mask: "
if "!CUSTOM_MASK!"=="" (
    echo [ERROR] Mask cannot be empty.
    pause
    exit /b 1
)
set /p "MIN_LEN=Enter min length (default 1): "
if "!MIN_LEN!"=="" set "MIN_LEN=1"
set /p "MAX_LEN=Enter max length (default 8): "
if "!MAX_LEN!"=="" set "MAX_LEN=8"
set "CRACK_CMD=--mask=!CUSTOM_MASK! --min-length=!MIN_LEN! --max-length=!MAX_LEN!"
set "MODE_DESC=Custom mask: !CUSTOM_MASK! (!MIN_LEN!-!MAX_LEN!)"
goto :run_crack

:custom_dict
set /p "DICT_PATH=Enter dictionary path (press Enter for password.lst): "
if "!DICT_PATH!"=="" set "DICT_PATH=password.lst"
if not exist "!DICT_PATH!" (
    if not exist "%JOHN_DIR%\!DICT_PATH!" (
        echo [ERROR] Dictionary not found: !DICT_PATH!
        pause
        exit /b 1
    )
    set "DICT_PATH=%JOHN_DIR%\!DICT_PATH!"
)
set "CRACK_CMD=--wordlist=!DICT_PATH!"
set "MODE_DESC=Dictionary: !DICT_PATH!"
goto :run_crack

:run_crack
echo.
echo ============================================================
echo  Mode  : !MODE_DESC!
echo  Cmd   : john --format=%FORMAT% !CRACK_CMD! --session=crack_!ZIP_NAME!_!MODE!
echo ============================================================
echo  Press 'q' to abort, 'h' for help, any key for status
echo  Auto-status: every 5 seconds (current password range + progress^)
echo ----------------------------------------------------------------
john.exe --format=%FORMAT% --progress-every=5 --verbosity=4 !CRACK_CMD! --session=crack_!ZIP_NAME!_!MODE! "%HASH_CLEAN%"
set "JOHN_RC=!errorlevel!"
echo ----------------------------------------------------------------
if !JOHN_RC! NEQ 0 echo [WARN] john exited with code !JOHN_RC! ^(may be interrupted or errored^)

:: Step 5: Show result
echo [5/5] Result:
echo.
john.exe --show "%HASH_CLEAN%" > "%RESULT_FILE%" 2>&1
type "%RESULT_FILE%"
echo.

:: Determine if a password was cracked: parse "N password hash cracked, M left" (N>0)
set "FOUND_PW=0"
set "CRACKED_N=0"
for /f "tokens=1" %%X in ('findstr /C:"cracked," "%RESULT_FILE%" 2^>nul') do set "CRACKED_N=%%X"
if !CRACKED_N! GTR 0 set "FOUND_PW=1"

echo ============================================================
if "!FOUND_PW!"=="1" (
    echo  ##########################################################
    echo  #                                                        #
    echo  #   PASSWORD / [Password]:
    powershell -NoProfile -Command "$pl = (Get-Content -LiteralPath '%RESULT_FILE%' | Where-Object { $_ -and ($_ -notmatch 'password hash') -and $_.Contains(':') } | Select-Object -First 1); if ($pl) { $i = $pl.IndexOf(':') + 1; $r = $pl.Substring($i); $j = $r.IndexOf(':$'); if ($j -ge 0) { $pw = $r.Substring(0,$j) } else { $pw = ($r -split ':')[0] }; Write-Host ('  #   ' + $pw) }"
    echo  #                                                        #
    echo  ##########################################################
) else (
    echo  Password not found / [Not Found]
)
echo ============================================================
echo  ZIP file  : %ZIP_FILE%
echo  Hash file : %HASH_CLEAN%
echo  Result    : %RESULT_FILE%
echo  Stored in John's pot file
echo  Re-show: john.exe --show "%HASH_CLEAN%"
echo ============================================================
echo.
pause
exit /b 0
