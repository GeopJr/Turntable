public interface Turntable.Scrobbling.Scrobbler : GLib.Object {
	public abstract Manager.Provider SERVICE { get; }
	public abstract string url { get; set; }
	public abstract string token { get; set; }

	public abstract void scrobble (Scrobbling.Manager.Payload payload, GLib.DateTime datetime);
	public virtual void update_tokens () {
		if (!account_manager.accounts.contains (SERVICE.to_string ())) {
			this.token = "";
			return;
		}

		this.token = account_manager.accounts.get (SERVICE.to_string ()).token;
	}
}
