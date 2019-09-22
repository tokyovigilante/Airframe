#if os(OSX)

import Cocoa
import Metal
import LoggerAPI
import Harness

fileprivate let outputCallback: CVDisplayLinkOutputCallback = {
    (displayLink, inNow, outOutputTime, flagsIn, flagsOut, context) -> CVReturn in
    guard let context = context else {
        return kCVReturnInvalidArgument
    }
    let window = Unmanaged<MacWSIWindow>.fromOpaque(context).takeUnretainedValue()
    window.draw(at: inNow.pointee)
    return kCVReturnSuccess
}

public class MacWSIWindow: AirframeWindow {

    private (set) public var title: String
    private (set) public var width: Double
    private (set) public var height: Double
    private (set) public var scaleFactor: Double
    
    public var rendererCallback: (() -> Void)?

    internal let _metalLayer: CAMetalLayer
    internal let _internalWindow: NSWindow
    
    internal var _displayLink: CVDisplayLink! = nil
    
    public var displayLinkCreated: Bool {
        return _displayLink != nil
    }
    
    public var displayLinkRunning: Bool {
        if _displayLink == nil {
            return false
        }
        return CVDisplayLinkIsRunning(_displayLink)
    }
    
    public init? (title: String = "MacWSIWindow",
                  width: Double = 640.0, height: Double = 480.0, scaleFactor: Double = 1.0) {
        
        self.title = title
        self.height = height
        self.width = width
        self.scaleFactor = scaleFactor
        
        let windowSize = NSSize(width: width, height: height)

        let windowOrigin: NSPoint
        if let mainScreen = NSScreen.main {
            let screenRect = mainScreen.frame
            windowOrigin = NSPoint(
                x: (screenRect.width - windowSize.width)/2,
                y: (screenRect.height - windowSize.height)/2)
        } else {
            windowOrigin = NSPoint(x: 100.0, y: 100.0)
        }
        
        let contentRect = NSRect(origin: windowOrigin, size: windowSize)
        
        _internalWindow = InternalWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .unifiedTitleAndToolbar],
            backing: .buffered,
            defer: false)
        
        //self.titlebarAppearsTransparent = true
        //self.titleVisibility = .hidden
        _internalWindow.isMovableByWindowBackground = true
        
        _metalLayer = CAMetalLayer()
        _metalLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 1.0
        _metalLayer.displaySyncEnabled = true
        //metalLayer.maximumDrawableCount = 3
    
        let view = NSView()
        view.layer = _metalLayer
        view.wantsLayer = true
        
        let content = _internalWindow.contentView! as NSView
        content.addSubview(view)
        
        view.topAnchor.constraint(equalTo: content.topAnchor).isActive = true
        view.leftAnchor.constraint(equalTo: content.leftAnchor).isActive = true
        view.rightAnchor.constraint(equalTo: content.rightAnchor).isActive = true
        view.bottomAnchor.constraint(equalTo: content.bottomAnchor).isActive = true
        view.translatesAutoresizingMaskIntoConstraints = false
        
        if recreateDisplayLink(), let screen = NSScreen.main {
            updateDisplayLink(for: screen)
        }
        _internalWindow.makeKeyAndOrderFront(nil)
    }

    private func recreateDisplayLink () -> Bool {
        if _displayLink == nil {
            stopRendering()
        }
        let result = CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink)
        if result != kCVReturnSuccess {
            Log.error("updateDisplayLink failed: \(result)")
            _displayLink = nil
        }
        let unsafeSelf = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(_displayLink, outputCallback, unsafeSelf)
        
        return _displayLink != nil
    }
    
    public func updateDisplayLink (for screen: NSScreen) {
        if _displayLink == nil {
            Log.error("updateDisplayLink called with nil displaylink")
            return
        }
        let result = CVDisplayLinkSetCurrentCGDisplay(_displayLink, screen.displayID)
        if result != kCVReturnSuccess {
            Log.error("updateDisplayLink failed: \(result)")
            _displayLink = nil
        }
    }

    public func startRendering() {
        if _displayLink != nil {
            CVDisplayLinkStart(_displayLink)
            let id = CVDisplayLinkGetCurrentCGDisplay(_displayLink)
            let refresh = CVDisplayLinkGetNominalOutputVideoRefreshPeriod(_displayLink)
            let refreshPeriod = 1.0 / (Double(refresh.timeValue) / Double(refresh.timeScale))
            Log.debug("Displaylink running on display \(id)" + String(format: " (%.2f Hz)", refreshPeriod))
        } else {
            Log.error("startRendering called with nil displaylink")
        }
    }
    
    public func stopRendering() {
        if _displayLink != nil && displayLinkRunning {
            CVDisplayLinkStop(_displayLink)
        }
    }

    fileprivate func draw(at time: CVTimeStamp) {
        rendererCallback?()
    }
    
    deinit {
        stopRendering()
    }
}

private class InternalWindow: NSWindow {
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        return deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as! CGDirectDisplayID
    }
}

#endif
