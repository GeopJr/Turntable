public class Turntable.Mpris.Entry : GLib.Object {
	~Entry () {
		debug ("Destroying: %s (%s)", this.client_info_name, this.bus_namespace);
	}

	public struct ClientInfo {
		public string identity;
		public string desktop_entry;
		public string icon;
	}

	public string bus_namespace { get; private set; }
	public ClientInfo client_info { get; private set; }
	public DesktopBus.Mpris.MediaPlayer2Player? player { get; private set; default = null; }
	private DesktopBus.Props? props { get; set; default = null; }

	// for expressions
	public string client_info_name { get { return this.client_info.identity; } }
	public string client_info_icon { get { return this.client_info.icon; } }

	public bool looping { get; private set; default = false; }
	public bool can_go_next { get; private set; default = false; }
	public bool can_go_back { get; private set; default = false; }
	public bool can_control { get; private set; default = false; }
	public bool playing { get; private set; default = false; }
	public string? art { get; private set; default = null; }
	public string? title { get; private set; default = null; }
	public string? artist { get; private set; default = null; }
	public string? album { get; private set; default = null; }
	public int64 length { get; private set; default = -1; }
	public int64 position { get; private set; default = -1; }

	public void play_pause () {
		try {
			this.player.play_pause ();
		} catch (Error e) {
			debug ("Couldn't PlayPause: %s", e.message);
		}
	}

	public void next () {
		try {
			this.player.next ();
		} catch (Error e) {
			debug ("Couldn't Next: %s", e.message);
		}
	}

	public void back () {
		try {
			this.player.previous ();
		} catch (Error e) {
			debug ("Couldn't Previous: %s", e.message);
		}
	}

	#if SANDBOXED
		GLib.HashTable<string, string> cached_desktop_icons = new GLib.HashTable<string, string> (str_hash, str_equal);
		private string get_sandboxed_icon_for_id (string id) {
			if (cached_desktop_icons.contains (id)) return cached_desktop_icons.get (id);

			string icon = "application-x-executable-symbolic";
			try {
				var key_file = new GLib.KeyFile ();
				if (key_file.load_from_dirs (@"$id.desktop", desktop_file_dirs, null, GLib.KeyFileFlags.NONE)) {
					var icon_key = key_file.get_string ("Desktop Entry", "Icon");
					if (icon_key != null) icon = icon_key;
				}
			} catch {}

			cached_desktop_icons.set (id, icon);
			return icon;
		}
	#endif

	public Entry (string name, DesktopBus.Mpris.MediaPlayer2 media_player) {
		this.bus_namespace = name;

		string icon = "application-x-executable-symbolic";
		#if SCROBBLING
			if (!cli_mode) {
		#endif
			#if SANDBOXED
				if (media_player.desktop_entry != null) icon = get_sandboxed_icon_for_id (media_player.desktop_entry);
			#else
				var app_info = media_player.desktop_entry == null ? null : new GLib.DesktopAppInfo (@"$(media_player.desktop_entry).desktop");
				if (app_info != null) {
					var app_icon = app_info.get_icon ();
					if (app_icon != null) icon = app_icon.to_string ();
				} else if (media_player.desktop_entry == "spotify") {
					icon = "com.spotify.Client";
				}
			#endif
		#if SCROBBLING
			}
		#endif

		this.client_info = {
			media_player.identity,
			media_player.desktop_entry,
			icon
		};
	}

	int users = 0;
	public void initialize_player () {
		users += 1;
		if (player != null) return;

		try {
			this.player = Bus.get_proxy_sync (
				BusType.SESSION,
				this.bus_namespace,
				"/org/mpris/MediaPlayer2"
			);

			this.props = Bus.get_proxy_sync (
				BusType.SESSION,
				this.bus_namespace,
				"/org/mpris/MediaPlayer2"
			);

			this.props.properties_changed.connect (on_props_changed);

			update_metadata ();
			update_position ();
			update_playback_status ();
			update_controls ();
			update_loop_status ();

			GLib.Timeout.add (PROGRESS_UPDATE_TIME, update_position);
		} catch (Error e) {
			debug ("Couldn't setup Proxies for %s: %s", this.bus_namespace, e.message);
		}
	}

	public void terminate_player () {
		if (player == null) return;
		users -= 1;
		if (users > 0) return;

		this.props = null;
		this.player = null;
	}

	private void on_props_changed (string name, GLib.HashTable<string,Variant> changed, string[] invalid) {
		if (name != "org.mpris.MediaPlayer2.Player") return;

		changed.foreach ((key, value) => {
			switch (key) {
				case "Metadata":
					update_metadata ();
					break;
				case "PlaybackStatus":
					update_playback_status ();
					break;
				case "LoopStatus":
					update_loop_status ();
					break;
				case "CanGoNext":
				case "CanGoPrevious":
				case "CanPlay":
				case "CanPause":
				case "CanControl":
					update_controls ();
					break;
				default:
					break;
			}
		});
	}

	private void update_loop_status () {
		this.looping = this.player.loop_status == "Track";
	}

	private bool update_position () {
		if (this.props == null) return GLib.Source.REMOVE;

		try {
			int64 new_pos = (int64) this.props.get ("org.mpris.MediaPlayer2.Player", "Position");
			if (this.position != new_pos) this.position = new_pos;
		} catch (Error e) {
			debug ("Couldn't get Position: %s", e.message);
		}
		return GLib.Source.CONTINUE;
	}

	private void update_controls () {
		if (!this.player.can_control) {
			this.can_go_back =
			this.can_go_next =
			this.can_control = false;
			return;
		}

		this.can_go_back = this.player.can_go_previous;
		this.can_go_next = this.player.can_go_next;
		this.can_control = true;
	}

	private void update_playback_status () {
		this.playing = this.player.playback_status == "Playing";
	}

	private void update_metadata () {
		if (this.player.metadata.contains ("mpris:artUrl")) {
			string new_art = this.player.metadata["mpris:artUrl"].get_string ();
			if (new_art != this.art) this.art = new_art;
		} else {
			this.art = null;
		}

		if (this.player.metadata.contains ("xesam:title")) {
			string new_title = this.player.metadata["xesam:title"].get_string ().strip ();
			if (new_title == "") {
				this.title = null;
			} else if (new_title != this.title) {
				this.title = new_title;
			}
		} else {
			this.title = null;
		}

		if (this.player.metadata.contains ("xesam:artist")) {
			(unowned string)[] artists = this.player.metadata["xesam:artist"].get_strv ();
			string new_artist = string.joinv (", ", artists).strip ();

			if (new_artist == "") {
				this.artist = null;
			} else if (this.artist != new_artist) {
				this.artist = new_artist;
			}
		} else {
			this.artist = null;
		}

		if (this.player.metadata.contains ("xesam:album")) {
			string new_album = this.player.metadata["xesam:album"].get_string ().strip ();
			if (new_album == "") {
				this.album = null;
			} else if (new_album != this.album) {
				this.album = new_album;
			}
		} else {
			this.album = null;
		}

		if (this.player.metadata.contains ("mpris:length")) {
			var variant_length = this.player.metadata["mpris:length"];
			// Spec: "If the length of the track is known, it should be provided in the metadata property with the 'mpris:length' key.
			//		  The length must be given in microseconds, and be represented as a signed 64-bit integer."
			// Spotify:
			if (variant_length.is_of_type (GLib.VariantType.UINT64)) {
				this.length = (int64) variant_length.get_uint64 ();
			} else if (variant_length.is_of_type (GLib.VariantType.STRING)) { // whatever at this point, nobody reads the spec
				this.length = int64.parse (variant_length.get_string ());
			} else {
				this.length = variant_length.get_int64 ();
			}

			this.notify_property ("length");
		}
	}
}
