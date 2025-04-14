public class Turntable.Mpris.Manager : GLib.Object {
	GLib.Array<Mpris.Entry> entries = new GLib.Array<Mpris.Entry> ();
	public signal void players_changed ();

	public unowned Mpris.Entry[] get_players () {
		return entries.data;
	}

	DesktopBus.Base dbus_base;
	construct {
		try {
			dbus_base = Bus.get_proxy_sync (BusType.SESSION, "org.freedesktop.DBus", "/org/freedesktop/DBus");

			foreach (var name in dbus_base.list_names ()) {
				if (!name.has_prefix ("org.mpris.MediaPlayer2.")) continue;

				add_player (name);
			}

			dbus_base.name_owner_changed.connect (on_name_owner_changed);
		} catch (Error e) {
			critical ("Couldn't get all MPRIS Clients: %s", e.message);
		}
	}

	void add_player (string name) {
		try {
			DesktopBus.Mpris.MediaPlayer2 mpris = Bus.get_proxy_sync (
				BusType.SESSION,
				name,
				"/org/mpris/MediaPlayer2"
			);

			entries.append_val (new Mpris.Entry (name, mpris));
			players_changed ();
		} catch (Error e) {
			debug ("Couldn't add Player for %s: %s", name, e.message);
		}
	}

	void remove_player (string name, bool whole_bus = false) {
		bool removed = false;
		for (int i = 0; i < entries.length ; i++) {
			var entry = entries.index (i);
			string name_for_removal = whole_bus ? entry.parent_bus_namespace : entry.bus_namespace;
			if (name_for_removal != name) continue;

			entries.remove_index_fast (i);
			removed = true;
		}

		if (removed) players_changed ();
	}

	public void on_name_owner_changed (string name, string old_owner, string new_owner) {
		if (!name.has_prefix ("org.mpris.MediaPlayer2.")) return;
		if (old_owner == "") {
			add_player (name);
		} else {
			remove_player (name);
		}
	}
}
