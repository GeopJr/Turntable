public class Turntable.Scrobbling.LibreFM : LastFM, Scrobbler {
	public override Manager.Provider SERVICE { get { return Manager.Provider.LIBREFM; } }
	public override string api_key { get { return Build.LIBREFM_KEY; } }
	public override string api_secret { get { return Build.LIBREFM_SECRET; } }
	public override string token { get; set; default = ""; }

	private string _url = "https://libre.fm/2.0/";
	public override string url {
		get { return _url; }
		set {
			if (value == null) value = "https://libre.fm/2.0/";

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
						"/2.0/",
						null,
						null
					).to_string ();
				} catch (Error e) {
					critical (@"Can't parse $value: $(e.message)");
				}
			}
		}
	}

	protected override async Wrapped? wrapped_actual (Soup.Session session, string username, int max = 5) throws GLib.Error {
		return {
			yield get_stats_entities (session, username, max, "gettopartists", "topartists", "artist"),
			yield get_stats_entities (session, username, max, "gettoptracks", "toptracks", "track"),
			{} // no albums
		};
	}
}
