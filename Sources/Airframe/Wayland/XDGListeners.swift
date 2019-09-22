#if os(Linux)

import CWaylandClient
import CWaylandEGL // workaround SR-9589
import LoggerAPI
import XDGShell

func xdgSurfaceHandleConfigure(data: UnsafeMutableRawPointer?,
        xdg_surface: OpaquePointer?, serial: UInt32) {
    xdg_surface_ack_configure(xdg_surface, serial)
}

 var xdgSurfaceListener = xdg_surface_listener(
    configure: xdgSurfaceHandleConfigure
)

func xdgToplevelHandleConfigure (data: UnsafeMutableRawPointer?,
        xdg_toplevel: OpaquePointer?, width: Int32, height: Int32,
        states: UnsafeMutablePointer<wl_array>?) {
    Log.debug("Window size \(width)x\(height)")
    guard let data = data else {
        return
    }
    let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
            .takeUnretainedValue()
    window.width = Int(width)
    window.height = Int(height)
    window.resizeCallback?(window)
    //xdg_toplevel_ack_configure(xdg_surface, serial)
}

func xdgToplevelHandleClose (data: UnsafeMutableRawPointer?,
        xdg_toplevel: OpaquePointer?) {
    guard let data = data else {
        return
    }
    let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
            .takeUnretainedValue()
    window._running = false
    window.closeCallback?(window)
}

 var xdgToplevelListener = xdg_toplevel_listener(
    configure: xdgToplevelHandleConfigure,
    close: xdgToplevelHandleClose
)

#endif
