public class Turntable.Views.MalojaPage : Views.ListenBrainzPage {
	protected override Scrobbling.Manager.Provider scrobbler_provider { get { return MALOJA; }}

	private string _url = "";
	public override string url {
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
							"/apis/listenbrainz",
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

	protected override void on_url_row_changed (Gtk.Editable url_row_editable) {
		this.url = url_row_editable.text.strip ();
	}

	protected override void on_token_changed (Gtk.Editable token_row_editable) {
		this.token = token_row_editable.text.strip ();
		token_row_valid = this.token != "";
	}

	construct {
		this.title = Scrobbling.Manager.Provider.MALOJA.to_string ();
		// translators: host as in a web server; entry title
		url_row.title = _("Host");
		url_row.text =
		this.url = "";
	}
}
