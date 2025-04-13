public class Turntable.Mpris.Entry : GLib.Object {
	public struct ClientInfo {
		public string identity;
		public string desktop_entry;
		public string icon;
	}

	public string parent_bus_namespace { get; private set; }
	public string bus_namespace { get; private set; }
	public ClientInfo client_info { get; private set; }
	public DesktopBus.Mpris.MediaPlayer2Player? player { get; private set; default = null; }
	private DesktopBus.Props? props { get; set; default = null; }

	// for expressions
	public string client_info_name { get { return this.client_info.identity; } }
	public string client_info_icon { get { return this.client_info.icon; } }

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
		this.player.play_pause ();
	}

	public void next () {
		this.player.next ();
	}

	public void back () {
		this.player.previous ();
	}

	public Entry (string name, DesktopBus.Mpris.MediaPlayer2 media_player) {
		this.bus_namespace = name;
		parent_bus_namespace = name;
		string[] namespace_parts = name.split (".");
		if (namespace_parts.length > 6) {
			parent_bus_namespace = @"org.mpris.MediaPlayer2.$(namespace_parts[0]).$(namespace_parts[1]).$(namespace_parts[2])";
		}

		var app_info = new GLib.DesktopAppInfo (@"$(media_player.desktop_entry).desktop");
		string icon = "application-x-executable-symbolic";
		if (app_info != null) {
			var app_icon = app_info.get_icon ();
			if (app_icon != null) icon = app_icon.to_string ();
		}

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

		GLib.Timeout.add (PROGRESS_UPDATE_TIME, update_position);
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
				case "CanGoNext":
				case "CanGoPrevious":
				case "CanPlay":
				case "CanPause":
					update_controls ();
					break;
				default:
					break;
			}
		});
	}

	private bool update_position () {
		if (this.props == null) return GLib.Source.REMOVE;

		int64 new_pos = (int64) this.props.get ("org.mpris.MediaPlayer2.Player", "Position");
		if (this.position != new_pos) this.position = new_pos;
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
			this.length = this.player.metadata["mpris:length"].get_int64 ();
		}
	}
}
