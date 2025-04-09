public interface Turntable.Scrobbling.Scrobbler : GLib.Object {
	public abstract string SERVICE_NAME { get; }
	public abstract string url { get; set; }
	public abstract string token { get; set; }

	public abstract void scrobble (Scrobbling.Manager.Payload payload, GLib.DateTime datetime);
}
