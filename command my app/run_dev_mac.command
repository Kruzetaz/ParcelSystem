#!/bin/bash
# run_dev_mac.command
# ดับเบิลคลิกไฟล์นี้เพื่อรันแอปโหมดพัฒนา (flutter run -d macos) ทันที
# ใช้ตอนกำลังแก้โค้ด/ทดสอบไปเรื่อยๆ เร็วกว่า build เต็มมาก และ hot reload ได้
# กด "r" ใน terminal นี้เพื่อ hot reload หลังแก้โค้ด, กด "q" เพื่อออก

# แก้ path นี้ให้ตรงกับตำแหน่งโปรเจกต์จริงในเครื่องคุณ
PROJECT_DIR="/Users/zack1again/Developer/Projects/ParcelSystem"

cd "$PROJECT_DIR" || { echo "ไม่พบโฟลเดอร์โปรเจกต์ที่ $PROJECT_DIR"; read -p "กด Enter เพื่อปิด..."; exit 1; }

echo "=========================================="
echo "  กำลังรันโหมดพัฒนา (flutter run -d macos)"
echo "  กด r = hot reload, R = hot restart, q = ออก"
echo "=========================================="

flutter run -d macos
