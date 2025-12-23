public class Turntable.Scrobbling.Manager : GLib.Object {
	Soup.Session session;
	GLib.HashTable<string, Pushable> queue_squared = new GLib.HashTable<string, Pushable> (str_hash, str_equal);
	GLib.HashTable<string, string> reserved_clients = new GLib.HashTable<string, string> (str_hash, str_equal);

	public enum Provider {
		LISTENBRAINZ,
		LIBREFM,
		LASTFM,
		MALOJA;

		public string to_string () {
			switch (this) {
				case LISTENBRAINZ: return "ListenBrainz";
				case LIBREFM: return "Libre.fm";
				case LASTFM: return "last.fm";
				case MALOJA: return "Maloja";
				default: assert_not_reached ();
			}
		}

		public string to_icon_name () {
			switch (this) {
				case LISTENBRAINZ: return "listenbrainz";
				case LIBREFM: return "librefm";
				case LASTFM: return "lastfm-symbolic";
				case MALOJA: return "maloja";
				default: assert_not_reached ();
			}
		}
	}
	public const Provider[] ALL_PROVIDERS = { LISTENBRAINZ, LIBREFM, LASTFM, MALOJA };

	public bool cli_mode { get; set; default = false; }

	Scrobbler[] services = {
		new Scrobbling.ListenBrainz (),
		new Scrobbling.LibreFM (),
		new Scrobbling.LastFM (),
		new Scrobbling.Maloja ()
	};

	public struct Payload {
		public string? track;
		public string? artist;
		public string? album;
	}

	public class Pushable : GLib.Object {
		private Payload payload { get; set; }
		private uint scrobble_timeout { get; set; default = 0; }
		private int scrobble_in_seconds { get; set; }
		private int total_playtime { get; set; default = 0; }
		public signal void scrobbled (Payload payload, bool now_playing = false);
		bool cleared = false;

		~Pushable () {
			debug ("[Pushable] Destroying: %s", payload.track);
		}

		private bool _playing = false;
		public bool playing {
			get { return _playing; }
			set {
				if (_playing != value) {
					_playing = value;
					if (this.scrobble_timeout != 0) GLib.Source.remove (this.scrobble_timeout);

					if (value && !cleared) {
						this.scrobble_timeout = GLib.Timeout.add_seconds (1, on_add_second);
					} else {
						this.scrobble_timeout = 0;
					}

					debug ("[Pushable] Changed play status for %s", payload.track);
				}
			}
		}

		public Pushable (Payload payload, int scrobble_in_seconds) {
			this.payload = payload;
			this.scrobble_in_seconds = scrobble_in_seconds;
		}

		private bool on_add_second () {
			if (cleared) return GLib.Source.REMOVE;

			total_playtime += 1;
			if (total_playtime == 3) on_started_playing ();
			else if (total_playtime >= scrobble_in_seconds) on_scrobble ();
			return GLib.Source.CONTINUE;
		}

		private inline string to_background_portal_message (Payload payload) {
			string res = payload.track;
			if (payload.artist != null) {
				res += @" - $(payload.artist)";
			}

			return res;
		}

		bool now_played = false;
		private void on_started_playing () {
			// translators: background portal subtitle when scrobbling,
			//				the variable is a song name
			application.background_portal_message.begin (_("Scrobbling %s").printf (to_background_portal_message (payload)));

			if (!settings.now_playing || now_played) return;
			now_played = true;

			debug ("[Pushable] Now Playing %s", payload.track);
			scrobbled (payload, true);
		}

		bool lock_scrobbled = false;
		private void on_scrobble () {
			if (lock_scrobbled) return;
			lock_scrobbled = true;

			// translators: background portal subtitle when publishing a scrobble,
			//				the variable is a song name
			application.background_portal_message.begin (_("Scrobbled %s").printf (to_background_portal_message (payload)));
			debug ("[Pushable] Scrobbling %s", payload.track);
			scrobbled (payload);

			clear ();
		}

		public void clear () {
			if (cleared) return;

			if (this.scrobble_timeout != 0) GLib.Source.remove (this.scrobble_timeout);
			this.scrobble_timeout = 0;
			this.total_playtime = 0;
			cleared = true;
			debug ("[Pushable] Cleared %s", payload.track);
		}
	}

	private class BatchSplitter : GLib.Object {
		const int BATCH_SIZE = 50;
		public signal void done (Scrobbler.ScrobbleEntry[] batch);
		public signal void done_all ();

		string[] batches = {};
		public BatchSplitter (string[] batches) {
			this.batches = batches;
		}

		public void split () {
			int batches_length = this.batches.length;
			if (batches_length == 0) {
				done_all ();
				this.batches = {};
				return;
			}

			int total_batches = (batches_length + BATCH_SIZE - 1) / BATCH_SIZE;
			for (int b = 0; b < total_batches; b++) {
				int start = b * BATCH_SIZE;
				int end = int.min (start + BATCH_SIZE, batches_length);
				Scrobbler.ScrobbleEntry[] batch_entries = {};

				foreach (string payload in this.batches[start:end]) {
					var parser = new Json.Parser ();
					try {
						parser.load_from_data (payload, -1);

						var root = parser.get_root ();
						if (root == null) assert_not_reached ();

						var obj = root.get_object ();
						if (obj == null) assert_not_reached ();
						if (!obj.has_member ("track") || !obj.has_member ("artist") || !obj.has_member ("date")) assert_not_reached ();

						batch_entries += Scrobbler.ScrobbleEntry () {
							payload = Payload () {
								track = obj.get_string_member ("track"),
								artist = obj.get_string_member ("artist"),
								album = obj.has_member ("album") ? obj.get_string_member ("album") : null
							},
							datetime = new GLib.DateTime.from_iso8601 (obj.get_string_member ("date"), null)
						};
					} catch {
						assert_not_reached ();
					}
				}

				done (batch_entries);
				GLib.Thread.usleep (250000);
			}

			done_all ();
			this.batches = {};
		}
	}

	construct {
		session = new Soup.Session.with_options ("max-conns", 64, "max-conns-per-host", 64) {
			user_agent = @"$(Build.NAME)/$(Build.VERSION) libsoup/$(Soup.get_major_version()).$(Soup.get_minor_version()).$(Soup.get_micro_version()) ($(Soup.MAJOR_VERSION).$(Soup.MINOR_VERSION).$(Soup.MICRO_VERSION))" // vala-lint=line-length
		};

		settings.notify["scrobbler-allowlist"].connect (on_allowlist_changed);
		account_manager.accounts_changed.connect (update_services);
		update_services ();

		GLib.Timeout.add_once (5000, submit_offline_scrobbles);
	}

	public void queue_payload (string win_id, string client, Payload payload, int64 length) {
		int add_in_seconds = int.min (4 * 60, (int) (length / 1000000 / 2));

		clear_queue (win_id);
		if (add_in_seconds < 25 || (reserved_clients.find ((k, v) => { return v == client; }) != null)) return;

		reserved_clients.set (win_id, client);
		var pushable = new Pushable (payload, add_in_seconds);
		pushable.scrobbled.connect (scrobble_all);
		queue_squared.set (win_id, pushable);
	}

	public void clear_queue (string win_id) {
		debug ("Clearing %s", win_id);

		if (queue_squared.contains (win_id)) {
			application.background_portal_message.begin (null);
			queue_squared.get (win_id).clear ();
			queue_squared.remove (win_id);
		}

		if (reserved_clients.contains (win_id)) {
			reserved_clients.remove (win_id);
		}
	}

	public void set_playing_for_id (string win_id, bool playing) {
		if (!queue_squared.contains (win_id)) return;
		queue_squared.get (win_id).playing = playing;
	}

	private void update_services () {
		debug ("Updating service tokens");
		foreach (var service in services) {
			service.update_tokens ();
		}
	}

	private void on_allowlist_changed () {
		if (reserved_clients.length == 0 || cli_mode) return;
		debug ("Allowlist changed");

		string[] win_ids_to_clear = {};
		reserved_clients.foreach ((k, v) => {
			if (!(v in settings.scrobbler_allowlist)) win_ids_to_clear += k;
		});

		// let's not modify reserved_clients while foreaching it
		foreach (var win_id in win_ids_to_clear) {
			clear_queue (win_id);
		}
	}

	private void add_to_offline_scrobbling (Payload payload) {
		debug ("[OFFLINE] Adding %s to the offline scrobbling list", payload.track);

		var builder = new Json.Builder ();
		builder.begin_object ();
			builder.set_member_name ("date");
			builder.add_string_value ((new DateTime.now_local ()).format_iso8601 ());
			builder.set_member_name ("track");
			builder.add_string_value (payload.track);
			builder.set_member_name ("artist");
			builder.add_string_value (payload.artist);

			if (payload.album != null) {
				builder.set_member_name ("album");
				builder.add_string_value (payload.album);
			}
		builder.end_object ();

		var generator = new Json.Generator ();
		generator.set_root (builder.get_root ());

		// this can be long, let's not keep it in memory
		string[] offline_scrobbles = settings.get_strv ("offline-scrobbles");
		offline_scrobbles += generator.to_data (null);
		settings.set_strv ("offline-scrobbles", offline_scrobbles);
	}

	public void scrobble_all (Payload payload, bool now_playing) {
		if (payload.track == null || payload.artist == null) return;

		debug (now_playing ? "Now Playing %s" : "Scrobbling %s", payload.track);
		if (settings.offline_scrobbling && !network_monitor.network_available) {
			if (!now_playing) add_to_offline_scrobbling (payload);
			return;
		}

		if (settings.mbid_required) {
			scrobbling_manager.fetch_mb_data.begin (payload, (obj, res) => {
				var new_payload = scrobbling_manager.fetch_mb_data.end (res);
				if (new_payload != null) {
					scrobble_all_actual (new_payload, now_playing);
				}
			});

			return;
		}

		scrobble_all_actual (payload, now_playing);
	}

	private inline void scrobble_all_actual (Payload payload, bool now_playing) {
		var now = new GLib.DateTime.now ();
		foreach (var scrobbler in services) {
			scrobbler.scrobble ({Scrobbler.ScrobbleEntry () {payload = payload, datetime = now}}, now_playing ? Scrobbler.ScrobbleType.NOW_PLAYING : Scrobbler.ScrobbleType.TRACK);
		}
	}

	public void submit_offline_scrobbles () {
		if (!network_monitor.network_available || !settings.offline_scrobbling || application.batch_in_progress) return;
		application.batch_in_progress = true;

		BatchSplitter splitter;
		{
			string[] offline_scrobbles = settings.get_strv ("offline-scrobbles");
			int total = offline_scrobbles.length;
			if (total == 0) {
				application.batch_in_progress = false;
				return;
			}
			debug ("Splitting %d offline scrobbles", total);
			splitter = new BatchSplitter (offline_scrobbles);
		}

		try {
			splitter.done.connect (on_split_done);
			splitter.done_all.connect (on_split_done_all);
			debug ("Spawining BatchSplitter thread");
			new GLib.Thread<void>.try ("BatchSplitter", splitter.split);
			settings.set_strv ("offline-scrobbles", {});
		} catch (Error e) {
			critical (@"Couldn't spawn BatchSplitter thread: $(e.code) $(e.message)");
		}
	}

	private void on_split_done (Scrobbler.ScrobbleEntry[] batch) {
		debug ("Submitting BatchSplitter batch");
		foreach (var scrobbler in services) {
			scrobbler.scrobble (batch, Scrobbler.ScrobbleType.IMPORT);
		}
	}

	private void on_split_done_all () {
		debug ("Finished BatchSplitter");
		application.batch_in_progress = false;
	}

	public void send_scrobble (owned Soup.Message msg, Provider provider, Scrobbler.ScrobbleType scrobble_type) {
		debug ("Sending %s to %s", scrobble_type.to_action (), provider.to_string ());
		session.send_async.begin (msg, 0, null, (obj, res) => {
			try {
				var in_stream = session.send_async.end (res);

				switch (msg.status_code) {
					case Soup.Status.OK:
						debug ("Successfully %s %s", scrobble_type.to_past_action (), provider.to_string ());
						break;
					case GLib.IOError.CANCELLED:
						debug ("Cancelled %s for %s", scrobble_type.to_present_action (), provider.to_string ());
						return; // !
					default:
						critical ("Request \"%s\" failed: %zu %s", msg.uri.to_string (), msg.status_code, msg.reason_phrase);
						break;
				}

				if (debug_enabled) {
					DataInputStream dis = new DataInputStream (in_stream);
					StringBuilder builder = new StringBuilder ();
					string? line;

					while ((line = dis.read_line (null)) != null) {
						builder.append (line);
						builder.append ("\n");
					}

					debug ("Response: %s", builder.str);
				}
			} catch (GLib.Error e) {
				warning (e.message);
			}
		});
	}

	struct MbCached {
		string mb_url;
		Payload? payload;
	}
	MbCached? mb_cached = null;

	private async Payload? fetch_mb_data (Payload payload) {
		string album_string_param = payload.album == null ? "" : @"+AND+release:$(GLib.Uri.escape_string (payload.album))";
		string mb_url = @"https://musicbrainz.org/ws/2/recording?query=recording:$(GLib.Uri.escape_string (payload.track))+AND+artist:$(GLib.Uri.escape_string (payload.artist))$album_string_param&fmt=json&limit=1";

		debug ("MBID Request %s", mb_url);
		if (mb_cached != null) {
			if (mb_cached.mb_url == mb_url) {
				debug ("MBID Found in Cache");
				return mb_cached.payload;
			} else {
				mb_cached = null;
			}
		}

		var msg = new Soup.Message ("GET", mb_url);
		try {
			var in_stream = yield session.send_async (msg, 0, null);
			if (msg.status_code != Soup.Status.OK) new Error.literal (-1, 2, @"Server returned $(msg.status_code)");

			var parser = new Json.Parser ();
			parser.load_from_stream (in_stream);

			var root = parser.get_root ();
			if (root == null) new Error.literal (-1, 3, "Malformed JSON");
			var obj = root.get_object ();
			if (obj == null) new Error.literal (-1, 3, "Malformed JSON");

			if (!obj.has_member ("count") || obj.get_int_member_with_default ("count", 0) == 0) new Error.literal (-1, 2, "Count doesn't exist or 0");
			if (!obj.has_member ("recordings")) new Error.literal (-1, 2, "Recordings is missing");

			var recordings = obj.get_array_member ("recordings");
			if (recordings.get_length () == 0) new Error.literal (-1, 2, "Recordings is empty");

			var recording = recordings.get_object_element (0);
			if (recording.has_member ("title")) {
				payload.track = recording.get_string_member ("title");
			}

			if (recording.has_member ("artist-credit")) {
				var artists = recording.get_array_member ("artist-credit");
				if (artists.get_length () > 0) {
					var artist = artists.get_object_element (0);
					if (artist.has_member ("name")) {
						payload.artist = artist.get_string_member ("name");
					}
				}
			}

			if (recording.has_member ("releases")) {
				var releases = recording.get_array_member ("releases");
				if (releases.get_length () > 0) {
					var release = releases.get_object_element (0);
					if (release.has_member ("title")) {
						payload.album = release.get_string_member ("title");
					}
				}
			}

			mb_cached = {mb_url, payload};
			return payload;
		} catch (Error e) {
			if (e.code == 2) {
				debug ("Couldn't complete MBID: %s", e.message);
			} else {
				warning ("Couldn't complete MBID: %s", e.message);
			}
		}

		mb_cached = {mb_url, null};
		return null;
	}
}
