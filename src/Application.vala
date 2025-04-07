namespace Turntable {
	public static bool is_flatpak = false;
	public static Mpris.Manager mpris_manager;
	public const int PROGRESS_UPDATE_TIME = 250;

	public static Utils.Settings settings;
	public class Application : Adw.Application {
		private const GLib.ActionEntry[] APP_ENTRIES = {
			{ "about", on_about_action },
			{ "new-window", on_new_window },
			{ "quit", quit }
		};

		string troubleshooting = "os: %s %s\nprefix: %s\nflatpak: %s\nversion: %s (%s)\ngtk: %u.%u.%u (%d.%d.%d)\nlibadwaita: %u.%u.%u (%d.%d.%d)".printf ( // vala-lint=line-length
			GLib.Environment.get_os_info ("NAME"), GLib.Environment.get_os_info ("VERSION"),
			Build.PREFIX,
			Turntable.is_flatpak.to_string (),
			Build.VERSION, Build.PROFILE,
			Gtk.get_major_version (), Gtk.get_minor_version (), Gtk.get_micro_version (),
			Gtk.MAJOR_VERSION, Gtk.MINOR_VERSION, Gtk.MICRO_VERSION,
			Adw.get_major_version (), Adw.get_minor_version (), Adw.get_micro_version (),
			Adw.MAJOR_VERSION, Adw.MINOR_VERSION, Adw.MICRO_VERSION
		);

		construct {
			application_id = Build.DOMAIN;
			flags = ApplicationFlags.DEFAULT_FLAGS;
		}

		protected override void startup () {
			base.startup ();

			try {
				var lines = troubleshooting.split ("\n");
				foreach (unowned string line in lines) {
					debug (line);
				}
				Gtk.Window.set_default_icon_name (Build.DOMAIN);
				Adw.init ();
			} catch (Error e) {
				var msg = "Could not start application: %s".printf (e.message);
				error (msg);
			}

			settings = new Utils.Settings ();

			this.add_action_entries (APP_ENTRIES, this);
			this.set_accels_for_action ("app.quit", {"<primary>q"});
		}

		public static int main (string[] args) {
			Intl.setlocale (LocaleCategory.ALL, "");
			Intl.bindtextdomain (Build.GETTEXT_PACKAGE, Build.LOCALEDIR);
			Intl.bind_textdomain_codeset (Build.GETTEXT_PACKAGE, "UTF-8");
			Intl.textdomain (Build.GETTEXT_PACKAGE);

			is_flatpak = GLib.Environment.get_variable ("FLATPAK_ID") != null || GLib.File.new_for_path ("/.flatpak-info").query_exists ();
			GLib.Environment.unset_variable ("GTK_THEME");
			mpris_manager = new Mpris.Manager ();

			return (new Application ()).run (args);
		}

		public override void activate () {
			base.activate ();
			var win = this.active_window ?? new Turntable.Views.Window (this);
			win.present ();
		}

		private void on_about_action () {
			string[] developers = { "Evangelos Paterakis" };
			var about = new Adw.AboutDialog () {
				application_name = "turntable",
				application_icon = "dev.geopjr.Turntable",
				developer_name = "Evangelos Paterakis",
				translator_credits = _("translator-credits"),
				version = "0.1.0",
				developers = developers,
				copyright = "© 2025 Evangelos Paterakis",
			};

			about.present (this.active_window);
		}

		private void on_new_window () {
			(new Turntable.Views.Window (this)).present ();
		}
	}
}
