public class Turntable.Scrobbling.AccountManager : GLib.Object {
	const string VERSION = "1";
	Secret.Schema schema;
	GLib.HashTable<string, Secret.SchemaAttributeType> schema_attributes;

	public signal void accounts_changed ();
	public GLib.HashTable<string, ScrobblerAccount> accounts { get; private set; }
	public class ScrobblerAccount : GLib.Object {
		public string username { get; set; }
		public string token { get; set; }
		public string? custom_url { get; set; }

		public ScrobblerAccount (string username, string token, string? custom_url = null) {
			this.username = username;
			this.token = token;
			this.custom_url = custom_url;
		}
	}

	construct {
		accounts = new GLib.HashTable<string, ScrobblerAccount> (str_hash, str_equal);
		schema_attributes = new GLib.HashTable<string, Secret.SchemaAttributeType> (str_hash, str_equal);
		schema_attributes["version"] = Secret.SchemaAttributeType.STRING;
		schema = new Secret.Schema.newv (
			Build.DOMAIN,
			Secret.SchemaFlags.NONE,
			schema_attributes
		);
	}

	public void add (Scrobbling.Manager.Provider provider, string username, string token, string? custom_url = null) {
		accounts.set (provider.to_string (), new ScrobblerAccount (username, token, custom_url));
		accounts_changed ();
	}

	public void remove (Scrobbling.Manager.Provider provider) {
		accounts.remove (provider.to_string ());
		accounts_changed ();
	}

	bool loaded = false;
	public void load () {
		if (loaded) return;
		loaded = true;

		var attrs = new GLib.HashTable<string,string> (str_hash, str_equal);
		attrs["version"] = VERSION;

		Secret.password_searchv.begin (
			schema,
			attrs,
			Secret.SearchFlags.UNLOCK,
			null,
			(obj, res) => {
				try {
					List<Secret.Retrievable> secrets = Secret.password_searchv.end (res);
					secrets.foreach (item => {
						load_to_store (item);
					});
				} catch (GLib.Error e) {
					string wiki_page = "https://github.com/GeopJr/Tuba/wiki/keyring-issues";

					// Let's leave this untranslated for now
					string help_msg = "If you didn’t manually cancel it, try creating a password keyring named \"login\" using Passwords and Keys (seahorse) or KWalletManager";

					if (e.message == "org.freedesktop.DBus.Error.ServiceUnknown") {
						wiki_page = "https://github.com/GeopJr/Tuba/wiki/libsecret-issues";
						help_msg = @"$(e.message), $(Build.NAME) might be missing some permissions";
					}

					critical (@"Error while searching for items in the secret service: $(e.message)");
					warning (@"$help_msg\nread more: $wiki_page");

					var dlg = new Adw.AlertDialog (
						"Error while searching for user accounts",
						@"$help_msg."
					);

					dlg.add_responses (
						"cancel", _("_Cancel"),
						"read", _("_Read More")
					);
					dlg.set_default_response ("read");
					dlg.set_response_appearance ("read", Adw.ResponseAppearance.SUGGESTED);

					dlg.choose.begin (application.active_window, null, (obj, res) => {
						if (dlg.choose.end (res) == "read") {
							Utils.Host.open_in_default_app.begin (wiki_page, application.active_window, (obj, res) => {
								Utils.Host.open_in_default_app.end (res);
								Process.exit (1);
							});
						} else {
							Process.exit (1);
						}
					});
				}
			}
		);
	}

	public void load_cli_sync () throws Error {
		if (loaded) return;
		loaded = true;

		var attrs = new GLib.HashTable<string,string> (str_hash, str_equal);
		attrs["version"] = VERSION;

		List<Secret.Retrievable> secrets = Secret.password_searchv_sync (
			schema,
			attrs,
			Secret.SearchFlags.UNLOCK,
			null
		);

		secrets.foreach (item => {
			load_to_store_sync (item);
		});
	}

	public void save () {
		var attrs = new GLib.HashTable<string,string> (str_hash, str_equal);
		attrs["version"] = VERSION;
		StringBuilder providers = new StringBuilder ();

		var generator = new Json.Generator ();
		var builder = new Json.Builder ();
		builder.begin_array ();

		accounts.foreach ((k, v) => {
			providers.append (k);
			providers.append_c (' ');
			builder.begin_object ();
				builder.set_member_name ("provider");
				builder.add_string_value (k);
				builder.set_member_name ("username");
				builder.add_string_value (v.username);
				builder.set_member_name ("token");
				builder.add_string_value (v.token);
				builder.set_member_name ("custom_url");
				builder.add_string_value (v.custom_url);
			builder.end_object ();
		});

		builder.end_array ();
		generator.set_root (builder.get_root ());
		var secret = generator.to_data (null);
		Secret.password_storev.begin (
			schema,
			attrs,
			Secret.COLLECTION_DEFAULT,
			"Scrobbler Accounts",
			secret,
			null,
			(obj, async_res) => {
				try {
					Secret.password_store.end (async_res);
					debug (@"Saved scrobbler accounts: $(providers.str)");
				} catch (GLib.Error e) {
					critical (@"Couldn't save accounts: $(e.message)");
				}
			}
		);
	}

	private void load_to_store (Secret.Retrievable item) {
		item.retrieve_secret.begin (null, (obj, res) => {
			try {
				var secret = item.retrieve_secret.end (res);
				load_to_store_actual (secret);
			} catch (Error e) {
				critical (@"Couldn't load accounts to store: $(e.message)");
			}
		});
	}

	private void load_to_store_sync (Secret.Retrievable item) throws Error {
		load_to_store_actual (item.retrieve_secret_sync (null));
	}

	private inline void load_to_store_actual (Secret.Value secret) throws Error {
		var contents = secret.get_text ();
		var parser = new Json.Parser ();
		parser.load_from_data (contents, -1);

		var root = parser.get_root ();
		if (root == null) throw new Error.literal (-1, 3, "Malformed json");

		var root_arr = root.get_array ();
		if (root_arr == null) throw new Error.literal (-1, 3, "Malformed json");

		accounts.remove_all ();
		root_arr.foreach_element ((arr, i, node) => {
			var arr_obj = node.get_object ();
			string provider = arr_obj.get_string_member ("provider");
			accounts.set (
				provider,
				new ScrobblerAccount (
					arr_obj.get_string_member ("username"),
					arr_obj.get_string_member ("token"),
					arr_obj.has_member ("custom_url") ? arr_obj.get_string_member ("custom_url") : null
				)
			);
		});

		accounts_changed ();
	}
}
