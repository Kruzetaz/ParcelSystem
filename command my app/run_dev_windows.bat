@echo off
REM run_dev_windows.bat
REM ดับเบิลคลิกไฟล์นี้เพื่อรันแอปโหมดพัฒนา (flutter run -d windows) ทันที
REM ใช้ตอนกำลังแก้โค้ด/ทดสอบไปเรื่อยๆ เร็วกว่า build เต็มมาก และ hot reload ได้
REM กด "r" ใน terminal นี้เพื่อ hot reload หลังแก้โค้ด, กด "q" เพื่อออก

REM แก้ path นี้ให้ตรงกับตำแหน่งโปรเจกต์จริงในเครื่องคุณ
set PROJECT_DIR=C:\Users\Powernet\Desktop\ParcelSystem

cd /d "%PROJECT_DIR%"
if errorlevel 1 (
    echo ไม่พบโฟลเดอร์โปรเจกต์ที่ %PROJECT_DIR%
    pause
    exit /b 1
)

echo ==========================================
echo   กำลังรันโหมดพัฒนา (flutter run -d windows)
echo   กด r = hot reload, R = hot restart, q = ออก
echo ==========================================

call flutter run -d windows
pause
