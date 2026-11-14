#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <cstring>
#ifdef GDK_WINDOWING_WAYLAND
#include <gdk/gdkwayland.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlMethodChannel* window_channel;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Window controls for the Flutter-drawn bar ("open_chess/window" channel).
static void start_drag(GtkWindow* window, gint edge) {
  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
  GdkSeat* seat = gdk_display_get_default_seat(gdk_window_get_display(gdk_window));
  gint x = 0, y = 0;
  gdk_device_get_position(gdk_seat_get_pointer(seat), nullptr, &x, &y);
  // Wayland takes the serial of the button press still held; X11 the time.
  if (edge < 0) {
    gtk_window_begin_move_drag(window, 1, x, y, GDK_CURRENT_TIME);
  } else {
    gtk_window_begin_resize_drag(window, static_cast<GdkWindowEdge>(edge), 1,
                                 x, y, GDK_CURRENT_TIME);
  }
}

static void window_method_cb(FlMethodChannel* channel, FlMethodCall* call,
                             gpointer user_data) {
  GtkWindow* window = GTK_WINDOW(user_data);
  const gchar* method = fl_method_call_get_name(call);
  if (strcmp(method, "startDrag") == 0) {
    start_drag(window, -1);
  } else if (strcmp(method, "startResize") == 0) {
    FlValue* args = fl_method_call_get_args(call);
    if (fl_value_get_type(args) == FL_VALUE_TYPE_INT) {
      gint64 edge = fl_value_get_int(args);
      if (edge >= GDK_WINDOW_EDGE_NORTH_WEST &&
          edge <= GDK_WINDOW_EDGE_SOUTH_EAST) {
        start_drag(window, static_cast<gint>(edge));
      }
    }
  } else if (strcmp(method, "minimize") == 0) {
    gtk_window_iconify(window);
  } else if (strcmp(method, "toggleMaximize") == 0) {
    if (gtk_window_is_maximized(window)) {
      gtk_window_unmaximize(window);
    } else {
      gtk_window_maximize(window);
    }
  } else if (strcmp(method, "close") == 0) {
    // Same request as the system close button (delete-event).
    gtk_window_close(window);
  } else {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  fl_method_call_respond_success(call, nullptr, nullptr);
}

static gboolean window_state_cb(GtkWidget* widget, GdkEventWindowState* event,
                                gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  GdkWindowState state = event->new_window_state;
  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string_take(
      map, "maximized",
      fl_value_new_bool((state & GDK_WINDOW_STATE_MAXIMIZED) != 0));
  fl_value_set_string_take(
      map, "framed",
      fl_value_new_bool((state & (GDK_WINDOW_STATE_MAXIMIZED |
                                  GDK_WINDOW_STATE_FULLSCREEN |
                                  GDK_WINDOW_STATE_TILED)) == 0));
  fl_method_channel_invoke_method(self->window_channel, "state", map, nullptr,
                                  nullptr, nullptr);
  return FALSE;
}

// An undecorated GTK3 window asks KWin (and other compositors with server
// decorations) for a system frame on Wayland; say the client draws it.
static void window_realize_cb(GtkWidget* widget, gpointer) {
#ifdef GDK_WINDOWING_WAYLAND
  GdkWindow* gdk_window = gtk_widget_get_window(widget);
  if (GDK_IS_WAYLAND_WINDOW(gdk_window)) {
    gdk_wayland_window_announce_csd(gdk_window);
  }
#endif
}

static void setup_window_channel(MyApplication* self, GtkWindow* window,
                                 FlView* view) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlPluginRegistrar) registrar =
      fl_plugin_registry_get_registrar_for_plugin(FL_PLUGIN_REGISTRY(view),
                                                  "OpenChessWindow");
  self->window_channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "open_chess/window",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->window_channel,
                                            window_method_cb, window, nullptr);
  g_signal_connect(window, "window-state-event", G_CALLBACK(window_state_cb),
                   self);
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // The app draws its own window bar (lib/src/widgets/window_chrome.dart),
  // so the window has no system title bar or frame on Wayland or X11.
  gtk_window_set_title(window, "Open Chess");
  gtk_window_set_decorated(window, FALSE);
  g_signal_connect(window, "realize", G_CALLBACK(window_realize_cb), nullptr);
  // Smallest size at which the merged bar still fits a game screen's actions.
  GdkGeometry min_size = {};
  min_size.min_width = 720;
  min_size.min_height = 480;
  gtk_window_set_geometry_hints(window, nullptr, &min_size, GDK_HINT_MIN_SIZE);
  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));
  setup_window_channel(self, window, view);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->window_channel);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
