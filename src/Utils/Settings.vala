public class Turntable.Utils.Settings : GLib.Settings {
	public bool orientation_horizontal { get; set; }
	public string cover_style { get; set; }
	public bool component_progressbin { get; set; }
	public bool component_extract_colors { get; set; }
	public string window_style { get; set; }
	public string client_icon_style { get; set; }

	private const string[] KEYS_TO_INIT = {
		"orientation-horizontal",
		"cover-style",
		"component-progressbin",
		"component-extract-colors",
		"window-style",
		"client-icon-style"
	};

	public Settings () {
		Object (schema_id: Build.DOMAIN);

		foreach (var key in KEYS_TO_INIT) {
			init (key);
		}
	}

	inline void init (string key) {
		bind (key, this, key, SettingsBindFlags.DEFAULT);
	}
}
