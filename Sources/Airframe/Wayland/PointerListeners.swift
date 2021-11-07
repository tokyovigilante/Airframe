#if os(Linux)

import CWaylandClient
import CWaylandEGL // workaround SR-9589
import Harness
import LoggerAPI

func pointerOnEnter (data: UnsafeMutableRawPointer?, pointer: OpaquePointer?,
        serial: UInt32, surface: OpaquePointer?, fixedX: wl_fixed_t,
        fixedY: wl_fixed_t) {
    guard let data = data else {
        return
    }
    let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
            .takeUnretainedValue()
    window.pointerEnterCallback?(window)
}

func pointerOnLeave (data: UnsafeMutableRawPointer?, pointer: OpaquePointer?,
        serial: UInt32, surface: OpaquePointer?) {
    guard let data = data else {
        return
    }
    let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
            .takeUnretainedValue()
    window.pointerLeaveCallback?(window)
}

func pointerOnMotion (data: UnsafeMutableRawPointer?,
        pointer: OpaquePointer?, time: UInt32, fixedX: wl_fixed_t,
        fixedY: wl_fixed_t) {
    guard let data = data else {
        return
    }
    let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
            .takeUnretainedValue()
    window._pointer.x = wl_fixed_to_double(fixedX)
    window._pointer.y = wl_fixed_to_double(fixedY)

    let event = InputPointerEvent(
                    type: .motion,
                    time: Int(time),
                    x: window._pointer.x,
                    y: window._pointer.y,
                    button: Int(window._pointer.button),
                    state: Int(window._pointer.state),
                    modifiers: [])
    window.pointerMotionCallback?(window, event)
}

func pointerOnButton (data: UnsafeMutableRawPointer?,
        pointer: OpaquePointer?, serial: UInt32, time: UInt32, button: UInt32,
        state: UInt32) {

    var button = button
    if button >= UInt32(BTN_MOUSE) {
        button = button - UInt32(BTN_MOUSE) + 1
    } else {
        button = 0
    }
    guard let data = data else {
        return
    }
    let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
            .takeUnretainedValue()

    window._pointer.button = button//state > 0 ? button : 0
    window._pointer.state = state

    let event = InputPointerEvent(
                    type: .button,
                    time: Int(time),
                    x: window._pointer.x,
                    y: window._pointer.y,
                    button: Int(window._pointer.button),
                    state: Int(window._pointer.state),
                    modifiers: [])
    window.pointerButtonCallback?(window, event)
}

func pointerOnAxis (data: UnsafeMutableRawPointer?,
        pointer: OpaquePointer?, time: UInt32, axis: UInt32, value: wl_fixed_t) {

    guard let axisDirection = AxisDirection(waylandValue: axis) else {
        Log.error("Invalid axis \(axis)")
        return
    }
    guard let data = data else {
        return
    }
    let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
            .takeUnretainedValue()
    let event = InputAxisEvent(
        type: .motion,
        time: Int(time),
        x: window._pointer.x,
        y: window._pointer.y,
        axis: axisDirection,
        value: wl_fixed_to_int(value) > 0 ? -1 : 1,//,wl_fixed_to_double(value),
        modifiers: []
    )
    Log.debug("axis: \(event)")
    window.pointerAxisCallback?(window, event)
}
func pointerOnFrame (data: UnsafeMutableRawPointer?, pointer: OpaquePointer?) {
    /* @FIXME: buffer pointer events and handle them in frame. That's the
     * recommended usage of this interface.
     */
}

func pointerOnAxisSource (data: UnsafeMutableRawPointer?, pointer: OpaquePointer?, axisSource: UInt32) {

}

func pointerOnAxisStop (data: UnsafeMutableRawPointer?, pointer: OpaquePointer?, time: UInt32, axis: UInt32) {

}

func pointerOnAxisDiscrete (data: UnsafeMutableRawPointer?, pointer: OpaquePointer?,axis: UInt32, discrete: Int32) {

}

var pointerListener = wl_pointer_listener(
    enter: pointerOnEnter,
    leave: pointerOnLeave,
    motion: pointerOnMotion,
    button: pointerOnButton,
    axis: pointerOnAxis,
    frame: pointerOnFrame,
    axis_source: pointerOnAxisSource,
    axis_stop: pointerOnAxisStop,
    axis_discrete: pointerOnAxisDiscrete
)

extension AxisDirection {

    fileprivate init? (waylandValue: UInt32) {
        switch waylandValue {
        case WL_POINTER_AXIS_VERTICAL_SCROLL.rawValue:
            self = .vertical
        case WL_POINTER_AXIS_HORIZONTAL_SCROLL.rawValue:
            self = .horizontal
        default:
            return nil
        }
    }

    public var waylandValue: UInt32 {
        switch self {
        case .vertical:
            return WL_POINTER_AXIS_VERTICAL_SCROLL.rawValue
        case .horizontal:
            return WL_POINTER_AXIS_HORIZONTAL_SCROLL.rawValue
        }
    }
}

#endif
