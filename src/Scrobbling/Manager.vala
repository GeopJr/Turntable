public class Turntable.Scrobbling.Manager : GLib.Object {
	Soup.Session session;
	GLib.HashTable<string, Pushable> queue_squared = new GLib.HashTable<string, Pushable> (str_hash, str_equal);

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
	}

	public void queue_payload (string win_id, Payload payload, int64 length) {
		int add_in_seconds = int.min (4 * 60, (int) (length / 1000000 / 2));

		clear_queue (win_id);
		if (add_in_seconds < 25) return;

		var pushable = new Pushable (payload, add_in_seconds);
		pushable.scrobbled.connect (scrobble_all);
		queue_squared.set (win_id, pushable);
	}

	public void clear_queue (string win_id) {
		if (!queue_squared.contains (win_id)) return;
		queue_squared.get (win_id).clear ();
		queue_squared.remove (win_id);
	}

	public void set_playing_for_id (string win_id, bool playing) {
		if (!queue_squared.contains (win_id)) return;
		queue_squared.get (win_id).playing = playing;
	}

	public void scrobble_all (Payload payload) {
		if (payload.track == null || payload.artist == null) return;

		//  (new Scrobbling.ListenBrainz ()).scrobble (payload, new GLib.DateTime.now ());
		//  (new Scrobbling.LastFM ()).scrobble (payload, new GLib.DateTime.now ());
		//  (new Scrobbling.LibreFM ()).scrobble (payload, new GLib.DateTime.now ());
	}

	public void send_scrobble (owned Soup.Message msg, string scrobbler_name) {
		session.send_async.begin (msg, 0, null, (obj, res) => {
			try {
				var in_stream = session.send_async.end (res);

				switch (msg.status_code) {
					case Soup.Status.OK:
						warning (@"$scrobbler_name SUCCESS $(msg.uri)");
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
