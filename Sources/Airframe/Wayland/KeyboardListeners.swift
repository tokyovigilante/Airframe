#if os(Linux)

import CWaylandClient
import CWaylandEGL // workaround SR-9589
import CXKBCommon
import Glibc
import CGLib
import LoggerAPI

func keyboardOnKeymap(data: UnsafeMutableRawPointer?,
        wl_keyboard: OpaquePointer?, format: UInt32, fd: Int32, size: UInt32) {
    if format != WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1.rawValue {
        close (fd)
        return
    }

    let mapping = mmap(nil, Int(size), PROT_READ, MAP_PRIVATE, fd, 0)
    if mapping == MAP_FAILED {
        close(fd)
        return
    }

    guard let data = data else {
        close(fd)
        return
    }
    let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
            .takeUnretainedValue()
    guard let mapString = mapping?.bindMemory(to: Int8.self, capacity: Int(size)) else {
        close(fd)
        return
    }
    window._xkb.keymap = xkb_keymap_new_from_string(window._xkb.context, mapString,
            XKB_KEYMAP_FORMAT_TEXT_V1, XKB_KEYMAP_COMPILE_NO_FLAGS)
    munmap (mapping, Int(size))
    close (fd)

    if window._xkb.keymap == nil {
        return
    }

    window._xkb.state = xkb_state_new(window._xkb.keymap)
    if window._xkb.state == nil {
        return
    }

    window._xkb.indices.control =
            xkb_keymap_mod_get_index(window._xkb.keymap, XKB_MOD_NAME_CTRL)
    window._xkb.indices.alt =
            xkb_keymap_mod_get_index(window._xkb.keymap, XKB_MOD_NAME_ALT)
    window._xkb.indices.shift =
            xkb_keymap_mod_get_index(window._xkb.keymap, XKB_MOD_NAME_SHIFT)
}

func keyboardOnEnter (data: UnsafeMutableRawPointer?,
        wl_keyboard: OpaquePointer?, serial: UInt32, surface: OpaquePointer?,
        keys: UnsafeMutablePointer<wl_array>?) {
    guard let data = data else {
        return
    }
    let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
            .takeUnretainedValue()
    assert(surface == window.wlSurface)
    window._keyboard.serial = serial
}

func keyboardOnLeave (data: UnsafeMutableRawPointer?, keyboard: OpaquePointer?,
        serial: UInt32, surface: OpaquePointer?) {
    guard let data = data else {
        return
    }
    let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
            .takeUnretainedValue()
    window._keyboard.serial = serial
}

func captureAppKeyBindings (window: WaylandWSIWindow, keysym: UInt32,
        unicode: UInt32, state: UInt32, modifiers: InputModifier) -> Bool {
    /*CogLauncher *launcher = cog_launcher_get_default ();
    WebKitWebView *web_view =
        cog_shell_get_web_view (cog_launcher_get_shell (launcher));

    if (state == WL_KEYBOARD_KEY_STATE_PRESSED) {
        /* fullscreen */
        if (modifiers == 0 && unicode == 0 && keysym == XKB_KEY_F11) {
            if (! win_data.is_fullscreen)
                zxdg_toplevel_v6_set_fullscreen (win_data.xdg_toplevel, NULL);
            else
                zxdg_toplevel_v6_unset_fullscreen (win_data.xdg_toplevel);
            win_data.is_fullscreen = ! win_data.is_fullscreen;
            return true;
        }
        /* Ctrl+W, exit the application */
        else if (modifiers == wpe_input_keyboard_modifier_control &&
                 unicode == 0x17 && keysym == 0x77) {
            g_application_quit (G_APPLICATION (launcher));
            return true;
        }
        /* Ctrl+Plus, zoom in */
        else if (modifiers == wpe_input_keyboard_modifier_control &&
                 unicode == XKB_KEY_equal && keysym == XKB_KEY_equal) {
            const double level = webkit_web_view_get_zoom_level (web_view);
            webkit_web_view_set_zoom_level (web_view,
                                            level + DEFAULT_ZOOM_STEP);
            return true;
        }
        /* Ctrl+Minus, zoom out */
        else if (modifiers == wpe_input_keyboard_modifier_control &&
                 unicode == 0x2D && keysym == 0x2D) {
            const double level = webkit_web_view_get_zoom_level (web_view);
            webkit_web_view_set_zoom_level (web_view,
                                            level - DEFAULT_ZOOM_STEP);
            return true;
        }
        /* Ctrl+0, restore zoom level to 1.0 */
        else if (modifiers == wpe_input_keyboard_modifier_control &&
                 unicode == XKB_KEY_0 && keysym == XKB_KEY_0) {
            webkit_web_view_set_zoom_level (web_view, 1.0f);
            return true;
        }
        /* Alt+Left, navigate back */
        else if (modifiers == wpe_input_keyboard_modifier_alt &&
                 unicode == 0 && keysym == XKB_KEY_Left) {
            webkit_web_view_go_back (web_view);
            return true;
        }
        /* Alt+Right, navigate forward */
        else if (modifiers == wpe_input_keyboard_modifier_alt &&
                 unicode == 0 && keysym == XKB_KEY_Right) {
            webkit_web_view_go_forward (web_view);
            return true;
        }
    }
    */
    return false
}

