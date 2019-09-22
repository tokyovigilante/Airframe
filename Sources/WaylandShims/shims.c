#ifdef __linux__
#include "include/shims.h"

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <errno.h>
#include <glib-2.0/glib.h>
#include <string.h>
#include <stdbool.h>
#include <stdio.h>
#include <wayland-client.h>

#include "../XDGShell/include/xdg-shell.h"

struct wl_interface *shim_get_interface (const char *name) {
    if (strcmp(name, wl_compositor_interface.name) == 0) {
        return (void *)&wl_compositor_interface;
    } else if (strcmp(name, wl_subcompositor_interface.name) == 0) {
        return (void *)&wl_subcompositor_interface;
    } else if (strcmp(name, wl_seat_interface.name) == 0) {
        return (void *)&wl_seat_interface;
    } else if (strcmp(name, xdg_wm_base_interface.name) == 0) {
        return (void *)&xdg_wm_base_interface;
    } else if (strcmp(name, wl_output_interface.name) == 0) {
        return (void *)&wl_output_interface;
    }
    return NULL;
}

struct xdg_surface *shim_get_xdg_surface (void *xdg_wm_base, void *surface) {
    return xdg_wm_base_get_xdg_surface(xdg_wm_base, surface);
}

struct xdg_toplevel *shim_get_xdg_toplevel(void *xdg_surface) {
    return xdg_surface_get_toplevel(xdg_surface);
}

EGLSurface shim_create_window_surface (void *eglDisplay, void *eglConfig, void *eglWindow) {
    return eglCreatePlatformWindowSurface(eglDisplay, eglConfig, eglWindow, NULL);
}

extern void *shim_create_wlbuffer_from_image (void *eglDisplay, void *image) {
    static PFNEGLCREATEWAYLANDBUFFERFROMIMAGEWL
        eglCreateWaylandBufferFromImageWL;
    if (eglCreateWaylandBufferFromImageWL == NULL) {
        eglCreateWaylandBufferFromImageWL = (PFNEGLCREATEWAYLANDBUFFERFROMIMAGEWL)
            eglGetProcAddress ("eglCreateWaylandBufferFromImageWL");
        g_assert_nonnull (eglCreateWaylandBufferFromImageWL);
    }
    struct wl_buffer *buffer = eglCreateWaylandBufferFromImageWL(eglDisplay, image);
    return (void *)buffer;
}
/* wl_event_source */

struct WaylandEventSource {
    GSource source;
    GPollFD pfd;
    struct wl_display* display;
    bool reading;
};

static gboolean wl_source_prepare (GSource *base, gint *timeout) {
    struct WaylandEventSource *source = (struct WaylandEventSource *)base;

    *timeout = -1;

    /* wl_display_prepare_read() needs to be balanced with either
     * wl_display_read_events() or wl_display_cancel_read()
     * (in gdk_event_source_check() */
    if (source->reading) {
        return FALSE;
    }

    /* if prepare_read() returns non-zero, there are events to be dispatched */
    if (wl_display_prepare_read(source->display) != 0) {
        return TRUE;
    }
    source->reading = TRUE;

    if (wl_display_flush(source->display) < 0) {
        fprintf(stderr, "Error flushing display: %s", strerror(errno));
        exit(1);
    }
    return FALSE;
}

static gboolean wl_source_check (GSource *base) {
    struct WaylandEventSource *source = (struct WaylandEventSource *)base;

    /* read the events from the wayland fd into their respective queues if we have data */
    if (source->reading) {
        if (source->pfd.revents & G_IO_IN) {
            if (wl_display_read_events (source->display) < 0) {
                fprintf(stderr, "Error reading events from display: %s", strerror(errno));
                exit(1);
            }
        } else {
            wl_display_cancel_read (source->display);
        }
        source->reading = FALSE;
    }
    return source->pfd.revents;
}

static gboolean wl_source_dispatch (GSource *base, GSourceFunc callback, gpointer user_data) {
    struct WaylandEventSource *source = (struct WaylandEventSource *)base;

    if (source->pfd.revents & G_IO_IN) {
        if (wl_display_dispatch_pending(source->display) < 0) {
            return FALSE;
        }
    }
    if (source->pfd.revents & (G_IO_ERR | G_IO_HUP)) {
        return FALSE;
    }
    source->pfd.revents = 0;
    return TRUE;
}

static void wl_source_finalize (GSource *base) {
    struct WaylandEventSource *source = (struct WaylandEventSource *)base;

    if (source->reading) {
        wl_display_cancel_read(source->display);
    }
    source->reading = FALSE;
}

void *setup_wayland_event_source (void *display) {
    static GSourceFuncs wl_source_funcs = {
        .prepare = wl_source_prepare,
        .check = wl_source_check,
        .dispatch = wl_source_dispatch,
        .finalize = wl_source_finalize,
    };

    struct WaylandEventSource *wl_source =
            (struct WaylandEventSource *)g_source_new(&wl_source_funcs,
            sizeof(struct WaylandEventSource));
    wl_source->display = display;
    wl_source->pfd.fd = wl_display_get_fd(display);
    wl_source->pfd.events = G_IO_IN | G_IO_ERR | G_IO_HUP;
    wl_source->pfd.revents = 0;
    wl_source->reading = FALSE;
    g_source_add_poll(&wl_source->source, &wl_source->pfd);

    g_source_set_priority(&wl_source->source, G_PRIORITY_HIGH + 30);
    g_source_set_can_recurse(&wl_source->source, TRUE);
    g_source_attach(&wl_source->source, NULL);

    g_source_unref(&wl_source->source);

    return (void *)wl_source;
}





static void
wl_src_finalize (GSource *base)
{
}

#endif // __linux__
