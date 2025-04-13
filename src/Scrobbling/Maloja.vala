public class Turntable.Scrobbling.Maloja : ListenBrainz, Scrobbler {
	public override Manager.Provider SERVICE { get { return Manager.Provider.MALOJA; } }
	public override string token { get; set; default = ""; }

	private string _url = "";
	public override string url {
		get { return _url; }
		set {
			if (value == null) value = "";
			if (_url != value) {
				try {
					var uri = GLib.Uri.parse (value, GLib.UriFlags.NONE);
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
				} catch (Error e) {
					critical (@"Can't parse $value: $(e.message)");
				}
			}
		}
	}
}
