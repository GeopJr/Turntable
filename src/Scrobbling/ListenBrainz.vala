public class Turntable.Scrobbling.ListenBrainz : GLib.Object, Scrobbler {
	public virtual Manager.Provider SERVICE { get { return Manager.Provider.LISTENBRAINZ; } }
	public virtual string token { get; set; default = ""; }
	protected virtual string auth_token_key { get; set; default = "Bearer"; }
	public override Experiments experiments { get { return WRAPPED; } }

	private string _url = "https://api.listenbrainz.org";
	public virtual string url {
		get { return _url; }
		set {
			if (value == null) value = "https://api.listenbrainz.org";
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
						"",
						null,
						null
					).to_string ();
				} catch (Error e) {
					critical (@"Can't parse $value: $(e.message)");
				}
			}
		}
	}

	protected void scrobble_actual (ScrobbleEntry[] scrobble_entries, ScrobbleType scrobble_type) {
		var builder = new Json.Builder ();
		builder.begin_object ();
			builder.set_member_name ("listen_type");
			builder.add_string_value (scrobble_type.to_listenbrainz ());
			builder.set_member_name ("payload");
			builder.begin_array ();
				foreach (ScrobbleEntry entry in scrobble_entries) {
					builder.begin_object ();
						if (scrobble_type != NOW_PLAYING) {
							builder.set_member_name ("listened_at");
							builder.add_int_value (entry.datetime.to_unix ());
						}
						builder.set_member_name ("track_metadata");
						builder.begin_object ();
							builder.set_member_name ("artist_name");
							builder.add_string_value (entry.payload.artist);
							builder.set_member_name ("track_name");
							builder.add_string_value (entry.payload.track);
							if (entry.payload.album != null) {
								builder.set_member_name ("release_name");
								builder.add_string_value (entry.payload.album);
							}
						builder.end_object ();
					builder.end_object ();
				}
			builder.end_array ();
		builder.end_object ();

		var msg = new Soup.Message ("POST", @"$(this.url)/1/submit-listens");
		var generator = new Json.Generator ();
		generator.set_root (builder.get_root ());
		msg.set_request_body_from_bytes ("application/json", new Bytes.take (generator.to_data (null).data));
		msg.request_headers.append ("Authorization", @"$(auth_token_key) $(this.token)");

		scrobbling_manager.send_scrobble (msg, SERVICE, scrobble_type);
	}

	protected override async Wrapped? wrapped_actual (Soup.Session session, string username, int max = 5) throws GLib.Error {
		bool has_year = true;
		var tracks = parse_stats_entities (yield get_stats_entities (session, username, max, "recordings", has_year, out has_year), "track_name", "recording_mbid");
		var artists = parse_stats_entities (yield get_stats_entities (session, username, max, "artists", has_year, null), "artist_name", "artist_mbid");
		var albums = parse_stats_entities (yield get_stats_entities (session, username, max, "release_groups", has_year, null), "release_group_name", "release_group_mbid");

		return {
			artists,
			tracks,
			albums
		};
	}

	private inline string listenbrainz_stats_url (string stat, string username, int max, bool all_time) {
		return @"$(this.url)/1/stats/user/$username/$(stat.replace ("_", "-"))?offset=0&range=$(all_time ? "all_time" : "year")&count=$max";
	}

	private inline async Json.Array get_stats_entities (Soup.Session session, string username, int max, string stat, bool has_year, out bool has_year_res) throws Error {
		has_year_res = has_year;
		var msg = new Soup.Message ("GET", listenbrainz_stats_url (stat, username, max, !has_year_res));
		msg.request_headers.append ("Authorization", @"$(auth_token_key) $(this.token)");
		GLib.InputStream in_stream = yield session.send_async (msg, GLib.Priority.HIGH, null);
		if (msg.status_code < 200 || msg.status_code >= 300) throw new Error.literal (-1, 2, @"Server returned $(msg.status_code)");

		var parser = new Json.Parser ();
		yield parser.load_from_stream_async (in_stream);
		var root = parser.get_root ();

		if (has_year_res && root == null) {
			has_year_res = false;
			msg = new Soup.Message ("GET", listenbrainz_stats_url (stat, username, max, !has_year_res));
			msg.request_headers.append ("Authorization", @"$(auth_token_key) $(this.token)");
			in_stream = yield session.send_async (msg, GLib.Priority.HIGH, null);
			if (msg.status_code < 200 || msg.status_code >= 300) throw new Error.literal (-1, 2, @"Server returned $(msg.status_code)");

			parser = new Json.Parser ();
			yield parser.load_from_stream_async (in_stream);
			root = parser.get_root ();
		}

		if (root == null) throw new Error.literal (-1, 3, "Malformed JSON");
		var obj = root.get_object ();
		if (obj == null) throw new Error.literal (-1, 3, "Malformed JSON");
		if (!obj.has_member ("payload")) throw new Error.literal (-1, 3, "Payload is missing");
		var payload = obj.get_object_member ("payload");
		if (!payload.has_member ("count") || payload.get_int_member_with_default ("count", 0) == 0 || !payload.has_member (stat)) throw new Error.literal (-1, 4, "Not enough data");
		var stats = payload.get_array_member (stat);
		if (stats.get_length () == 0) throw new Error.literal (-1, 4, "Not enough data");
		return stats;
	}

	private inline MBIDable[] parse_stats_entities (Json.Array stats, string name_key, string mbid_key) {
		MBIDable[] entities = {};
		stats.foreach_element ((arr, i, node) => {
			var arr_obj = node.get_object ();
			string? mbid = arr_obj.has_member ("release_mbid") ? arr_obj.get_string_member ("release_mbid") : null;
			if (mbid == null) mbid = arr_obj.has_member (mbid_key) ? arr_obj.get_string_member (mbid_key) : null;

			entities += MBIDable () {
				text = arr_obj.get_string_member (name_key),
				id = mbid,
				count = arr_obj.get_int_member_with_default ("listen_count", 0),
				image = null
			};
		});
		return entities;
	}

	public static inline async string? fetch_cover_from_wiki (Soup.Session session, string mbid, string kind) {
		if (mbid == null) return null;

		string? res = null;
		try {
			string? wikidata_id = null;
			{
				var msg = new Soup.Message ("GET", @"https://musicbrainz.org/ws/2/$kind/$mbid?inc=url-rels&fmt=json");
				GLib.InputStream in_stream = yield session.send_async (msg, GLib.Priority.HIGH, null);
				var parser = new Json.Parser ();
				yield parser.load_from_stream_async (in_stream);
				var root = parser.get_root ();
				if (root == null) throw new Error.literal (-1, 3, "Malformed JSON");
				var obj = root.get_object ();
				if (obj == null) throw new Error.literal (-1, 3, "Malformed JSON");
				if (!obj.has_member ("relations")) throw new Error.literal (-1, 3, "Relations is missing");
				var relations = obj.get_array_member ("relations");
				for (uint i = 0; i < relations.get_length (); i++) {
					var arr_obj = relations.get_object_element (i);
					if (
						arr_obj.has_member ("type")
						&& arr_obj.get_string_member ("type") == "wikidata"
						&& arr_obj.has_member ("url")
					) {
						var url_obj = arr_obj.get_object_member ("url");
						if (url_obj.has_member ("resource")) {
							string wikidata_url = url_obj.get_string_member ("resource");
							if (wikidata_url.has_prefix ("http") && "wikidata.org" in wikidata_url) {
								GLib.Regex regex = new Regex ("wiki/([^/]+)$");
    							GLib.MatchInfo match;

    							if (regex.match (wikidata_url, 0, out match)) {
    								wikidata_id = match.fetch (1);
									break;
    							}
							}
						}
					}
				}
			}

			string? img_val = null;
			if (wikidata_id != null) {
				var msg = new Soup.Message ("GET", @"https://www.wikidata.org/wiki/Special:EntityData/$wikidata_id.json");
				GLib.InputStream in_stream = yield session.send_async (msg, GLib.Priority.HIGH, null);
				var parser = new Json.Parser ();
				yield parser.load_from_stream_async (in_stream);
				var root = parser.get_root ();
				if (root == null) throw new Error.literal (-1, 3, "Malformed JSON");
				var obj = root.get_object ();
				if (obj == null) throw new Error.literal (-1, 3, "Malformed JSON");
				if (!obj.has_member ("entities")) throw new Error.literal (-1, 3, "Entities is missing");
				var entities = obj.get_object_member ("entities");
				entities.foreach_member ((t_obj, key, val) => {
					var val_obj = val.get_object ();
					if (val_obj != null && val_obj.has_member ("claims")) {
						var claims = val_obj.get_object_member ("claims");
						if (claims.has_member ("P18")) {
							var p_18 = claims.get_array_member ("P18");
							if (p_18.get_length () > 0) {
								var p_18_f = p_18.get_object_element (0);
								if (p_18_f.has_member ("mainsnak")) {
									var mainsnak = p_18_f.get_object_member ("mainsnak");
									if (mainsnak.has_member ("datavalue")) {
										var datavalue = mainsnak.get_object_member ("datavalue");
										if (datavalue.has_member ("value")) {
											img_val = datavalue.get_string_member ("value");
										}
									}
								}
							}
						}
					}
					return;
				});
			}

			if (img_val != null) res = @"https://commons.wikimedia.org/wiki/Special:FilePath/$(GLib.Uri.escape_string (img_val))";
		} catch (Error e) {
			warning (@"Couldn't fetch cover for $mbid from wiki: $(e.message) $(e.code)");
		}

		return res;
	}
}
