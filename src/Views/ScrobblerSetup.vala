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

	public class ProviderPage : Adw.NavigationPage {
		public signal void errored (string error_message);
		protected Gtk.Button add_button { get; set; }
		protected Adw.PreferencesPage page { get; set; }
		public Soup.Session session { get; set; }

		construct {
			page = new Adw.PreferencesPage ();
			add_button = new Gtk.Button.with_label ("Continue") {
				sensitive = false,
				css_classes = {"pill", "suggested-action" },
				valign = Gtk.Align.CENTER,
				halign = Gtk.Align.CENTER,
				margin_top = 8,
				margin_bottom = 8
			};
			add_button.clicked.connect (on_continue);

			var toolbar_view = new Adw.ToolbarView () {
				content = page
			};
			toolbar_view.add_top_bar (new Adw.HeaderBar ());
			toolbar_view.add_bottom_bar (add_button);

			this.child = toolbar_view;
		}

		protected virtual void update_validity () {}
		protected virtual void on_continue () {}
	}

	public class ListenBrainzPage : ProviderPage {
		Adw.EntryRow url_row;
		Adw.EntryRow token_row;
		private string token { get; set; default = ""; }
		public signal void done ();

		private bool _url_entry_valid = true;
		private bool url_entry_valid {
			get { return _url_entry_valid; }
			set {
				_url_entry_valid = value;
				bool has_error_class = url_row.has_css_class ("error");
				if (value && has_error_class) {
					url_row.remove_css_class ("error");
				} else if (!value && !has_error_class) {
					url_row.add_css_class ("error");
				}

				update_validity ();
			}
		}

		private bool _token_row_valid = false;
		private bool token_row_valid {
			get { return _token_row_valid; }
			set {
				_token_row_valid = value;
				bool has_error_class = token_row.has_css_class ("error");
				if (value && has_error_class) {
					token_row.remove_css_class ("error");
				} else if (!value && !has_error_class) {
					token_row.add_css_class ("error");
				}

				update_validity ();
			}
		}

		protected override void update_validity () {
			add_button.sensitive = this.token_row_valid && this.url_entry_valid;
		}

		private string _url = "";
		public string url {
			get { return _url; }
			set {
				bool error = false;
				string normalized_value = value.contains ("://") ? value : @"https://$value";

				if (!normalized_value.contains (".")) {
					error = true;
				} else if (_url != normalized_value) {
					try {
						if (GLib.Uri.is_valid (normalized_value, GLib.UriFlags.NONE)) {
							var uri = GLib.Uri.parse (normalized_value, GLib.UriFlags.NONE);
							string host = uri.get_host ();
							string path = uri.get_path ();
							if (path.has_suffix ("/")) path = path.slice (0, path.length - 1);

							_url = GLib.Uri.build (
								GLib.UriFlags.NONE,
								"https",
								uri.get_userinfo (),
								host,
								uri.get_port (),
								path,
								null,
								null
							).to_string ();

							string regular_url = _url;
							int first_dot = host.index_of_char ('.');
							if (host.index_of_char ('.', first_dot) != -1) {
								regular_url = GLib.Uri.build (
									GLib.UriFlags.NONE,
									"https",
									uri.get_userinfo (),
									host.splice (0, first_dot + 1),
									uri.get_port (),
									"",
									null,
									null
								).to_string ();
							}

							string settings_page = @"$(GLib.Markup.escape_text (regular_url))/settings/";
							page.description = _("You can get your user token from %s.").printf (@"<a href=\"$settings_page\">$settings_page</a>");
						} else {
							error = true;
						}
					} catch {
						error = true;
					}
				}

				url_entry_valid = !error;
			}
		}

		protected virtual Scrobbling.Manager.Provider scrobbler_provider { get { return LISTENBRAINZ; }}
		construct {
			this.title = Scrobbling.Manager.Provider.LISTENBRAINZ.to_string ();

			var main_group = new Adw.PreferencesGroup ();
			url_row = new Adw.EntryRow () {
				title = _("Host API")
			};
			this.url = "https://api.listenbrainz.org";

			url_row.text = this.url;
			url_row.changed.connect (on_url_row_changed);
			main_group.add (url_row);

			token_row = new Adw.EntryRow () {
				title = _("User Token")
			};
			token_row.changed.connect (on_token_changed);
			main_group.add (token_row);
			page.add (main_group);
		}

		private void on_url_row_changed (Gtk.Editable url_row_editable) {
			string clean_uri = url_row_editable.text.strip ();
			if (clean_uri == "") clean_uri = "https://api.listenbrainz.org";

			this.url = clean_uri;
		}

		private void on_token_changed (Gtk.Editable token_row_editable) {
			this.token = token_row_editable.text.strip ();
			token_row_valid = GLib.Uuid.string_is_valid (this.token);
		}

		protected override void on_continue () {
			this.can_pop =
			url_row.sensitive =
			token_row.sensitive =
			add_button.sensitive = false;
			validate_token.begin (this.token, (obj, res) => {
				string? error = validate_token.end (res);
				this.can_pop =
				url_row.sensitive =
				token_row.sensitive =
				add_button.sensitive = true;

				if (error == null) {
					done ();
					return;
				}
				errored (error);
			});
		}

		private async string? validate_token (string user_token) {
			var msg = new Soup.Message ("GET", @"$(this.url)/1/validate-token");
			msg.request_headers.append ("Authorization", @"Token $user_token");

			try {
				var in_stream = yield session.send_async (msg, 0, null);

				switch (msg.status_code) {
					case Soup.Status.OK:
						var parser = new Json.Parser ();
						parser.load_from_stream (in_stream);

						var root = parser.get_root ();
						if (root == null) return _("Invalid Token");
						var obj = root.get_object ();
						if (obj == null) return _("Invalid Token");

						if (!obj.has_member ("valid") || !obj.get_boolean_member ("valid")) return _("Invalid Token");
						if (!obj.has_member ("user_name")) return _("Invalid Token");

						var user_name = obj.get_string_member ("user_name");
						account_manager.add (this.scrobbler_provider, user_name, user_token, this.url);

						break;
					default:
						string message = _("Couldn't validate token: %s").printf (@"$(msg.status_code) $(msg.reason_phrase)");
						critical (message);
						return message;
				}
			} catch (Error e) {
				string message = _("Couldn't validate token: %s").printf (e.message);
				critical (message);
				return message;
			}

			return null;
		}
	}

	public class LibreFMPage : ProviderPage {
		public signal void chose_url (string chosen_url);
		Adw.EntryRow url_row;

		private bool _url_entry_valid = true;
		private bool url_entry_valid {
			get { return _url_entry_valid; }
			set {
				_url_entry_valid = value;
				bool has_error_class = url_row.has_css_class ("error");
				if (value && has_error_class) {
					url_row.remove_css_class ("error");
				} else if (!value && !has_error_class) {
					url_row.add_css_class ("error");
				}

				update_validity ();
			}
		}

		protected override void update_validity () {
			add_button.sensitive = this.url_entry_valid;
		}

		private string _url = "";
		public string url {
			get { return _url; }
			set {
				bool error = false;
				string normalized_value = value.contains ("://") ? value : @"https://$value";

				if (!normalized_value.contains (".")) {
					error = true;
				} else if (_url != normalized_value) {
					try {
						if (GLib.Uri.is_valid (normalized_value, GLib.UriFlags.NONE)) {
							var uri = GLib.Uri.parse (normalized_value, GLib.UriFlags.NONE);

							_url = GLib.Uri.build (
								GLib.UriFlags.NONE,
								"https",
								uri.get_userinfo (),
								uri.get_host (),
								uri.get_port (),
								"",
								null,
								null
							).to_string ();
						} else {
							error = true;
						}
					} catch {
						error = true;
					}
				}

				url_entry_valid = !error;
			}
		}

		construct {
			this.title = Scrobbling.Manager.Provider.LIBREFM.to_string ();

			var main_group = new Adw.PreferencesGroup ();
			url_row = new Adw.EntryRow () {
				title = _("Host")
			};
			this.url = "https://libre.fm";

			url_row.text = this.url;
			url_row.changed.connect (on_url_row_changed);

			main_group.add (url_row);
			page.add (main_group);
		}

		protected override void on_continue () {
			url_row.sensitive =
			add_button.sensitive = false;
			chose_url (this.url);
		}

		private void on_url_row_changed (Gtk.Editable url_row_editable) {
			string clean_uri = url_row_editable.text.strip ();
			if (clean_uri == "") clean_uri = "https://libre.fm";

			this.url = clean_uri;
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

	string win_id;
	GLib.HashTable<string, ScrobblerRow> provider_rows = new GLib.HashTable<string, ScrobblerRow> (str_hash, str_equal);
	construct {
		session = new Soup.Session () {
			user_agent = @"$(Build.NAME)/$(Build.VERSION) libsoup/$(Soup.get_major_version()).$(Soup.get_minor_version()).$(Soup.get_micro_version()) ($(Soup.MAJOR_VERSION).$(Soup.MINOR_VERSION).$(Soup.MICRO_VERSION))" // vala-lint=line-length
		};

		this.title = _("Scrobblers");

		var main_page = new Adw.PreferencesPage () {
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

		win_id = ((Views.Window) application.active_window).uuid;
		application.token_received[win_id].connect (on_token_received);
		account_manager.accounts_changed.connect (update_row_states);
		update_row_states ();
	}

	private void update_row_states () {
		provider_rows.foreach ((provider, row) => {
			if (row.state != ScrobblerRow.State.LOADING) {
				bool exists = account_manager.accounts.contains (provider);

				row.state = exists ? ScrobblerRow.State.EXISTS : ScrobblerRow.State.NEW;
				row.subtitle = exists ? account_manager.accounts.get (provider).username : "";
			}
		});
	}

	private void on_trash (Scrobbling.Manager.Provider provider) {
		var dlg = new Adw.AlertDialog (
			_("Forget %s Account?").printf (provider.to_string ()),
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
		switch (provider) {
			case LISTENBRAINZ:
				var page = new ListenBrainzPage () {
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
				var page = new LibreFMPage () {
					session = session
				};
				page.chose_url.connect (on_librefm_chose);
				this.push_subpage (page);
				break;
			default:
				break;
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
			return _("Couldn't get session: %s").printf (e.message);
		}
	}

	private void on_token_received (Scrobbling.Manager.Provider provider, string token) {
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
