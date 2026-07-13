#!/bin/bash
# open_app.command
# ดับเบิลคลิกไฟล์นี้เพื่อเปิดแอป "ระบบจัดซื้อจัดจ้าง"
#
# ต้องวางไฟล์นี้ไว้โฟลเดอร์เดียวกับ "ParcelSystem v.2.app" เสมอ ห้ามแยกออกจากกัน
#
# เหตุผลที่ไม่ให้ดับเบิลคลิกไฟล์ .app ตรงๆ: เครื่องที่รัน macOS ใหม่ๆ บางเครื่อง
# (เช่น macOS 26) มีบั๊กที่ทำให้แอป Flutter จอดำเวลาเปิดผ่าน Finder โดยตรง —
# ไฟล์ .command นี้เปิดผ่าน Terminal แทน ซึ่งไม่เจอบั๊กนี้

# หาตำแหน่งโฟลเดอร์ที่ไฟล์นี้อยู่จริง (รองรับกรณีย้ายไปที่อื่น/เครื่องอื่น)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$SCRIPT_DIR/ParcelSystem v.2.app"
APP_BINARY="$APP_PATH/Contents/MacOS/ParcelSystem v.2"

clear
echo "กำลังเปิด ระบบจัดซื้อจัดจ้าง ..."

if [ ! -f "$APP_BINARY" ]; then
  echo ""
  echo "ไม่พบไฟล์ \"ParcelSystem v.2.app\" ในโฟลเดอร์เดียวกับไฟล์นี้"
  echo "กรุณาอย่าย้ายไฟล์แยกออกจากกัน"
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
