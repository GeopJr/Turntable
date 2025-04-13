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

	Scrobbler[] services = {
		new Scrobbling.ListenBrainz (),
		new Scrobbling.LibreFM (),
		new Scrobbling.LastFM ()
	};

	public struct Payload {
		public string? track;
		public string? artist;
		public string? album;
	}

	public class Pushable : GLib.Object {
		private Payload payload { get; set; }
		private uint scrobble_timeout { get; set; default = -1; }
		private int scrobble_in_seconds { get; set; }
		private int total_playtime { get; set; default = 0; }
		public signal void scrobbled (Payload payload);
		bool cleared = false;

		private bool _playing = false;
		public bool playing {
			get { return _playing; }
			set {
				if (_playing != value) {
					_playing = value;
					if (this.scrobble_timeout != -1) GLib.Source.remove (this.scrobble_timeout);

					if (value && !cleared) {
						this.scrobble_timeout = GLib.Timeout.add_seconds (1, on_add_second);
					} else {
						this.scrobble_timeout = -1;
					}
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
			if (total_playtime >= scrobble_in_seconds) on_scrobble ();
			return GLib.Source.CONTINUE;
		}

		private void on_scrobble () {
			scrobbled (payload);

			clear ();
		}

		public void clear () {
			if (cleared) return;

			if (this.scrobble_timeout != -1) GLib.Source.remove (this.scrobble_timeout);
			this.scrobble_timeout = -1;
			this.total_playtime = 0;
			cleared = true;
		}
	}

	construct {
		session = new Soup.Session.with_options ("max-conns", 64, "max-conns-per-host", 64) {
			user_agent = @"$(Build.NAME)/$(Build.VERSION) libsoup/$(Soup.get_major_version()).$(Soup.get_minor_version()).$(Soup.get_micro_version()) ($(Soup.MAJOR_VERSION).$(Soup.MINOR_VERSION).$(Soup.MICRO_VERSION))" // vala-lint=line-length
		};

		settings.notify["scrobbler-allowlist"].connect (on_allowlist_changed);
		account_manager.accounts_changed.connect (update_services);
		update_services ();
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
		if (queue_squared.contains (win_id)) {
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
		foreach (var service in services) {
			service.update_tokens ();
		}
	}

	private void on_allowlist_changed () {
		if (reserved_clients.length == 0) return;

		string[] win_ids_to_clear = {};
		reserved_clients.foreach ((k, v) => {
			if (!(v in settings.scrobbler_allowlist)) win_ids_to_clear += k;
		});

		// let's not modify reserved_clients while foreaching it
		foreach (var win_id in win_ids_to_clear) {
			clear_queue (win_id);
		}
	}

	public void scrobble_all (Payload payload) {
		if (payload.track == null || payload.artist == null) return;

		var now = new GLib.DateTime.now ();
		foreach (var scrobbler in services) {
			scrobbler.scrobble (payload, now);
		}
	}

	public void send_scrobble (owned Soup.Message msg, Provider provider) {
		session.send_async.begin (msg, 0, null, (obj, res) => {
			try {
				var in_stream = session.send_async.end (res);

				switch (msg.status_code) {
					case Soup.Status.OK:
						warning (@"$provider SUCCESS $(msg.uri)");
						DataInputStream dis = new DataInputStream (in_stream);
						StringBuilder builder = new StringBuilder ();
						string? line;

						while ((line = dis.read_line (null)) != null) {
							builder.append (line);
							builder.append ("\n");
						}

    					warning (builder.str);
						break;
					case GLib.IOError.CANCELLED:
						message ("Message is cancelled. Ignoring callback invocation.");
						break;
					default:
						critical (@"Request \"$(msg.uri.to_string ())\" failed: $(msg.status_code) $(msg.reason_phrase)");
						DataInputStream dis = new DataInputStream (in_stream);
						StringBuilder builder = new StringBuilder ();
						string? line;

						while ((line = dis.read_line (null)) != null) {
							builder.append (line);
							builder.append ("\n");
						}

    					warning (builder.str);
						break;
				}
			} catch (GLib.Error e) {
				warning (e.message);
			}
		});
	}
}
