import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // กำหนดขนาดหน้าต่างขั้นต่ำ — เป็นแอปตารางข้อมูลหนาแน่น (rail sidebar 212px
    // + เนื้อหาตาราง/แผงข้าง) ถ้าย่อแคบกว่านี้ layout จะแตกจริงไม่ว่าจะพยายาม
    // ป้องกัน overflow ที่ระดับ widget ดีแค่ไหนก็ตาม — ตั้งขั้นต่ำไว้กันปัญหา
    // ทั้งหมวดหมู่นี้แทนที่จะไล่แก้ทีละจุดไม่จบสิ้น (มาตรฐานทั่วไปของแอป desktop)
    self.minSize = NSSize(width: 1200, height: 720)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // ปิดระบบจำสถานะหน้าต่างของ macOS — Flutter engine ไม่รองรับการ restore
    // window ตัวนี้ดีนัก ทำให้เปิดผ่าน Finder/open แล้วเจอจอดำค้าง (แต่เปิดผ่าน
    // การรัน executable ตรงๆ ใน Terminal ไม่เจอ เพราะไม่ผ่านกลไก restore นี้)
    self.isRestorable = false

    super.awakeFromNib()
  }
}
