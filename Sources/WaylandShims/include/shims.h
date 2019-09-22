#ifdef __linux__
#ifndef __WAYLAND_SHIM_H__
#define __WAYLAND_SHIM_H__

extern struct wl_interface *shim_get_interface (const char *name);

extern struct xdg_surface *shim_get_xdg_surface(void *xdg_wm_base, void *surface);
extern struct xdg_toplevel *shim_get_xdg_toplevel(void *xdg_surface);


extern void *shim_create_window_surface (void *eglDisplay, void *eglConfig,
                                  void *eglWindow);

extern void *shim_create_wlbuffer_from_image (void *eglDisplay, void *image);

void *setup_wayland_event_source (void *display);
#endif // __WAYLAND_SHIM_H__
#endif // __linux__
