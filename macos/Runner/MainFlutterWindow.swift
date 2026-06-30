import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // DevDisk: desktop-sized window, native title bar with traffic lights.
    self.setContentSize(NSSize(width: 1000, height: 680))
    self.minSize = NSSize(width: 880, height: 600)
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
