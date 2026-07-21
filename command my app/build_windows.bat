@echo off
chcp 65001 >nul
REM build_windows.bat
REM ดับเบิลคลิกไฟล์นี้เพื่อ build เวอร์ชัน Release ใหม่ทั้งหมด (pub get + build)
REM แล้วสร้าง shortcut ไปวางที่ Desktop ให้อัตโนมัติ เปิดใช้งานได้เลยไม่ต้องงมหา

REM แก้ path นี้ให้ตรงกับตำแหน่งโปรเจกต์จริงในเครื่องคุณ
set PROJECT_DIR=C:\Dev\ParcelSystem
set EXE_NAME=ParcelSystem v.2.4.exe

cd /d "%PROJECT_DIR%"
if errorlevel 1 (
    echo ไม่พบโฟลเดอร์โปรเจกต์ที่ %PROJECT_DIR%
    pause
    exit /b 1
)

echo ==========================================
echo   กำลัง build ระบบจัดซื้อจัดจ้าง (Windows)
echo ==========================================

call flutter pub get
call flutter build windows --release

set RELEASE_DIR=%PROJECT_DIR%\build\windows\x64\runner\Release
set EXE_PATH=%RELEASE_DIR%\%EXE_NAME%

if exist "%EXE_PATH%" (
    echo.
    echo Build สำเร็จ! กำลังสร้าง shortcut ที่ Desktop...

    REM สร้าง shortcut ด้วย PowerShell (ตัว .bat เองทำไม่ได้ตรงๆ ต้องเรียก PowerShell ช่วย)
    powershell -Command "$s = (New-Object -COM WScript.Shell).CreateShortcut('%USERPROFILE%\Desktop\ระบบจัดซื้อจัดจ้าง.lnk'); $s.TargetPath = '%EXE_PATH%'; $s.WorkingDirectory = '%RELEASE_DIR%'; $s.Save()"

    echo.
    echo เสร็จแล้ว! เปิดแอปได้จาก shortcut ที่ Desktop ชื่อ "ระบบจัดซื้อจัดจ้าง"
    echo หรือเปิดตรงจาก: %EXE_PATH%
    echo.
    pause
    start "" "%EXE_PATH%"
) else (
    echo.
    echo Build ไม่สำเร็จ — ดู error ด้านบนเพื่อหาสาเหตุ
    pause
)
