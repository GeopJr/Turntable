public class Turntable.Utils.Settings : GLib.Settings {
	public bool orientation_horizontal { get; set; }
	public string cover_style { get; set; }

	private static string[] keys_to_init = {
		"orientation-horizontal",
		"cover-style"
	};

	public Settings () {
		Object (schema_id: Build.DOMAIN);

		foreach (var key in keys_to_init) {
			init (key);
		}
	}

	inline void init (string key) {
		bind (key, this, key, SettingsBindFlags.DEFAULT);
	}
}
