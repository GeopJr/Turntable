public class Turntable.Scrobbling.LibreFM : LastFM, Scrobbler {
	public override Manager.Provider SERVICE { get { return Manager.Provider.LIBREFM; } }
	public override string api_key { get { return Build.LIBREFM_KEY; } }
	public override string api_secret { get { return Build.LIBREFM_SECRET; } }
	public override string token { get; set; default = ""; }

	public override string url { get { return "https://libre.fm/2.0/"; } set {} }
}
