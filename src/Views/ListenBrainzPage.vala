public class Turntable.Views.ListenBrainzPage : Views.ProviderPage {
	protected Adw.EntryRow url_row;
	Adw.EntryRow token_row;
	protected string token { get; set; default = ""; }
	public signal void done ();

	private bool _url_entry_valid = true;
	protected bool url_entry_valid {
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
	protected bool token_row_valid {
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
	public virtual string url {
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
						// translators: variable is a link
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
			// translators: host as in a web server; entry title
			title = _("Host API")
		};
		this.url = "https://api.listenbrainz.org";

		url_row.text = this.url;
		url_row.changed.connect (on_url_row_changed);
		main_group.add (url_row);

		token_row = new Adw.EntryRow () {
			// translators: can also be translated as Authentication Token
			title = _("User Token")
		};
		token_row.changed.connect (on_token_changed);
		main_group.add (token_row);
		page.add (main_group);
	}

	protected virtual void on_url_row_changed (Gtk.Editable url_row_editable) {
		string clean_uri = url_row_editable.text.strip ();
		if (clean_uri == "") clean_uri = "https://api.listenbrainz.org";

		this.url = clean_uri;
	}

	protected virtual void on_token_changed (Gtk.Editable token_row_editable) {
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
				yield parser.load_from_stream_async (in_stream);

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
				// translators: the variable is an error message
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
