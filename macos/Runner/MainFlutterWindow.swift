import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // ปิดระบบจำสถานะหน้าต่างของ macOS — Flutter engine ไม่รองรับการ restore
    // window ตัวนี้ดีนัก ทำให้เปิดผ่าน Finder/open แล้วเจอจอดำค้าง (แต่เปิดผ่าน
    // การรัน executable ตรงๆ ใน Terminal ไม่เจอ เพราะไม่ผ่านกลไก restore นี้)
    self.isRestorable = false

    super.awakeFromNib()
  }
}
