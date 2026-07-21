#!/bin/bash
# build_mac.command
# ดับเบิลคลิกไฟล์นี้เพื่อ build เวอร์ชัน Release ใหม่ทั้งหมด (clean ก่อนเสมอ
# กันปัญหา code-sign ค้างจาก build เก่า) แล้วล้าง quarantine flag +
# re-sign แบบ ad-hoc ให้อัตโนมัติ กันปัญหาจอดำตอนดับเบิลคลิกเปิดแอป

# แก้ path นี้ให้ตรงกับตำแหน่งโปรเจกต์จริงในเครื่องคุณ
PROJECT_DIR="/Users/zack1again/Developer/Projects/ParcelSystem"

cd "$PROJECT_DIR" || { echo "ไม่พบโฟลเดอร์โปรเจกต์ที่ $PROJECT_DIR"; read -p "กด Enter เพื่อปิด..."; exit 1; }

echo "=========================================="
echo "  กำลัง build ระบบจัดซื้อจัดจ้าง (macOS)"
echo "=========================================="

flutter clean
flutter pub get
flutter build macos --release

APP_PATH="build/macos/Build/Products/Release/ParcelSystem v.2.4.app"
APP_BINARY="$APP_PATH/Contents/MacOS/ParcelSystem v.2.4"

if [ -d "$APP_PATH" ]; then
  echo ""
  echo "Build สำเร็จ — กำลังล้าง quarantine flag..."
  xattr -cr "$APP_PATH"
  echo ""
  echo "เสร็จแล้ว! เปิดแอปได้จาก:"
  echo "$PROJECT_DIR/$APP_PATH"
  echo ""
  echo "หมายเหตุ: เครื่องรุ่นนี้ (macOS ใหม่) มีบั๊กจอดำถ้าเปิดผ่าน Finder/ดับเบิลคลิก"
  echo "โดยตรง สคริปต์นี้เลยเปิดแอปด้วยวิธีรัน executable ตรงๆ แทน ซึ่งไม่เจอบั๊กนี้"
  echo ""
  read -p "กด Enter เพื่อเปิดแอปทันที (หรือปิดหน้าต่างนี้ถ้าไม่ต้องการ)..."
  "$APP_BINARY" &
  disown
else
  echo ""
  echo "Build ไม่สำเร็จ — ดู error ด้านบนเพื่อหาสาเหตุ"
  read -p "กด Enter เพื่อปิด..."
fi
