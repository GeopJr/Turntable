public class Turntable.Scrobbling.LastFM : GLib.Object, Scrobbler {
	public virtual Manager.Provider SERVICE { get { return Manager.Provider.LASTFM; } }
	public virtual string api_key { get { return Build.LASTFM_KEY; } }
	public virtual string api_secret { get { return Build.LASTFM_SECRET; } }
	public virtual string token { get; set; default = ""; }

	public virtual string url { get { return "http://ws.audioscrobbler.com/2.0/"; } set {} }

	protected void scrobble_actual (ScrobbleEntry[] scrobble_entries, ScrobbleType scrobble_type) {
		var scrobble_params = new GLib.HashTable<string, string> (str_hash, str_equal);
		scrobble_params.set ("api_key", api_key);
		scrobble_params.set ("sk", token);
		scrobble_params.set ("method", scrobble_type.to_last_fm ());

		if (scrobble_entries.length == 1 || scrobble_type == NOW_PLAYING) {
			var entry = scrobble_entries[0];
			if (entry.payload.album != null) scrobble_params.set ("album", entry.payload.album);
			scrobble_params.set ("artist", entry.payload.artist);
			scrobble_params.set ("timestamp", entry.datetime.to_unix ().to_string ());
			scrobble_params.set ("track", entry.payload.track);
		} else {
			for (int i = 0; i < scrobble_entries.length; i++) {
				var entry = scrobble_entries[i];
				if (entry.payload.album != null) scrobble_params.set (@"album[$i]", entry.payload.album);
				scrobble_params.set (@"artist[$i]", entry.payload.artist);
				scrobble_params.set (@"timestamp[$i]", entry.datetime.to_unix ().to_string ());
				scrobble_params.set (@"track[$i]", entry.payload.track);
			}
		}

		string signature = Utils.Host.lfm_signature (scrobble_params, this.api_secret);
		scrobble_params.set ("api_sig", signature);
		scrobble_params.set ("format", "json");

		var msg = new Soup.Message.from_encoded_form ("POST", this.url, Soup.Form.encode_hash (scrobble_params));
		scrobbling_manager.send_scrobble (msg, SERVICE, scrobble_type);
	}
}
