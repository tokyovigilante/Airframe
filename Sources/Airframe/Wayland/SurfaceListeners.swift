#if os(Linux)

import CWaylandClient
import CWaylandEGL // workaround SR-9589
import LoggerAPI

var surfaceListener = wl_surface_listener(
    enter: surfaceOutputEnter,
    leave: surfaceOutputLeave
)

func surfaceOutputEnter (data: UnsafeMutableRawPointer?,
        surface: OpaquePointer?, output: OpaquePointer?) {
    Log.debug ("Entered output")
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
    window.scaleFactor = Double(metrics.scaleFactor)
    wl_surface_set_buffer_scale(surface, Int32(metrics.scaleFactor))
    Log.info("Set surface buffer scale to \(metrics.scaleFactor)")
    window.enteredCallback?(window, metrics)
}


func surfaceOutputLeave (data: UnsafeMutableRawPointer?,
        surface: OpaquePointer?, output: OpaquePointer?) {
    Log.debug ("Left output")
    /*guard let data = data else {
        return
    }
    let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
            .takeUnretainedValue()*/
}

#endif
