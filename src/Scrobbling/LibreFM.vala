public class Turntable.Scrobbling.LibreFM : LastFM, Scrobbler {
	public override string SERVICE_NAME { get { return "Libre.fm"; } }
	public override string api_key { get; set; default = ""; }
	public override string api_secret { get; set; default = ""; }
	public override string token { get; set; default = ""; }

	public override string url { get { return "https://libre.fm/2.0/"; } set {} }
}
