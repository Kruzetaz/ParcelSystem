#!/bin/bash
# open_app.command
# ดับเบิลคลิกไฟล์นี้เพื่อ "เปิดแอปที่ build ไว้แล้ว" โดยไม่ต้อง build ใหม่
#
# เหตุผลที่ไม่ใช้ดับเบิลคลิกไฟล์ .app ตรงๆ: เครื่องที่รัน macOS ใหม่ (เช่น macOS 26)
# มีบั๊กที่ทำให้แอป Flutter จอดำเวลาเปิดผ่าน Finder โดยตรง — ไฟล์ .command นี้เปิดผ่าน
# Terminal แทน ซึ่งไม่เจอบั๊กนี้ (ทดสอบแล้วใช้ได้จริง)
#
# หน้าต่างนี้จะปิดเองอัตโนมัติหลังเปิดแอปสำเร็จ (ไม่มี dialog ถามยืนยัน เพราะตัว
# แอปถูกตัดขาด stdin/stdout/stderr ออกจากหน้าต่างนี้เต็มรูปแบบด้วย nohup ก่อนปิด
# — Terminal เลยไม่เห็นว่ามีโปรเซสค้างอยู่ในหน้าต่างแล้ว) ปิดด้วยการส่งคีย์ Cmd+W
# ไปที่หน้าต่างที่ใช้งานอยู่ (ใช้ได้กับทุกโปรแกรม Terminal ไม่ว่าจะเป็น Terminal.app,
# iTerm, Warp ฯลฯ — ครั้งแรกอาจมี dialog ขอสิทธิ์ "Accessibility" จาก macOS ต้อง
# กด "อนุญาต"/Allow ครั้งเดียว ครั้งต่อไปจะไม่ถามอีก)

PROJECT_DIR="/Users/zack1again/Developer/Projects/ParcelSystem"
APP_PATH="$PROJECT_DIR/build/macos/Build/Products/Release/ParcelSystem v3.2 Retamp.app"
APP_BINARY="$APP_PATH/Contents/MacOS/ParcelSystem v3.2 Retamp"

clear
echo "กำลังเปิด ระบบจัดซื้อจัดจ้าง ..."

if [ ! -f "$APP_BINARY" ]; then
  echo ""
  echo "ไม่พบแอปที่ build ไว้ที่:"
  echo "$APP_PATH"
  echo "กรุณา build ก่อนด้วย build_mac.command"
  read -p "กด Enter เพื่อปิด..."
  exit 1
fi

# จำชื่อโปรแกรม Terminal ที่กำลังรันสคริปต์นี้อยู่ไว้ก่อน เพราะพอแอปจริงเปิดขึ้นมา
# มันจะแย่ง focus ไปเป็นหน้าต่างที่ active แทน ถ้าไม่จำไว้ก่อน คำสั่งปิดหน้าต่างท้าย
# สคริปต์จะไปกดปิดผิดโปรแกรม (ไปกดที่แอปจริงแทนที่จะเป็น Terminal)
FRONT_APP="$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null)"

xattr -cr "$APP_PATH" 2>/dev/null
nohup "$APP_BINARY" > /dev/null 2>&1 < /dev/null &
disown -h
sleep 3

if [ -n "$FRONT_APP" ]; then
  osascript \
    -e "tell application \"$FRONT_APP\" to activate" \
    -e 'tell application "System Events" to keystroke "w" using command down' \
    >/dev/null 2>&1
fi
exit 0
