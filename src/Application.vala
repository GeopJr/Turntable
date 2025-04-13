namespace Turntable {
	public static bool is_flatpak = false;
	public static Mpris.Manager mpris_manager;
	public const int PROGRESS_UPDATE_TIME = 1000; // it was 250ms, turns out it updates every second?
	public static Application application;

	public static Utils.Settings settings;
	#if SCROBBLING
		public static Scrobbling.Manager scrobbling_manager;
		public static Scrobbling.AccountManager account_manager;
	#endif
	public class Application : Adw.Application {
		#if SCROBBLING
			[Signal (detailed = true)]
			public signal void token_received (Scrobbling.Manager.Provider provider, string token);
		#endif

		private const GLib.ActionEntry[] APP_ENTRIES = {
			{ "about", on_about_action },
			{ "new-window", on_new_window },
			{ "quit", quit }
		};

		string troubleshooting = "os: %s %s\nprefix: %s\nflatpak: %s\nversion: %s (%s)\ngtk: %u.%u.%u (%d.%d.%d)\nlibadwaita: %u.%u.%u (%d.%d.%d)%s".printf (
			GLib.Environment.get_os_info ("NAME"), GLib.Environment.get_os_info ("VERSION"),
			Build.PREFIX,
			Turntable.is_flatpak.to_string (),
			Build.VERSION, Build.PROFILE,
			Gtk.get_major_version (), Gtk.get_minor_version (), Gtk.get_micro_version (),
			Gtk.MAJOR_VERSION, Gtk.MINOR_VERSION, Gtk.MICRO_VERSION,
			Adw.get_major_version (), Adw.get_minor_version (), Adw.get_micro_version (),
			Adw.MAJOR_VERSION, Adw.MINOR_VERSION, Adw.MICRO_VERSION,
			#if SCROBBLING
				"\nlibsoup: %u.%u.%u (%d.%d.%d)\njson-glib: %d.%d.%d\nlibsecret: %d.%d.%d".printf (
					Soup.get_major_version (), Soup.get_minor_version (), Soup.get_micro_version (),
					Soup.MAJOR_VERSION, Soup.MINOR_VERSION, Soup.MICRO_VERSION,
					Json.MAJOR_VERSION, Json.MINOR_VERSION, Json.MICRO_VERSION,
					Secret.MAJOR_VERSION, Secret.MINOR_VERSION, Secret.MICRO_VERSION
				)
			#else
				""
			#endif
		);

		construct {
			application_id = Build.DOMAIN;
			flags = ApplicationFlags.HANDLES_OPEN;
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
			#if SCROBBLING
				account_manager = new Scrobbling.AccountManager ();
				scrobbling_manager = new Scrobbling.Manager ();
			#endif

			this.add_action_entries (APP_ENTRIES, this);
			this.set_accels_for_action ("app.quit", {"<primary>q"});
			this.set_accels_for_action ("app.new-window", {"<primary>n"});
		}

		public static int main (string[] args) {
			Intl.setlocale (LocaleCategory.ALL, "");
			Intl.bindtextdomain (Build.GETTEXT_PACKAGE, Build.LOCALEDIR);
			Intl.bind_textdomain_codeset (Build.GETTEXT_PACKAGE, "UTF-8");
			Intl.textdomain (Build.GETTEXT_PACKAGE);

			is_flatpak = GLib.Environment.get_variable ("FLATPAK_ID") != null || GLib.File.new_for_path ("/.flatpak-info").query_exists ();
			GLib.Environment.unset_variable ("GTK_THEME");
			mpris_manager = new Mpris.Manager ();
			application = new Application ();

			return application.run (args);
		}

		bool activated = false;
		public override void activate () {
			base.activate ();

			var win = this.active_window ?? new Turntable.Views.Window (this);
			win.present ();
			#if SCROBBLING
				if (!activated) account_manager.load ();
			#endif
			activated = true;
		}

		const string[] DEVELOPERS = { "Evangelos “GeopJr” Paterakis" };
		const string[] DESIGNERS = { "Evangelos “GeopJr” Paterakis" };
		const string[] ARTISTS = { "Evangelos “GeopJr” Paterakis" };
		private void on_about_action () {
			var about = new Adw.AboutDialog () {
				application_name = Build.NAME,
				application_icon = Build.DOMAIN,
				developer_name = DEVELOPERS[0],
				version = Build.VERSION,
				developers = DEVELOPERS,
				artists = ARTISTS,
				designers = DESIGNERS,
				debug_info = troubleshooting,
				debug_info_filename = @"$(Build.NAME).txt",
				copyright = @"© 2025 $(DEVELOPERS[0])",
				// translators: Name <email@domain.com> or Name https://website.example
				translator_credits = _("translator-credits")
			};

			about.add_link (_("Donate"), Build.DONATE_WEBSITE);
			//  about.add_link (_("Translate"), Build.TRANSLATE_WEBSITE);
			#if SCROBBLING
				about.comments = _("<b>Best Practices for Scrobbling</b>\n• Avoid allowlisting non-curated MPRIS clients like Web Browsers and Video Players\n• Tag your music with the proper track, album and artist names\n• Check, fix and match your scrobbles regularly");
			#endif

			// translators: Application metainfo for the app "Archives". <https://gitlab.gnome.org/GeopJr/Archives/>
			about.add_other_app ("dev.geopjr.Archives", _("Archives"), _("Create and view web archives"));
			// translators: Application metainfo for the app "Calligraphy". <https://gitlab.gnome.org/GeopJr/Calligraphy>
			about.add_other_app ("dev.geopjr.Calligraphy", _("Calligraphy"), _("Turn text into ASCII banners"));
			// translators: Application metainfo for the app "Collision". <https://github.com/GeopJr/Collision>
			about.add_other_app ("dev.geopjr.Collision", _("Collision"), _("Check hashes for your files"));
			// translators: Application metainfo for the app "Tuba". <https://github.com/GeopJr/Tuba>
			about.add_other_app ("dev.geopjr.Tuba", _("Tuba"), _("Browse the Fediverse"));

			about.present (this.active_window);

			GLib.Idle.add (() => {
				var style = Utils.Celebrate.get_celebration_css_class (new GLib.DateTime.now ());
				if (style != "") about.add_css_class (style);
				return GLib.Source.REMOVE;
			});
		}

		private void on_new_window () {
			(new Turntable.Views.Window (this)).present ();
		}

		public override void open (File[] files, string hint) {
			if (!activated) activate ();

			foreach (File file in files) {
				string unparsed_uri = file.get_uri ();

				try {
					Uri uri = Uri.parse (unparsed_uri, UriFlags.ENCODED);
					string scheme = uri.get_scheme ();

					switch (scheme) {
						case "turntable":
							string? host = uri.get_host ();
							if (host == null) host = "";

							string down_host = host.down ();
							switch (down_host) {
								#if SCROBBLING
									case "lastfm":
									case "librefm":
										string? path = uri.get_path ();
										if (path == null || path == "") throw new Error.literal (-1, 3, @"$unparsed_uri doesn't have win id");
										if (!path.has_prefix ("/")) path = @"/$path";

										string[] path_parts = path.split ("/");
										if (path_parts.length < 2 || path_parts[1].length < 4) throw new Error.literal (-1, 3, @"$unparsed_uri doesn't have win id");
										string win_id = path_parts[1];

										string? query = uri.get_query ();
										if (query == null || query == "") throw new Error.literal (-1, 3, @"$unparsed_uri doesn't have query params");

										var uri_params = Uri.parse_params (query);
										if (!uri_params.contains ("token")) throw new Error.literal (-1, 3, @"$unparsed_uri doesn't have a 'token' query param");

										token_received[win_id] (
											down_host == "librefm"
												? Scrobbling.Manager.Provider.LIBREFM
												: Scrobbling.Manager.Provider.LASTFM,
											uri_params.get ("token")
										);
										break;
								#endif
								default:
									throw new Error.literal (-1, 3, @"$(Build.NAME) does not handle '$host'");
							}

							break;
						default:
							throw new Error.literal (-1, 3, @"$(Build.NAME) does not accept '$scheme://'");
					}
				} catch (GLib.Error e) {
					string msg = @"Couldn't open $unparsed_uri: $(e.message)";
					critical (msg);
				}
			}
		}
	}
}
