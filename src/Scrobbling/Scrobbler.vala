public interface Turntable.Scrobbling.Scrobbler : GLib.Object {
	public abstract Manager.Provider SERVICE { get; }
	public abstract string url { get; set; }
	public abstract string token { get; set; default = ""; }

	public virtual void scrobble (Scrobbling.Manager.Payload payload, GLib.DateTime datetime, bool now_playing = false) {
		if (token == "" || url == null || url == "") return;
		scrobble_actual (payload, datetime, now_playing);
	}
	protected abstract void scrobble_actual (Scrobbling.Manager.Payload payload, GLib.DateTime datetime, bool now_playing);
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
