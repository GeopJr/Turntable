public class Turntable.Views.ScrobblerSetup : Adw.PreferencesDialog {
	protected Soup.Session session { get; set; }

	public class ScrobblerRow : Adw.ActionRow {
		public signal void added (Scrobbling.Manager.Provider provider);
		public signal void trashed (Scrobbling.Manager.Provider provider);
		public Scrobbling.Manager.Provider provider { get; set; }

		public enum State {
			NEW,
			EXISTS,
			LOADING;
		}

		private State _state = NEW;
		public State state {
			get { return _state; }
			set {
				switch (value) {
					case NEW:
						trash_button.visible = false;
						spinner.visible = false;
						next_icon.visible = true;
						this.activatable = true;
						break;
					case EXISTS:
						trash_button.visible = true;
						spinner.visible = false;
						next_icon.visible = false;
						this.activatable = false;
						break;
					default:
						trash_button.visible = false;
						spinner.visible = true;
						next_icon.visible = false;
						this.activatable = false;
						break;
				}

				_state = value;
			}
		}

		Gtk.Button trash_button;
		Gtk.Image next_icon;
		Adw.Spinner spinner;
		public ScrobblerRow (Scrobbling.Manager.Provider provider, bool exists) {
			this.provider = provider;
			this.title = provider.to_string ();
			this.add_prefix (new Gtk.Image.from_icon_name (provider.to_icon_name ()) {
				icon_size = Gtk.IconSize.LARGE
			});

			spinner = new Adw.Spinner ();
			next_icon = new Gtk.Image.from_icon_name (Gtk.Widget.get_default_direction () == Gtk.TextDirection.RTL ? "left-large-symbolic" : "right-large-symbolic");
			trash_button = new Gtk.Button.from_icon_name ("user-trash-symbolic") {
				valign = Gtk.Align.CENTER,
				halign = Gtk.Align.CENTER,
				// translators: variable is a scrobbler e.g. ListenBrainz
				tooltip_text = _("Forget %s Account").printf (this.title),
				css_classes = { "flat", "error" }
			};
			trash_button.clicked.connect (on_trash);
			this.state = exists ? State.EXISTS : State.NEW;

			this.add_suffix (trash_button);
			this.add_suffix (next_icon);
			this.add_suffix (spinner);

			this.activated.connect (on_activate);
		}

		private void on_trash () {
			trashed (this.provider);
		}

		private void on_activate () {
			added (this.provider);
		}
	}

	//  private string generate_all_scrobblers_list () {
	//  	GLib.StringBuilder all_scrobblers = new GLib.StringBuilder ();
	//  	int total_providers = Scrobbling.Manager.ALL_PROVIDERS.length;
	//  	for (int i = 0; i < total_providers; i++) {
	//  		all_scrobblers.append (Scrobbling.Manager.ALL_PROVIDERS[i].to_string ());
	//  		if (i < total_providers - 2) {
	//  			all_scrobblers.append (", ");
	//  		} else if (i < total_providers - 1) {
	//  			all_scrobblers.append (" &amp; ");
	//  		}
	//  	}

	//  	return all_scrobblers.str;
	//  }

	Adw.SwitchRow mbid_row;
	Adw.SwitchRow now_playing_row;
	Gtk.Switch offline_scrobbling_switch;
	string win_id;
	GLib.HashTable<string, ScrobblerRow> provider_rows = new GLib.HashTable<string, ScrobblerRow> (str_hash, str_equal);
	construct {
		session = new Soup.Session () {
			user_agent = @"$(Build.NAME)/$(Build.VERSION) libsoup/$(Soup.get_major_version()).$(Soup.get_minor_version()).$(Soup.get_micro_version()) ($(Soup.MAJOR_VERSION).$(Soup.MINOR_VERSION).$(Soup.MICRO_VERSION))" // vala-lint=line-length
		};

		// translators: probably leave it as is unless there's a way to describe it accurately
		this.title = _("Scrobblers");

		var main_page = new Adw.PreferencesPage () {
			icon_name = "network-server-symbolic",
			// translators: scrobbling dialog tab title of the page that allows you to setup your accounts
			//				services as in "Scrobbling Services", if it's easier, translate it into "Platforms" or "Providers"
			title = _("Services"),
			// translators: warning shown in the scrobbler setup window. Leave MPRIS as is. The variable is the app name (Turntable)
			description = _("Track your music by scrobbling your MPRIS clients. By connecting your account, MPRIS information will be sent to that service when you reach the minimum listening time. To protect your privacy, %s requires you to opt-in scrobbling per MPRIS client.").printf (Build.NAME)
		};

		var main_group = new Adw.PreferencesGroup ();
		foreach (var provider in Scrobbling.Manager.ALL_PROVIDERS) {
			var row = new ScrobblerRow (provider, false);
			row.added.connect (on_add);
			row.trashed.connect (on_trash);
			main_group.add (row);
			provider_rows.set (provider.to_string (), row);
		}
		main_page.add (main_group);
		this.add (main_page);

		var settings_page = new Adw.PreferencesPage () {
			icon_name = "settings-symbolic",
			title = _("Settings")
		};
		var settings_group = new Adw.PreferencesGroup ();
		var offline_scrobbling_row = new Adw.ActionRow () {
			activatable = true,
			// translators: row title
			title = _("Offline Scrobbling"),
			// translators: row description
			subtitle = _("Scrobble even when you are offline and submit them automatically when you get online.")
		};
		offline_scrobbling_row.activated.connect (open_offline_scrobbling_page);

		offline_scrobbling_switch = new Gtk.Switch () {
			active = settings.offline_scrobbling,
			valign = CENTER,
			halign = CENTER
		};
		offline_scrobbling_switch.notify["active"].connect (offline_changed);
		offline_scrobbling_row.add_suffix (offline_scrobbling_switch);
		offline_scrobbling_row.add_suffix (new Gtk.Image.from_icon_name (Gtk.Widget.get_default_direction () == Gtk.TextDirection.RTL ? "left-large-symbolic" : "right-large-symbolic"));
		settings_group.add (offline_scrobbling_row);

		now_playing_row = new Adw.SwitchRow () {
			active = settings.now_playing,
			// translators: as explained later, "Now Playing" means the currently playing song even if it hasn't hit the scrobbling mark, please make sure they are not confused with each other, this doesn't mean scrobbling.
			title = _("Submit Now Playing"),
			// translators: switch description
			subtitle = _("Indicate that you started listening to a track.")
		};
		now_playing_row.notify["active"].connect (np_changed);
		settings_group.add (now_playing_row);

		mbid_row = new Adw.SwitchRow () {
			active = settings.mbid_required,
			// translators: switch title; lookup = search, fetch, request
			title = _("Lookup Metadata on MusicBrainz before Scrobbling"),
			// translators: switch description; untagged as in music files missing metadata like artist, album etc
			subtitle = _("Recommended for non-curated clients or untagged music libraries as it will fix and complete metadata but it will also prevent scrobbling tracks not found in the MusicBrainz library.")
		};
		mbid_row.notify["active"].connect (mbid_required_changed);
		settings_group.add (mbid_row);
		settings_page.add (settings_group);
		this.add (settings_page);

		win_id = ((Views.Window) application.active_window).uuid;
		application.token_received[win_id].connect (on_token_received);
		account_manager.accounts_changed.connect (update_row_states);
		update_row_states ();
	}

	private void open_offline_scrobbling_page () {
		this.push_subpage (new Views.OfflineScrobbling ());
	}

	private void offline_changed () {
		settings.offline_scrobbling = offline_scrobbling_switch.active;
	}

	private void np_changed () {
		settings.now_playing = now_playing_row.active;
	}

	private void mbid_required_changed () {
		settings.mbid_required = mbid_row.active;
	}

	private void update_row_states () {
		debug ("Updating Row States");
		provider_rows.foreach ((provider, row) => {
			if (row.state != ScrobblerRow.State.LOADING) {
				bool exists = account_manager.accounts.contains (provider);

				row.state = exists ? ScrobblerRow.State.EXISTS : ScrobblerRow.State.NEW;

				string subtitle = "";
				if (exists) {
					var acc = account_manager.accounts.get (provider);
					subtitle = acc.username;
					if (acc.custom_url != null) {
						string custom_url = acc.custom_url;
						try {
							custom_url = GLib.Uri.parse (custom_url, GLib.UriFlags.NONE).get_host ();
						} catch {
							custom_url = custom_url.replace ("https://", "");
						}

						subtitle = @"$subtitle - $custom_url";
					}
				}
				row.subtitle = subtitle;
			}
		});
	}

	private void on_trash (Scrobbling.Manager.Provider provider) {
		debug ("Forgetting %s", provider.to_string ());

		var dlg = new Adw.AlertDialog (
			_("Forget %s Account?").printf (provider.to_string ()),
			// translators: dialog description
			_("This won't affect your submitted scrobbles.")
		);

		dlg.add_responses (
			"cancel", _("_Cancel"),
			"forget", _("_Forget")
		);
		dlg.set_default_response ("forget");
		dlg.set_response_appearance ("forget", Adw.ResponseAppearance.DESTRUCTIVE);

		dlg.choose.begin (this, null, (obj, res) => {
			if (dlg.choose.end (res) == "forget") {
				account_manager.remove (provider);
			}
		});
	}

	bool last_fm_awaiting_token = false;
	bool libre_fm_awaiting_token = false;
	private void on_add (ScrobblerRow row, Scrobbling.Manager.Provider provider) {
		debug ("Selected %s", provider.to_string ());

		switch (provider) {
			case LISTENBRAINZ:
				var page = new Views.ListenBrainzPage () {
					session = session
				};
				page.done.connect (on_page_done);
				page.errored.connect (on_error);
				this.push_subpage (page);
				break;
			case MALOJA:
				var page = new Views.MalojaPage () {
					session = session
				};
				page.done.connect (on_page_done);
				page.errored.connect (on_error);
				this.push_subpage (page);
				break;
			case LASTFM:
				row.state = LOADING;
				last_fm_awaiting_token = true;
				Utils.Host.open_in_default_app.begin (@"https://www.last.fm/api/auth/?api_key=$(Build.LASTFM_KEY)&cb=turntable://lastfm/$win_id", application.active_window);
				break;
			case LIBREFM:
				var page = new Views.LibreFMPage () {
					session = session
				};
				page.chose_url.connect (on_librefm_chose);
				this.push_subpage (page);
				break;
			default:
				assert_not_reached ();
		}
	}

	private void on_page_done () {
		this.pop_subpage ();
	}

	string librefm_url = "https://libre.fm";
	private void on_librefm_chose (string page_librefm_url) {
		this.pop_subpage ();

		librefm_url = page_librefm_url;
		provider_rows.get (Scrobbling.Manager.Provider.LIBREFM.to_string ()).state = LOADING;
		libre_fm_awaiting_token = true;
		Utils.Host.open_in_default_app.begin (@"$librefm_url/api/auth/?api_key=$(Build.LIBREFM_KEY)&cb=turntable://librefm/$win_id", application.active_window);
	}

	private async string? do_last_fm_step_2 (string token, bool libre) {
		var provider = libre ? Scrobbling.Manager.Provider.LIBREFM : Scrobbling.Manager.Provider.LASTFM;
		debug ("%s Begin Step 2", provider.to_string ());

		var sk_params = new GLib.HashTable<string, string> (str_hash, str_equal);
		sk_params.set ("api_key", libre ? Build.LIBREFM_KEY : Build.LASTFM_KEY);
		sk_params.set ("method", "auth.getSession");
		sk_params.set ("token", token);

		string signature = Utils.Host.lfm_signature (sk_params, libre ? Build.LIBREFM_SECRET : Build.LASTFM_SECRET);
		GLib.StringBuilder query = new GLib.StringBuilder ();
		sk_params.foreach ((k, v) => {
			query.append (@"$k=$v&");
		});

		string final_url = libre ? librefm_url : "https://ws.audioscrobbler.com";
		var msg = new Soup.Message ("POST", @"$final_url/2.0/?$(query.str)api_sig=$signature&format=json");
		try {
			var in_stream = yield session.send_async (msg, 0, null);

			var parser = new Json.Parser ();
			parser.load_from_stream (in_stream);
			var root = parser.get_root ();
			// translators: error message when lastfm/librefm token validation fails
			if (root == null) return _("Invalid Session");

			var obj = root.get_object ();
			if (obj == null) return _("Invalid Session");
			if (!obj.has_member ("session")) return _("Invalid Session");

			var session_obj = obj.get_object_member ("session");
			if (!session_obj.has_member ("name") || !session_obj.has_member ("key")) return _("Invalid Session");

			var name = session_obj.get_string_member ("name");
			var sk = session_obj.get_string_member ("key");

			provider_rows.get (provider.to_string ()).state = EXISTS;
			account_manager.add (provider, name, sk, libre ? librefm_url : null);
			return null;
		} catch (Error e) {
			provider_rows.get (provider.to_string ()).state = NEW;
			// translators: the variable is an error message
			return _("Couldn't get session: %s").printf (e.message);
		}
	}

	private void on_token_received (Scrobbling.Manager.Provider provider, string token) {
		debug ("Received token for %s", provider.to_string ());

		switch (provider) {
			case LASTFM:
				if (!last_fm_awaiting_token) return;
				last_fm_awaiting_token = false;
				break;
			case LIBREFM:
				if (!libre_fm_awaiting_token) return;
				libre_fm_awaiting_token = false;
				break;
			default:
				return;
		}

		do_last_fm_step_2.begin (token, provider == LIBREFM, (obj, res) => {
			string? error = do_last_fm_step_2.end (res);
			if (error == null) return;
			on_error (error);
		});
	}

	private void on_error (string error) {
		this.add_toast (new Adw.Toast (error));
	}

	public override void closed () {
		base.closed ();
		account_manager.save ();
	}
}
