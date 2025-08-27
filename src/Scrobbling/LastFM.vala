public class Turntable.Scrobbling.LastFM : GLib.Object, Scrobbler {
	public virtual Manager.Provider SERVICE { get { return Manager.Provider.LASTFM; } }
	public virtual string api_key { get { return Build.LASTFM_KEY; } }
	public virtual string api_secret { get { return Build.LASTFM_SECRET; } }
	public virtual string token { get; set; default = ""; }

	public virtual string url { get { return "http://ws.audioscrobbler.com/2.0/"; } set {} }

	protected void scrobble_actual (Scrobbling.Manager.Payload payload, GLib.DateTime datetime, bool now_playing) {
		var scrobble_params = new GLib.HashTable<string, string> (str_hash, str_equal);
		if (payload.album != null) scrobble_params.set ("album", payload.album);
		scrobble_params.set ("api_key", api_key);
		scrobble_params.set ("artist", payload.artist);
		scrobble_params.set ("method", now_playing ? "track.updateNowPlaying" : "track.scrobble");
		scrobble_params.set ("sk", token);
		scrobble_params.set ("timestamp", datetime.to_unix ().to_string ());
		scrobble_params.set ("track", payload.track);

		string signature = Utils.Host.lfm_signature (scrobble_params, this.api_secret);
		scrobble_params.set ("api_sig", signature);
		scrobble_params.set ("format", "json");

		var msg = new Soup.Message.from_encoded_form ("POST", this.url, Soup.Form.encode_hash (scrobble_params));
		scrobbling_manager.send_scrobble (msg, SERVICE, now_playing);
	}
}
