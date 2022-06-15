#if os(Linux)

import Foundation
import CWaylandClient
import CWaylandEGL // workaround SR-9589
import CXKBCommon
import Foundation
import LoggerAPI

var seatListener = wl_seat_listener(
    capabilities: seatHandleCapabilities,
    name: seatHandleName
)

func seatHandleCapabilities (data: UnsafeMutableRawPointer?,
        seat: OpaquePointer?, capabilities: UInt32) {
    if capabilities & WL_SEAT_CAPABILITY_POINTER.rawValue != 0 {
        let pointer = wl_seat_get_pointer(seat)
        wl_pointer_add_listener(pointer, &pointerListener, data)
        Log.verbose("Added pointer listener")
    }
    if capabilities & WL_SEAT_CAPABILITY_KEYBOARD.rawValue != 0 {

        guard let data = data else {
            return
        }
        let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
                .takeUnretainedValue()
        guard let context = xkb_context_new(XKB_CONTEXT_NO_FLAGS) else {
            Log.error("xkb context creation failed")
            return
        }
        window._xkb.context = context
        window._xkb.composeTable =
                xkb_compose_table_new_from_locale(window._xkb.context,
                setlocale(LC_CTYPE, nil), XKB_COMPOSE_COMPILE_NO_FLAGS)
        if (window._xkb.composeTable != nil) {
            window._xkb.composeState = xkb_compose_state_new(
                    window._xkb.composeTable, XKB_COMPOSE_STATE_NO_FLAGS)
        }
        let keyboard = wl_seat_get_keyboard(seat)
        wl_keyboard_add_listener(keyboard, &keyboardListener, data)
        Log.verbose("Added keyboard listener")
    }

}

func seatHandleName (data: UnsafeMutableRawPointer?, seat: OpaquePointer?,
        name: UnsafePointer<Int8>?) {
    guard let name = name, let nameString = String(cString: name, encoding: .utf8) else {
        return
    }
    Log.verbose("Seat name: \(nameString)")
}

#endif