func handleKeyEvent (window: WaylandWSIWindow, key: UInt32, state: UInt32,
        time: UInt32) {
    var keysym = xkb_state_key_get_one_sym(window._xkb.state, key)
    var unicode = xkb_state_key_get_utf32 (window._xkb.state, key)

    /* Capture app-level key-bindings here */
    if captureAppKeyBindings (window: window, keysym: keysym, unicode: unicode,
            state: state, modifiers: window._xkb.modifiers) {
        return
    }

    if window._xkb.composeState != nil
            && state == WL_KEYBOARD_KEY_STATE_PRESSED.rawValue
            && xkb_compose_state_feed(window._xkb.composeState, keysym) ==
                    XKB_COMPOSE_FEED_ACCEPTED
            && xkb_compose_state_get_status(window._xkb.composeState) ==
                    XKB_COMPOSE_COMPOSED {
        keysym = xkb_compose_state_get_one_sym(window._xkb.composeState)
        unicode = xkb_keysym_to_utf32(keysym)
    }

    let event = InputKeyboardEvent(
        time: time,
        keyCode: keysym,
        hardwareKeyCode: unicode,
        pressed: state != 0,
        modifiers: window._xkb.modifiers
    )
    window.keyCallback?(window, event)
}

func repeatDelayTimeout (data: UnsafeMutableRawPointer?) -> Int32 {
    guard let data = data else {
        return G_SOURCE_REMOVE
    }
    let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
            .takeUnretainedValue()

    handleKeyEvent(window: window, key: window._keyboard.repeatData.key,
            state: window._keyboard.repeatData.state,
            time: window._keyboard.repeatData.time)

    window._keyboard.repeatData.eventSource =
            g_timeout_add(window._keyboard.repeatInfo.rate, repeatDelayTimeout, data)
    return G_SOURCE_REMOVE
}

func keyboardOnKey (data: UnsafeMutableRawPointer?, wl_keyboard: OpaquePointer?,
        serial: UInt32, time: UInt32, key: UInt32, state: UInt32) {
    /* offset evdev scancode */
    let key = key + 8

    guard let data = data else {
            return
        }
    let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
            .takeUnretainedValue()
    window._keyboard.serial = serial
    handleKeyEvent(window: window, key: key, state: state, time: time)

    if window._keyboard.repeatInfo.rate == 0 {
        return
    }
    if state == WL_KEYBOARD_KEY_STATE_RELEASED.rawValue
            && window._keyboard.repeatData.key == key {
        if window._keyboard.repeatData.eventSource > 0 {
            g_source_remove(window._keyboard.repeatData.eventSource)
        }
        window._keyboard.repeatData = (0, 0, 0, 0)
    } else if state == WL_KEYBOARD_KEY_STATE_PRESSED.rawValue
            && xkb_keymap_key_repeats(window._xkb.keymap, key) != 0 {
        if window._keyboard.repeatData.eventSource > 0 {
            g_source_remove (window._keyboard.repeatData.eventSource)
        }
        window._keyboard.repeatData.key = key
        window._keyboard.repeatData.time = time
        window._keyboard.repeatData.state = state
        window._keyboard.repeatData.eventSource = g_timeout_add(
                window._keyboard.repeatInfo.delay, repeatDelayTimeout, data)
    }
}

func keyboardOnModifiers (data: UnsafeMutableRawPointer?,
        wl_keyboard: OpaquePointer?, serial: UInt32, mods_depressed: UInt32,
        mods_latched: UInt32, mods_locked: UInt32, group: UInt32) {
    guard let data = data else {
            return
        }
    let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
            .takeUnretainedValue()

    xkb_state_update_mask(window._xkb.state, mods_depressed, mods_latched,
            mods_locked, 0, 0, group)

    window._xkb.modifiers = []
    let component: xkb_state_component = XKB_STATE_MODS_EFFECTIVE

    if xkb_state_mod_index_is_active(window._xkb.state,
            window._xkb.indices.control, component) == 1 {
        window._xkb.modifiers.insert(.control)
    }
    if xkb_state_mod_index_is_active(window._xkb.state,
            window._xkb.indices.alt, component) == 1 {
        window._xkb.modifiers.insert(.alt)
    }
    if xkb_state_mod_index_is_active (window._xkb.state,
            window._xkb.indices.shift, component) == 1 {
        window._xkb.modifiers.insert(.shift)
    }
}
func keyboardOnRepeatInfo (data: UnsafeMutableRawPointer?,
        wl_keyboard: OpaquePointer?, rate: Int32, delay: Int32) {
    guard let data = data else {
            return
        }
    let window = Unmanaged<WaylandWSIWindow>.fromOpaque(data)
            .takeUnretainedValue()

    window._keyboard.repeatInfo.rate = UInt32(rate)
    window._keyboard.repeatInfo.delay = UInt32(delay)

    /* a rate of zero disables any repeating. */
    if rate == 0 && window._keyboard.repeatData.eventSource > 0 {
        g_source_remove(window._keyboard.repeatData.eventSource)
        window._keyboard.repeatData = (0, 0, 0, 0)
    }
}

var keyboardListener = wl_keyboard_listener(
    keymap: keyboardOnKeymap,
    enter: keyboardOnEnter,
    leave: keyboardOnLeave,
    key: keyboardOnKey,
    modifiers: keyboardOnModifiers,
    repeat_info: keyboardOnRepeatInfo
)


#endif
