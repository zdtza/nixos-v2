/* gtk-live-css -- retheme running GTK apps in place, no restart.
 *
 * GTK reads ~/.config/gtk-{3,4}.0/gtk.css exactly once, in settings_init_style(),
 * into a process-static GtkCssProvider with no file monitor attached. That is
 * the whole reason a stylix theme switch only shows up in apps started after
 * it: nothing ever re-reads the file. This preload adds a *second* provider at
 * user priority that does watch its file, so rewriting
 * ~/.cache/gtk-live-<major>.css restyles every open GTK window in place.
 *
 * Every GTK/GLib entry point is resolved with dlsym against whatever the host
 * process already loaded, and this .so links nothing but libc. One build
 * therefore serves GTK3 and GTK4 alike, and costs a no-op mmap in a process
 * that has neither -- which matters, because LD_PRELOAD is set for the whole
 * session (see gtk-live-css.nix), not just for GTK apps.
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <glib.h>
#include <gio/gio.h>

/* Resolve from the app's own already-loaded libraries, never from ourselves. */
#define SYM(name) dlsym(RTLD_DEFAULT, (name))

/* GTK_STYLE_PROVIDER_PRIORITY_USER is 800 and is what GTK gives the config
 * file above; +1 so our copy wins that tie regardless of load order (and it is
 * far above libadwaita's stylesheet, which sits at THEME/200). Hardcoded
 * rather than included: the constant lives in gtk headers, and pulling in
 * either gtk3's or gtk4's would tie this build to one of them. */
#define PRIORITY 801

/* G_FILE_MONITOR_WATCH_MOVES: the writer swaps the file in with rename(2), so
 * without this an atomic replace can arrive as a bare delete. */
#define WATCH_MOVES 8

static void *provider; /* GtkCssProvider *, owned by the display's cascade */
static char css_path[4096];
static int debug;

#define DBG(...)                                        \
  do {                                                  \
    if (debug) {                                        \
      fprintf(stderr, "gtk-live-css[%d]: ", getpid());  \
      fprintf(stderr, __VA_ARGS__);                     \
    }                                                   \
  } while (0)

/* Reparse the file into the live provider. GTK emits GtkStyleProvider::changed
 * from here, the cascade re-resolves, and every widget restyles -- the same
 * path GTK itself uses when the theme name changes. */
static void load(void) {
  void *fn = SYM("gtk_css_provider_load_from_path");

  if (!fn || !provider)
    return;

  if (SYM("gtk_style_context_add_provider_for_display")) /* GTK4: (provider, path) */
    ((void (*)(void *, const char *))fn)(provider, css_path);
  else /* GTK3: (provider, path, GError **) */
    ((int (*)(void *, const char *, void *))fn)(provider, css_path, NULL);

  DBG("loaded %s\n", css_path);
}

static void on_changed(void *monitor, void *file, void *other, int event, void *data) {
  (void)monitor;
  (void)file;
  (void)other;
  (void)data;

  /* Reload on every event kind: a rename-over lands as CREATED, RENAMED or
   * CHANGES_DONE_HINT depending on backend, and reloading is idempotent. */
  DBG("event %d\n", event);
  load();
}

static void resolve_path(void) {
  const char *env = getenv("GTK_LIVE_CSS");
  const char *(*cache_dir)(void);
  unsigned (*major)(void);

  if (env && *env) {
    snprintf(css_path, sizeof css_path, "%s", env);
    return;
  }

  cache_dir = SYM("g_get_user_cache_dir");
  major = SYM("gtk_get_major_version");
  snprintf(css_path, sizeof css_path, "%s/gtk-live-%u.css",
           cache_dir ? cache_dir() : getenv("HOME"), major ? major() : 4);
}

/* Runs from the app's main loop, where a display exists. */
static gboolean install(gpointer data) {
  static int tries;
  void *(*provider_new)(void);
  void (*add_for_display)(void *, void *, unsigned);
  void (*add_for_screen)(void *, void *, unsigned);
  void *(*get_display)(void);
  void *(*get_screen)(void);
  void *(*file_new)(const char *);
  void *(*monitor_file)(void *, int, void *, void *);
  unsigned long (*connect_data)(void *, const char *, void *, void *, void *, int);
  void *target, *file, *monitor;

  (void)data;

  provider_new = SYM("gtk_css_provider_new");
  if (!provider_new) {
    DBG("no GTK in this process\n");
    return G_SOURCE_REMOVE;
  }

  add_for_display = SYM("gtk_style_context_add_provider_for_display"); /* GTK4 only */
  add_for_screen = SYM("gtk_style_context_add_provider_for_screen");   /* GTK3 only */
  get_display = SYM("gdk_display_get_default");
  get_screen = SYM("gdk_screen_get_default");

  target = add_for_display ? (get_display ? get_display() : NULL)
                           : (get_screen ? get_screen() : NULL);

  if (!target) {
    /* GtkApplication opens the display in ::startup, which can land after our
     * first tick. A remote instance (second `nautilus` invocation) never opens
     * one at all, so cap the retries instead of polling for the process's life. */
    if (++tries < 40)
      return G_SOURCE_CONTINUE;
    DBG("no display after %d tries, giving up\n", tries);
    return G_SOURCE_REMOVE;
  }

  resolve_path();
  provider = provider_new();
  load();

  if (add_for_display)
    add_for_display(target, provider, PRIORITY);
  else if (add_for_screen)
    add_for_screen(target, provider, PRIORITY);

  file_new = SYM("g_file_new_for_path");
  monitor_file = SYM("g_file_monitor_file");
  connect_data = SYM("g_signal_connect_data");

  if (file_new && monitor_file && connect_data) {
    file = file_new(css_path);
    monitor = monitor_file(file, WATCH_MOVES, NULL, NULL);
    if (monitor)
      connect_data(monitor, "changed", (void *)on_changed, NULL, NULL, 0);
    DBG("installed, watching %s (monitor %s)\n", css_path, monitor ? "ok" : "FAILED");
  }

  return G_SOURCE_REMOVE;
}

static void schedule(void) {
  static int scheduled;
  unsigned (*timeout_add)(unsigned, GSourceFunc, gpointer);

  if (scheduled)
    return;

  debug = getenv("GTK_LIVE_CSS_DEBUG") != NULL;
  timeout_add = SYM("g_timeout_add");
  if (!timeout_add)
    return;

  scheduled = 1;
  /* Queued before the loop starts; fires 50ms into it, by which point
   * GtkApplication has finished ::startup and opened its display. */
  timeout_add(50, install, NULL);
}

/* Hook points, both called from the application's own main() and so reachable
 * through the PLT. gtk_init is not: GTK builds with -fvisibility=hidden and
 * GtkApplication calls it internally, bypassing interposition. */

/* Signature has to match gio's declaration exactly, not a void * lookalike. */
int g_application_run(GApplication *app, int argc, char **argv) {
  static int (*real)(GApplication *, int, char **);

  if (!real)
    real = dlsym(RTLD_NEXT, "g_application_run");
  schedule();

  return real(app, argc, argv);
}

void gtk_main(void) { /* GTK3 apps that never touch GApplication */
  static void (*real)(void);

  if (!real)
    real = dlsym(RTLD_NEXT, "gtk_main");
  schedule();

  if (real)
    real();
}
