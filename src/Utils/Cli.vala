public class Turntable.Utils.CLI : GLib.Object {
	private Mpris.Entry? cli_last_player = null;

	private int64 _cli_length = 0;
	public int64 cli_length {
		get { return _cli_length; }
		set {
			_cli_length = value;
			if (value > 0) {
				cli_add_to_scrobbler ();
				if (this.cli_playing) cli_update_scrobbler_playing ();
			}
		}
	}

	private bool _cli_playing = false;
	public bool cli_playing {
		get { return _cli_playing; }
		set {
			_cli_playing = value;
			cli_update_scrobbler_playing ();
		}
	}

	construct {
	}

	public int run () {
		if (cli_list_clients) {
			stdout.printf ("Available MPRIS Clients: (ID - Name)\n");
			foreach (var client in mpris_manager.get_players ()) {
				stdout.printf (@"$(client.bus_namespace) - $(client.client_info_name)\n");
			}
			return 0;
		} else if (cli_client_id_scrobble != null) {
			if (cli_client_id_scrobble == "") {
				stderr.printf ("Please provide a Client ID\n");
				return 1;
			} else if (cli_client_id_scrobble.split (".").length < 4) {
				stderr.printf ("Please provide a valid Client ID\n");
				return 1;
			}

			settings = new Utils.Settings ();
			mpris_manager.players_changed.connect (cli_update_players);
			GLib.MainLoop loop = new GLib.MainLoop ();
			account_manager = new Scrobbling.AccountManager ();
			scrobbling_manager = new Scrobbling.Manager ();
			scrobbling_manager.cli_mode = true;

			try {
				account_manager.load_cli_sync ();
			} catch (Error e) {
				stderr.printf (@"Error while loading accounts: $(e.message)\n");
				return 1;
			}

			if (account_manager.accounts.length == 0) {
				stderr.printf (@"No Scrobbling accounts found, please set them up through $(Build.NAME)\n");
				return 1;
			}

			cli_update_players ();
			loop.run ();
		}

		return 0;
	}

	private void cli_update_players () {
		debug ("Updating players");

		Mpris.Entry? new_cli_player = null;
		foreach (var client in mpris_manager.get_players ()) {
			if (client.bus_namespace.down () == cli_client_id_scrobble.down ()) {
				new_cli_player = client;
				break;
			}
		}

		if (new_cli_player == null) {
			if (cli_last_player != null) {
				cli_last_player.terminate_player ();
				cli_last_player = null;
			}
			cli_player_changed ();
			return;
		}

		if (cli_last_player == null) {
			cli_last_player = new_cli_player;
			cli_last_player.initialize_player ();
			cli_player_changed ();
		}
	}

	GLib.Binding[] cli_player_bindings = {};
	private void cli_player_changed () {
		debug ("Player changed");

		scrobbling_manager.clear_queue ("1");
		foreach (var binding in cli_player_bindings) {
			binding.unbind ();
		}
		cli_player_bindings = {};

		if (cli_last_player == null) return;
		cli_player_bindings += this.cli_last_player.bind_property ("length", this, "cli-length", GLib.BindingFlags.SYNC_CREATE);
		cli_player_bindings += this.cli_last_player.bind_property ("playing", this, "cli-playing", GLib.BindingFlags.SYNC_CREATE);
	}

	private void cli_add_to_scrobbler () {
		if (this.cli_last_player == null || this.cli_last_player.length == 0) return;

		scrobbling_manager.queue_payload (
			"1",
			this.cli_last_player.bus_namespace,
			{ this.cli_last_player.title, this.cli_last_player.artist, this.cli_last_player.album },
			this.cli_last_player.length
		);
	}

	private void cli_update_scrobbler_playing () {
		if (this.cli_last_player == null || this.cli_last_player.length == 0) return;

		scrobbling_manager.set_playing_for_id (
			"1",
			this.cli_playing
		);
	}
}
