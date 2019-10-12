#if os(Linux)

import CEGL
import CWaylandClient
import CWaylandEGL
import Foundation
import Harness
import LoggerAPI
import WaylandShims
import XDGShell

public class WaylandWSIWindow: AirframeWindow {

    public var title: String? {
        didSet {
            if let title = title {
                xdg_toplevel_set_title(_xdg_toplevel, title.cString(using: .utf8))
            }
        }
    }
    public let appID: String?

    internal (set) public var width: Int
    internal (set) public var height: Int
    internal (set) public var scaleFactor: Double

    public var display: OpaquePointer {
        return _display
    }

    public var eglDisplay: EGLDisplay? {
        return _eglDisplay
    }

    public var wlSurface: OpaquePointer {
        return _surface
    }

    private (set) public var subsurfaces: [Subsurface] = []

    // Window callbacks
    public var frameCallback: ((WaylandWSIWindow) -> Void)? = nil
    public var outputCallback: ((WaylandWSIWindow, OutputMetrics) -> Void)? = nil
    public var enteredCallback: ((WaylandWSIWindow, OutputMetrics) -> Void)? = nil
    public var resizeCallback: ((WaylandWSIWindow) -> Void)? = nil
    public var closeCallback: ((WaylandWSIWindow) -> Void)? = nil

    // Pointer callbacks
    public var pointerEnterCallback: ((WaylandWSIWindow) -> Void)? = nil
    public var pointerLeaveCallback: ((WaylandWSIWindow) -> Void)? = nil
    public var pointerMotionCallback: ((WaylandWSIWindow, InputPointerEvent) -> Void)? = nil
    public var pointerButtonCallback: ((WaylandWSIWindow, InputPointerEvent) -> Void)? = nil
    public var pointerAxisCallback: ((WaylandWSIWindow, InputAxisEvent) -> Void)? = nil
    public var pointerFrameCallback: ((WaylandWSIWindow) -> Void)? = nil
    public var pointerAxisSourceCallback: ((WaylandWSIWindow) -> Void)? = nil
    public var pointerAxisStopCallback: ((WaylandWSIWindow) -> Void)? = nil
    public var pointerAxisDiscreteCallback: ((WaylandWSIWindow) -> Void)? = nil

    // Keyboard callbacks
    public var keyCallback: ((WaylandWSIWindow, InputKeyboardEvent) -> Void)? = nil

    internal var _pointer: (button: UInt32, state: UInt32, x: Double,y: Double) =
            (0, 0, 0.0, 0.0)

    internal var _keyboard: (
        repeatInfo: (rate: UInt32, delay: UInt32),
        repeatData: (key: UInt32, time: UInt32, state: UInt32, eventSource: UInt32),
        serial: UInt32
    ) = (
        (0, 0),
        (0, 0, 0, 0),
        0
    )

    internal var _xkb: (
        context: OpaquePointer?,
        keymap: OpaquePointer?,
        state: OpaquePointer?,
        composeTable: OpaquePointer?,
        composeState: OpaquePointer?,
        indices: (
            control: UInt32,
            alt: UInt32,
            shift: UInt32
        ),
        modifiers: InputModifier) = (nil, nil, nil, nil, nil, (0, 0, 0), [])

    fileprivate var _display: OpaquePointer! = nil

    fileprivate var _xdg_wm_base: OpaquePointer! = nil
    fileprivate var _compositor: OpaquePointer! = nil
    fileprivate var _subcompositor: OpaquePointer! = nil
    fileprivate var _seat: OpaquePointer! = nil
    fileprivate var _surface: OpaquePointer! = nil
    fileprivate var _xdg_surface: OpaquePointer! = nil
    fileprivate var _xdg_toplevel: OpaquePointer! = nil

    internal var _outputs = [UInt32: OpaquePointer]()
    internal var _outputMetrics = [UInt32: OutputMetrics]()

    private var _lastFrameTime = PrecisionTimer()

    private var _eglDisplay: EGLDisplay? = nil

    fileprivate var _eventSource: OpaquePointer! = nil

    internal var _running = true
    //private var _color = [Float](repeating: 0.0, count: 3)
    //private var _dec: size_t = 0

