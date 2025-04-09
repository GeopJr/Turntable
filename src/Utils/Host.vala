public class Turntable.Utils.Host {
	public async static bool open_in_default_app (string uri, Gtk.Window window) {
		debug (@"Opening URI: $uri");

		try {
			yield (new Gtk.UriLauncher (uri)).launch (window, null);
		} catch (Error e) {
			warning (@"Error opening uri \"$uri\": $(e.message)");
			return yield open_in_default_app_using_dbus (uri);
		}

		return true;
	}

	private async static bool open_in_default_app_using_dbus (string uri) {
		try {
			yield AppInfo.launch_default_for_uri_async (uri, null, null);
		} catch (Error e) {
			warning (@"Error opening using launch_default_for_uri \"$uri\": $(e.message)");
			return false;
		}

		return true;
	}

	public static string lfm_signature (GLib.HashTable<string, string> params_to_hash, string secret) {
		GLib.StringBuilder signature = new GLib.StringBuilder ();
		var sorted_keys = params_to_hash.get_keys ();
		sorted_keys.sort (strcmp);

		foreach (string key in sorted_keys) {
			signature.append (@"$key$(params_to_hash.get (key))");
		}
		signature.append (secret);

		return GLib.Checksum.compute_for_string (GLib.ChecksumType.MD5, signature.str);
	}
}
