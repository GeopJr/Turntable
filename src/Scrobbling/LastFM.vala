public class Turntable.Scrobbling.LastFM : GLib.Object, Scrobbler {
	public virtual Manager.Provider SERVICE { get { return Manager.Provider.LASTFM; } }
	public virtual string api_key { get { return Build.LASTFM_KEY; } }
	public virtual string api_secret { get { return Build.LASTFM_SECRET; } }
	public virtual string token { get; set; default = ""; }
	public override Experiments experiments { get { return WRAPPED; } }

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


	protected override async Wrapped? wrapped_actual (Soup.Session session, string username, int max = 5) throws GLib.Error {
		var tracks = yield get_stats_entities (session, username, max, "gettoptracks", "toptracks", "track");
		var artists = yield get_stats_entities (session, username, max, "gettopartists", "topartists", "artist");

		// lastfm doesn't provide these (star placeholder)
		// let's fallback to mbid search
		for (int i = 0; i < tracks.length; i++) {
			tracks[i].image = null;
		}

		for (int i = 0; i < artists.length; i++) {
			artists[i].image = null;
		}

		return {
			artists,
			tracks,
			yield get_stats_entities (session, username, max, "gettopalbums", "topalbums", "album")
		};
	}

	private inline string lastfm_stats_url (string method, string username, int max) {
		return @"$(this.url)/?method=user.$method&user=$username&api_key=$api_key&format=json&limit=$max&range=12months";
	}

	protected inline async MBIDable[] get_stats_entities (Soup.Session session, string username, int max, string method, string toplevel_key, string stat_key) throws Error {
		var msg = new Soup.Message ("GET", lastfm_stats_url (method, username, max));
		GLib.InputStream in_stream = yield session.send_async (msg, 0, null);
		if (msg.status_code != Soup.Status.OK) throw new Error.literal (-1, 2, @"Server returned $(msg.status_code)");

		MBIDable[] res = {};
		var parser = new Json.Parser ();
		yield parser.load_from_stream_async (in_stream);
		var root = parser.get_root ();
		if (root == null) throw new Error.literal (-1, 3, "Malformed JSON");
		var obj = root.get_object ();
		if (obj == null) throw new Error.literal (-1, 3, "Malformed JSON");
		if (!obj.has_member (toplevel_key)) throw new Error.literal (-1, 3, @"$toplevel_key is missing");
		var payload = obj.get_object_member (toplevel_key);
		if (!payload.has_member (stat_key)) throw new Error.literal (-1, 3, @"$stat_key is missing");
		var stats_member = payload.get_member (stat_key);
		switch (stats_member.get_node_type ()) {
			case Json.NodeType.OBJECT:
				res += parse_stats_entity (stats_member.get_object (), stat_key == "track");
				break;
			case Json.NodeType.ARRAY:
				Json.Array stats_arr = stats_member.get_array ();
				if (stats_arr.get_length () == 0) throw new Error.literal (-1, 4, "Not enough data");
				stats_arr.foreach_element ((arr, i, node) => {
					var arr_obj = node.get_object ();
					res += parse_stats_entity (arr_obj, stat_key == "track");
				});
				break;
			default:
				throw new Error.literal (-1, 3, "Malformed JSON");
		}
		return res;
	}

	private inline MBIDable parse_stats_entity (Json.Object stat, bool artist_mbid = false) {
		int64 count = 0;
		string count_s = stat.get_string_member_with_default ("playcount", "");
		if (count_s == "") {
			count = stat.get_int_member_with_default ("playcount", 0);
		} else {
			count = int64.parse (count_s);
		}

		string? mbid = null;
		if (stat.has_member ("mbid")) {
			mbid = stat.get_string_member ("mbid");
			if (mbid == "") mbid = null;
		}

		// hack: last.fm doesn't have images for tracks
		//		 and doesn't include the album mbid
		//		 therefore fallback to artist mbid
		if (artist_mbid && stat.has_member ("artist")) {
			var artist_obj = stat.get_object_member ("artist");
			if (artist_obj.has_member ("mbid")) {
				var ar_mbid = artist_obj.get_string_member ("mbid");
				if (ar_mbid != "") mbid = ar_mbid;
			}
		}

		string? image = null;
		if (stat.has_member ("image")) {
			var arr = stat.get_array_member ("image");
			var len = arr.get_length ();
			if (len > 0) {
				var obj = arr.get_object_element (len - 1);
				if (obj.has_member ("#text")) {
					image = obj.get_string_member ("#text");
				}
			}
		}

		return {
			stat.get_string_member ("name"),
			mbid,
			count,
			image
		};
	}
}