    public required init? (title: String? = nil, appID: String? = nil,
            width: Int = 640, height: Int = 480, scaleFactor: Double = 1.0) {
        _lastFrameTime = PrecisionTimer()

        self.title = title
        self.appID = appID
        self.height = height
        self.width = width
        self.scaleFactor = scaleFactor

        let unsafeSelf = Unmanaged.passUnretained(self).toOpaque()

        guard let display = wl_display_connect(nil) else {
            Log.error("Failed to create wl_display")
            return nil
        }
        _display = display

        let registry = wl_display_get_registry(_display)
        if wl_registry_add_listener(registry, &registryListener, unsafeSelf) != 0 {
            Log.error("wl_registry_add_listener failed")
            return nil
        }
        wl_display_dispatch(_display)
        wl_display_roundtrip(_display)

        if _compositor == nil || _xdg_wm_base == nil {
            Log.error("no wl_compositor or xdg_wm_base support")
            return nil
        }
        guard let surface = wl_compositor_create_surface(_compositor) else {
            Log.error("wl_surface creation failed: \(String(cString: strerror(errno)))")
            exit(-1)
        }
        _surface = surface
        if wl_surface_add_listener(_surface, &surfaceListener, unsafeSelf) != 0 {
            Log.error("wl_surface_add_listener failed")
        }

        _xdg_surface = shim_get_xdg_surface(UnsafeMutableRawPointer(_xdg_wm_base), UnsafeMutableRawPointer(_surface))
        _xdg_toplevel = shim_get_xdg_toplevel(UnsafeMutableRawPointer(_xdg_surface))

        if xdg_surface_add_listener(_xdg_surface, &xdgSurfaceListener, nil) != 0 {
            Log.error("xdg_surface_add_listener failed")
            return nil
        }
        if xdg_toplevel_add_listener(_xdg_toplevel, &xdgToplevelListener, unsafeSelf) != 0 {
            Log.error("xdg_toplevel_add_listener failed")
            return nil
        }
        if let title = title {
            xdg_toplevel_set_title(_xdg_toplevel, title.cString(using: .utf8))
        }
        if let appID = appID {
            xdg_toplevel_set_app_id(_xdg_wm_base, appID.cString(using: .utf8))
        }
        guard let eglDisplay = eglGetDisplay(display) else {
            Log.error("failed to get EGL display")
            return nil
        }
        _eglDisplay = eglDisplay

        var major: EGLint = 0, minor: EGLint = 0
        if eglInitialize(_eglDisplay, &major, &minor) != EGL_TRUE {
            Log.error("failed to initialize EGL")
            return nil
        }
        Log.debug("Initialised EGL v\(major).\(minor)")

        wl_surface_commit(_surface)
        wl_display_roundtrip(_display)

        _eventSource = OpaquePointer(setup_wayland_event_source(UnsafeMutableRawPointer(_display)))

        //self.render()
    }

    public func createSubsurface () {

        guard let surface = wl_compositor_create_surface(_compositor) else {
            Log.error("wl_surface creation failed: \(String(cString: strerror(errno)))")
            exit(-1)
        }
        guard let subsurface = wl_subcompositor_get_subsurface(_subcompositor, surface, _surface) else {
            Log.error("wl_subsurface creation failed: \(String(cString: strerror(errno)))")
            exit(-1)
        }
        subsurfaces.append(Subsurface(parent: surface, subsurface: subsurface))
    }

    fileprivate func render() {
        // Update color
        let renderTime = _lastFrameTime.elapsed
        _lastFrameTime = PrecisionTimer()
        if renderTime > 0.0 {
            //let fps = 1.0 / renderTime
            //Log.debug(String(format: "%.2f fps (%.1f ms)", fps, renderTime * 1000))
        }

        /*let ms = Float(renderTime * 1000)
        let inc = (_dec + 1) % 3
        _color[inc] += ms / 2000.0
        _color[_dec] -= ms / 2000.0
        if _color[_dec] < 0.0 {
            _color[inc] = 1.0
            _color[_dec] = 0.0
            _dec = inc
        }
        _lastFrameTime = PrecisionTimer()

        // And draw a new frame
        if eglMakeCurrent(_eglDisplay, _eglSurface, _eglSurface, _eglContext) != EGL_TRUE {
            Log.error("eglMakeCurrent failed: \(eglGetError())")
            exit(-1)
        }

        glClearColor(_color[0], _color[1], _color[2], 1.0)
        glClear(UInt32(GL_COLOR_BUFFER_BIT))
        */
        // Register a frame callback to know when we need to draw the next frame
        /*let unsafeSelf = Unmanaged.passUnretained(self).toOpaque()
        let callback = wl_surface_frame(_surface)
        if wl_callback_add_listener(callback, &frameListener, unsafeSelf) != 0 {
            Log.error("wl_callback_add_listener failed")
        }*/

        // This will attach a new buffer and commit the surface
        /*if eglSwapBuffers(_eglDisplay, _eglSurface) != EGL_TRUE {
            Log.error("eglSwapBuffers failed: \(eglGetError())")
            exit(-1)
        }

        // By default, eglSwapBuffers blocks until we receive the next frame event.
        // This is undesirable since it makes it impossible to process other events
        // (such as input events) while waiting for the next frame event. Setting
        // the swap interval to zero and managing frame events manually prevents
        // this behavior.
        eglSwapInterval(_eglDisplay, 0)*/
    }

