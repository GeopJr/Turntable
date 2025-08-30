public class Turntable.Views.LibreFMPage : Views.ProviderPage {
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
