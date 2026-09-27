import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    
    // ضبط حجم النافذة الافتراضي لنظام الكاشير
    let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1280, height: 800)
    let windowWidth: CGFloat = min(1280, screenSize.width * 0.9)
    let windowHeight: CGFloat = min(800, screenSize.height * 0.9)
    let windowX = (screenSize.width - windowWidth) / 2
    let windowY = (screenSize.height - windowHeight) / 2
    
    let windowFrame = NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight)
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    
    // الحد الأدنى للنافذة
    self.minSize = NSSize(width: 1024, height: 680)
    
    RegisterGeneratedPlugins(registry: flutterViewController)
    
    super.awakeFromNib()
  }
}