    deinit {
        //xdg_toplevel_destroy(xdg_toplevel);
        //xdg_surface_destroy(xdg_surface);
        //wl_surface_destroy(surface);
    }

}

public struct Subsurface {
    public var parent: OpaquePointer
    public var subsurface: OpaquePointer
}

private enum WaylandProtocol: String {
    case shm = "wl_shm"
    case zwp_linux_dmabuf_v1 = "zwp_linux_dmabuf_v1"
    case drm = "wl_drm"
    case compositor = "wl_compositor"
    case subcompositor = "wl_subcompositor"
    case data_device_manager = "wl_data_device_manager"
    case gamma_control_manager = "gamma_control_manager"
    case zwlr_gamma_control_manager_v1 = "zwlr_gamma_control_manager_v1"
    case gtk_primary_selection_device_manager = "gtk_primary_selection_device_manager"
    case zxdg_output_manager_v1 = "zxdg_output_manager_v1"
    case org_kde_kwin_idle = "org_kde_kwin_idle"
    case zwp_idle_inhibit_manager_v1 = "zwp_idle_inhibit_manager_v1"
    case zwlr_layer_shell_v1 = "zwlr_layer_shell_v1"
    case zxdg_shell_v6 = "zxdg_shell_v6"
    case xdg_wm_base = "xdg_wm_base"
    case org_kde_kwin_server_decoration_manager = "org_kde_kwin_server_decoration_manager"
    case zxdg_decoration_manager_v1 = "zxdg_decoration_manager_v1"
    case zwp_relative_pointer_manager_v1 = "zwp_relative_pointer_manager_v1"
    case zwp_pointer_constraints_v1 = "zwp_pointer_constraints_v1"
    case wp_presentation = "wp_presentation"
    case zwlr_export_dmabuf_manager_v1 = "zwlr_export_dmabuf_manager_v1"
    case zwlr_screencopy_manager_v1 = "zwlr_screencopy_manager_v1"
    case zwlr_data_control_manager_v1 = "zwlr_data_control_manager_v1"
    case zwp_primary_selection_device_manager_v1 = "zwp_primary_selection_device_manager_v1"
    case zwp_virtual_keyboard_manager_v1 = "zwp_virtual_keyboard_manager_v1"
    case zwlr_input_inhibit_manager_v1 = "zwlr_input_inhibit_manager_v1"
    case seat = "wl_seat"
    case output = "wl_output"
}

private var registryListener = wl_registry_listener(
    global: handleGlobal,
    global_remove: handleGlobalRemove
)

private func handleGlobal(data: UnsafeMutableRawPointer?,
        registry: OpaquePointer?, name: UInt32, interface: UnsafePointer<Int8>?,
        version: UInt32) {
    guard let interface = interface, let data = data else {
        return
    }
    var minimumVersion: UInt32
    let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
            .takeUnretainedValue()
    let interfaceName = String(cString: interface)
    Log.debug("\(name): \(interfaceName) v\(version)")
    if interfaceName == WaylandProtocol.seat.rawValue {
        guard let seatInterface = shim_get_interface(interface) else {
            Log.error("Failed to get interface pointer for \(interfaceName)")
            return
        }
        minimumVersion = 5
        window._seat = OpaquePointer(wl_registry_bind(registry, name, seatInterface, max(minimumVersion, version)))
        wl_seat_add_listener(window._seat, &seatListener, data)
    } else if interfaceName == WaylandProtocol.compositor.rawValue {
        guard let compositorInterface = shim_get_interface(interface) else {
            Log.error("Failed to get interface pointer for \(interfaceName)")
            return
        }
        minimumVersion = 4
        window._compositor = OpaquePointer(wl_registry_bind(registry, name, compositorInterface, max(minimumVersion, version)))
    } else if interfaceName == WaylandProtocol.subcompositor.rawValue {
        guard let subcompositorInterface = shim_get_interface(interface) else {
            Log.error("Failed to get interface pointer for \(interfaceName)")
            return
        }
        minimumVersion = 1
        window._subcompositor = OpaquePointer(wl_registry_bind(registry, name, subcompositorInterface, max(minimumVersion, version)))
    } else if interfaceName == WaylandProtocol.xdg_wm_base.rawValue {
        guard let xdgWmBaseInterface = shim_get_interface(interface) else  {
            Log.error("Failed to get interface pointer for \(interfaceName)")
            return
        }
        minimumVersion = 1
        window._xdg_wm_base = OpaquePointer(wl_registry_bind(registry, name, xdgWmBaseInterface, max(minimumVersion, version)))
    } else if interfaceName == WaylandProtocol.output.rawValue {
        guard let outputInterface = shim_get_interface(interface) else  {
            Log.error("Failed to get interface pointer for \(interfaceName)")
            return
        }
        minimumVersion = 2
        let output = OpaquePointer(wl_registry_bind(registry, name, outputInterface, max(minimumVersion, version)))
        wl_output_add_listener(output, &outputListener, data)
        window._outputs[name] = output
        window._outputMetrics[name] = OutputMetrics()
    } else {
        return
    }
    Log.verbose("Bound \(name): \(interfaceName) v\(max(minimumVersion, version)) (supported v\(version), minimum v\(minimumVersion)")
}

