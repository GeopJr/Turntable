public interface Turntable.Scrobbling.Scrobbler : GLib.Object {
	public abstract Manager.Provider SERVICE { get; }
	public abstract string url { get; set; }
	public abstract string token { get; set; default = ""; }

	public enum ScrobbleType {
		TRACK,
		NOW_PLAYING,
		IMPORT;

		public string to_last_fm () {
			switch (this) {
				case NOW_PLAYING: return "track.updateNowPlaying";
				default: return "track.scrobble";
			}
		}

		public string to_listenbrainz () {
			switch (this) {
				case IMPORT: return "import";
				case NOW_PLAYING: return "playing_now";
				default: return "single";
			}
		}

		public string to_past_action () {
			switch (this) {
				case IMPORT: return "imported";
				case NOW_PLAYING: return "submitted";
				default: return "scrobbled";
			}
		}

		public string to_action () {
			switch (this) {
				case IMPORT: return "import";
				case NOW_PLAYING: return "now playing";
				default: return "scrobble";
			}
		}

		public string to_present_action () {
			switch (this) {
				case IMPORT: return "importing";
				case NOW_PLAYING: return "submitting";
				default: return "scrobbling";
			}
		}
	}

	public struct ScrobbleEntry {
		Scrobbling.Manager.Payload payload;
		GLib.DateTime datetime;
	}

	public virtual void scrobble (ScrobbleEntry[] scrobble_entries, ScrobbleType scrobble_type) {
		if (token == "" || url == null || url == "") return;
		scrobble_actual (scrobble_entries, scrobble_type);
	}
	protected abstract void scrobble_actual (ScrobbleEntry[] scrobble_entries, ScrobbleType scrobble_type);
	public virtual void update_tokens () {
		if (!account_manager.accounts.contains (SERVICE.to_string ())) {
			this.token = "";
			this.url = "";
			return;
		}

		var acc = account_manager.accounts.get (SERVICE.to_string ());
		this.token = acc.token;
		this.url = acc.custom_url;
	}
}
