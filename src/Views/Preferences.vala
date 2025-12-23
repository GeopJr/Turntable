public class Turntable.Views.Preferences : Adw.PreferencesDialog {
	Adw.SwitchRow autostart;
	Adw.SwitchRow background;
	Adw.SwitchRow hidden;

	private void update_hidden (bool active_val = hidden.active) {
		bool enabled = autostart.active && background.active;
		bool active = enabled && active_val;

		// translators: switch description on "Start Hidden" notifying the user that they need to enable the other options first
		hidden.subtitle = enabled ? null : _("Requires both running on startup and in background");
		hidden.sensitive = enabled;
		if (active != hidden.active) hidden.active = active; // needed so it doesn't trigger out running_changed
	}

	construct {
		this.title = _("Preferences");
		this.can_close = false;
		this.close_attempt.connect (on_close);

		var main_page = new Adw.PreferencesPage () {
			icon_name = "settings-symbolic",
			title = _("Preferences")
		};

		autostart = new Adw.SwitchRow () {
			// translators: switch title, enables autostart on boot
			title = _("Run on Startup")
		};

		background = new Adw.SwitchRow () {
			// translators: switch title, enables the background portal
			title = _("Keep Running in Background")
		};

		hidden = new Adw.SwitchRow () {
			// translators: switch title, starts the app hidden if it starts on boot
			title = _("Start Hidden")
		};
		reset_all_toggles ();

		autostart.notify["active"].connect (changed_running);
		hidden.notify["active"].connect (changed_running);
		background.notify["active"].connect (changed_running);

		//  var autoselect_row = new Adw.ActionRow () {
		//  	activatable = false,
		//  	title = _("Client Auto-select Mode"),
		//  	description = _("Selection criteria for when there are multiple MRPIS clients available and %s has to choose one automatically.")
		//  };

		//  var toggle_group = new Adw.ToggelGroup ();
		//  toggle_group.add (new Adw.Toggle () { name = "playing", label = _() });
		//  toggle_group.add (new Adw.Toggle () { name = "allowlist", label = _("Allowlist") });

		//  var prefix_group = new Adw.PreferencesGroup ();
		//  prefix_group.add (autostart);
		//  main_page.add (prefix_group);

		var main_group = new Adw.PreferencesGroup () {
			// translators: Running settings group title, like "Running in the background"
			title = _("Running"),
			// translators: Running settings group description, the variable is the app name (Turntable),
			//				the purpose of this description is to push users towards the CLI version of
			//				Turntable if they want to scrobble in the background
			description = _("While it's possible to have %s run in the background for constant scrobbling, it's recommended to use the CLI instead as it's much more performant, skips initializing the GUI code entirely and can lock to specific MPRIS clients.").printf (Build.NAME)
		};
		main_group.add (background);
		main_group.add (autostart);
		main_group.add (hidden);
		main_page.add (main_group);
		this.add (main_page);
	}

	private bool running_changed = false;
	private void changed_running () {
		update_hidden ();
		running_changed = true;
	}

	// let's just do it in one go so we only send 1 request
	private async bool save () {
		// while it might be tempting to check if they actually changed,
		// we need to remember that people often backup and restore their gsettings
		// and this would cause issues here as it would never request the portal.
		// Instead we will check if anything was switched at all (even if switched back).
		if (!running_changed) return true;

		try {
			if (yield application.request_autostart (autostart.active, hidden.active)) {
				settings.autostart = autostart.active;
				settings.start_hidden = hidden.active;
				settings.run_in_background = background.active;
			}
		} catch (Error e) {
			reset_all_toggles ();
			warning (@"Couldn't set background portal: $(e.message) $(e.code)");
			on_error (e.message);
			return false;
		}

		return true;
	}

	private void reset_all_toggles () {
		background.active = settings.run_in_background;
		autostart.active = settings.autostart;
		update_hidden (settings.start_hidden);
		running_changed = false;
	}

	private void on_error (string error) {
		this.add_toast (new Adw.Toast (error));
	}

	private void on_close () {
		save.begin ((obj, res) => {
			if (save.end (res)) this.force_close ();
		});
	}
}