private func handleGlobalRemove (data: UnsafeMutableRawPointer?,
        registry: OpaquePointer?, name: UInt32) {
    guard let data = data else {
        return
    }
    let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
            .takeUnretainedValue()
    if let wl_output = window._outputs.removeValue(forKey: name) {
        Log.info("Output \(wl_output) removed")
    }
}

fileprivate var outputListener = wl_output_listener(
    geometry: outputHandleGeometry,
    mode: outputHandleMode,
    done: outputHandleDone,
    scale: outputHandleScale
)

fileprivate func outputHandleGeometry (data: UnsafeMutableRawPointer?,
        output: OpaquePointer?, x: Int32, y: Int32, physicalWidth: Int32,
        physicalHeight: Int32, subpixel: Int32, make: UnsafePointer<Int8>?,
        model: UnsafePointer<Int8>?, transform: Int32) {
    guard let data = data else {
        return
    }
    let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
            .takeUnretainedValue()
    guard let output = output,
            let name = window._outputs.key(for: output),
            var metrics = window._outputMetrics[name] else {
        Log.error("Missing output metrics")
        return
    }
    metrics.id = Int(name)
    metrics.x = Int(x)
    metrics.y = Int(y)
    metrics.physicalWidth = Int(physicalWidth)
    metrics.physicalHeight = Int(physicalHeight)
    if let make = make, let model = model {
        metrics.make = String(cString: make, encoding: .utf8) ?? "Unknown"
        metrics.model = String(cString: model, encoding: .utf8) ?? "Unknown"
    } else {
        metrics.make = "Unknown"
        metrics.model = "Unkown"
    }
    window._outputMetrics[name] = metrics
}

fileprivate func outputHandleMode (data: UnsafeMutableRawPointer?,
        output: OpaquePointer?, flags: UInt32, width: Int32, height: Int32,
        refresh: Int32) {
    if flags & WL_OUTPUT_MODE_CURRENT.rawValue == 0 {
        return
    }
    guard let data = data else {
        return
    }
    let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
            .takeUnretainedValue()
    guard let output = output,
            let name = window._outputs.key(for: output),
            var metrics = window._outputMetrics[name] else {
        Log.error("Missing output metrics")
        return
    }
    metrics.modeWidth = Int(width)
    metrics.modeHeight = Int(height)
    metrics.refresh = Int(refresh)
    window._outputMetrics[name] = metrics

}

fileprivate func outputHandleDone (data: UnsafeMutableRawPointer?,
        output: OpaquePointer?) {
    guard let data = data else {
        return
    }
    let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
            .takeUnretainedValue()
    guard let output = output,
            let name = window._outputs.key(for: output),
            let metrics = window._outputMetrics[name] else {
        Log.error("Missing output metrics")
        return
    }
    if !metrics.valid {
        Log.error("Invalid metrics for output \(name)")
        return
    }
    Log.verbose("Added output: \(metrics.description)")
    window.outputCallback?(window, metrics)
}

fileprivate func outputHandleScale (data: UnsafeMutableRawPointer?,
        output: OpaquePointer?, scale: Int32) {
    guard let data = data else {
        return
    }
    let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
            .takeUnretainedValue()
    guard let output = output,
            let name = window._outputs.key(for: output),
            var metrics = window._outputMetrics[name] else {
        Log.error("Missing output metrics")
        return
    }
    metrics.scaleFactor = Int(scale)
    window._outputMetrics[name] = metrics
}

/*
fileprivate var frameListener = wl_callback_listener(
    done: frameHandleDone
)

fileprivate func frameHandleDone(data: UnsafeMutableRawPointer?, callback: OpaquePointer?,
        time: UInt32) {
    wl_callback_destroy(callback)
    guard let data = data else {
        return
    }
    let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
            .takeUnretainedValue()
    window.frameCallback?()

    //window.render()
}*/

#endif
