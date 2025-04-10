public class Turntable.Utils.Settings : GLib.Settings {
	public bool orientation_horizontal { get; set; }
	public string cover_style { get; set; }
	public bool component_progressbin { get; set; }
	public bool component_extract_colors { get; set; }
	public string window_style { get; set; }
	public bool client_icon_style_symbolic { get; set; }
	public bool component_client_icon { get; set; }
	public bool component_cover_fit { get; set; }
	public string[] scrobbler_allowlist { get; set; default = {}; }

	private const string[] KEYS_TO_INIT = {
		"orientation-horizontal",
		"cover-style",
		"component-progressbin",
		"component-extract-colors",
		"window-style",
		"client-icon-style-symbolic",
		"component-client-icon",
		"component-cover-fit",
		"scrobbler-allowlist"
	};

	public Settings () {
		Object (schema_id: Build.DOMAIN);

		foreach (var key in KEYS_TO_INIT) {
			init (key);
		}
	}

	public void remove_from_allowlist (string client_name) {
		if (client_name in this.scrobbler_allowlist) {
			string[] new_allowlist = {};

			foreach (var allowed_client in this.scrobbler_allowlist) {
				if (allowed_client != client_name) new_allowlist += allowed_client;
			}

			this.scrobbler_allowlist = new_allowlist;
		}
	}

	public void add_to_allowlist (string client_name) {
		if (client_name in this.scrobbler_allowlist) return;
		string[] new_allowlist = this.scrobbler_allowlist;
		new_allowlist += client_name;
		this.scrobbler_allowlist = new_allowlist;
	}

	inline void init (string key) {
		bind (key, this, key, SettingsBindFlags.DEFAULT);
	}
}
