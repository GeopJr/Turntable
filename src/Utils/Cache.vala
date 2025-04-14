// While there have been ideas of caching both covers and colors,
// it seems unrealistic as we cannot guarantee that clients wont
// re-use file paths.
// Ideas like using metadata were also on the table but were
// discarded for similar reasons.
public class Turntable.Utils.Cache : GLib.Object {
	private GLib.HashTable<string, Utils.Color.ExtractedColors?> custom_color_cache;
	private GLib.Array<string> key_queue;

	construct {
		custom_color_cache = new GLib.HashTable<string, Utils.Color.ExtractedColors?> (str_hash, str_equal);
		key_queue = new GLib.Array<string> ();
	}

	public void add (string key, Utils.Color.ExtractedColors? value) {
		uint match = -1;
		if (key_queue.binary_search (key, GLib.strcmp, out match)) {
			custom_color_cache.set (key, value);
			if (match > -1 && match < key_queue.length - 1) {
				key_queue.append_val (key_queue.index (match));
				key_queue.remove_index (match);
			}
		} else {
			key_queue.append_val (key);
			custom_color_cache.set (key, value);

			if (key_queue.length > 10) {
				key_queue.remove_index (0);
			}
		}
	}

	public Utils.Color.ExtractedColors? get_val (string key) {
		if (custom_color_cache.contains (key)) {
			return custom_color_cache.get (key);
		}

		return null;
	}
}
