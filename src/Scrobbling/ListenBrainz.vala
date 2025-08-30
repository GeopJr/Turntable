public class Turntable.Scrobbling.ListenBrainz : GLib.Object, Scrobbler {
	public virtual Manager.Provider SERVICE { get { return Manager.Provider.LISTENBRAINZ; } }
	public virtual string token { get; set; default = ""; }

	private string _url = "https://api.listenbrainz.org";
	public virtual string url {
		get { return _url; }
		set {
			if (value == null) value = "https://api.listenbrainz.org";
			if (value == "") {
				_url = value;
			} else if (_url != value) {
				try {
					var uri = GLib.Uri.parse (value, GLib.UriFlags.NONE);
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
				} catch (Error e) {
					critical (@"Can't parse $value: $(e.message)");
				}
			}
		}
	}

	protected void scrobble_actual (ScrobbleEntry[] scrobble_entries, ScrobbleType scrobble_type) {
		var builder = new Json.Builder ();
		builder.begin_object ();
			builder.set_member_name ("listen_type");
			builder.add_string_value (scrobble_type.to_listenbrainz ());
			builder.set_member_name ("payload");
			builder.begin_array ();
				foreach (ScrobbleEntry entry in scrobble_entries) {
					builder.begin_object ();
						if (scrobble_type != NOW_PLAYING) {
							builder.set_member_name ("listened_at");
							builder.add_int_value (entry.datetime.to_unix ());
						}
						builder.set_member_name ("track_metadata");
						builder.begin_object ();
							builder.set_member_name ("artist_name");
							builder.add_string_value (entry.payload.artist);
							builder.set_member_name ("track_name");
							builder.add_string_value (entry.payload.track);
							if (entry.payload.album != null) {
								builder.set_member_name ("release_name");
								builder.add_string_value (entry.payload.album);
							}
						builder.end_object ();
					builder.end_object ();
				}
			builder.end_array ();
		builder.end_object ();

		var msg = new Soup.Message ("POST", @"$(this.url)/1/submit-listens");
		var generator = new Json.Generator ();
		generator.set_root (builder.get_root ());
		msg.set_request_body_from_bytes ("application/json", new Bytes.take (generator.to_data (null).data));
		msg.request_headers.append ("Authorization", @"Bearer $(this.token)");

		scrobbling_manager.send_scrobble (msg, SERVICE, scrobble_type);
	}
}
