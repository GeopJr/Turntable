public class Turntable.Widgets.ControlsOverlay : Adw.Bin {
	public signal void toggle_controls ();
	public signal void player_changed (Mpris.Entry? new_player);
	public Mpris.Entry? last_player { get; set; default = null; }

	~ControlsOverlay () {
		debug ("Destroying");
	}

	private bool _collapsed = false;
	public bool collapsed {
		get { return _collapsed; }
		set {
			_collapsed = value;
			if (value) {
				this.add_css_class ("collapsed");
			} else {
				this.remove_css_class ("collapsed");
			}
		}
	}

	private void update_style (Widgets.Cover.Style style, Gtk.Orientation orientation) {
		this.overlay.child.valign =
		this.overlay.child.halign =
		this.valign =
		this.halign = Gtk.Align.CENTER;

		switch (style) {
			case CARD:
				this.css_classes = { "card", "card-like" };
				break;
			case TURNTABLE:
				this.css_classes = { "card", "circular-art", "card-like", "clear-view" };
				break;
			case SHADOW:
				this.css_classes = { "fade" };
				this.overlay.child.valign =
				this.overlay.child.halign =
				this.valign =
				this.halign = Gtk.Align.FILL;
				break;
			default:
				assert_not_reached ();
		}

		switch (orientation) {
			case Gtk.Orientation.HORIZONTAL:
				this.add_css_class ("horizontal");
				break;
			default:
				this.add_css_class ("vertical");
				break;
		}

		if (this.collapsed) this.add_css_class ("collapsed");
	}

	#if SCROBBLING
		public class ScrobbleButton : Gtk.Button {
			private bool _enabled = false;
			public bool enabled {
				get { return _enabled; }
				set {
					if (_enabled != value) {
						_enabled = value;
						if (value) {
							// translators: button tooltip text
							this.tooltip_text = _("Disable Scrobbling");
							this.icon_name = "fingerprint2-symbolic";
						} else {
							// translators: button tooltip text
							this.tooltip_text = _("Enable Scrobbling");
							this.icon_name = "auth-fingerprint-symbolic";
						}
					}
				}
			}

			construct {
				this.icon_name = "auth-fingerprint-symbolic";
				this.tooltip_text = _("Enable Scrobbling");
			}
		}
	#endif

	Adw.TimedAnimation animation;
	Gtk.EventControllerMotion pointer_controller;
	Gtk.EventControllerFocus focus_controller;
	Gtk.Overlay overlay;
	GLib.ListStore players_store;
	Gtk.DropDown client_dropdown;
	Gtk.MenuButton menu_button;
	Gtk.Button toggle_controls_button;
	#if SCROBBLING
		ScrobbleButton scrobble_button;
	#endif
	construct {
		this.overflow = Gtk.Overflow.HIDDEN;
		this.valign = Gtk.Align.CENTER;
		this.halign = Gtk.Align.CENTER;

		overlay = new Gtk.Overlay () {
			focusable = true
		};

		players_store = new GLib.ListStore (typeof (Mpris.Entry));
		mpris_manager.players_changed.connect (update_store);

		client_dropdown = new Gtk.DropDown (players_store, new Gtk.PropertyExpression (typeof (Mpris.Entry), null, "client-info-name")) {
			enable_search = false,
			factory = new Gtk.BuilderListItemFactory.from_resource (null, @"$(Build.RESOURCES)gtk/dropdown/client_display.ui"),
			list_factory = new Gtk.BuilderListItemFactory.from_resource (null, @"$(Build.RESOURCES)gtk/dropdown/client.ui"),
			// translators: dropdown tooltip text
			tooltip_text = _("Select Player"),
			css_classes = { "client-chooser" },
			margin_start = 8,
			margin_end = 8
		};
		client_dropdown.notify["selected"].connect (selection_changed);

		{
			var toggle_btn = client_dropdown.get_first_child () as Gtk.ToggleButton;
			if (toggle_btn != null) toggle_btn.add_css_class ("osd");
		}

		var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
			vexpand = true,
			hexpand = true,
			valign = Gtk.Align.CENTER,
			halign = Gtk.Align.CENTER
		};
		main_box.append (client_dropdown);

		var sub_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
			halign = Gtk.Align.CENTER
		};
		var menu_model = new GLib.Menu ();
		var main_section_model = new GLib.Menu ();
		// translators: menu entry
		main_section_model.append (_("New Window"), "app.new-window");
		#if SCROBBLING
		// translators: menu entry that opens a dialog
			main_section_model.append (_("Scrobbling"), "win.open-scrobbling-setup");
		#endif
		menu_model.append_section (null, main_section_model);

		var style_section_model = new GLib.Menu ();
		var component_submenu_model = new GLib.Menu ();
		// translators: whether to show the (window) background progress bar
		component_submenu_model.append (_("Background Progress"), "win.component-progressbin");
		// translators: whether to show center the title, album and artist labels
		component_submenu_model.append (_("Center Text"), "win.component-center-text");
		// translators: whether to make the artist and album labels slightly transparent / less prominent
		component_submenu_model.append (_("Dim Metadata Labels"), "win.meta-dim");
		// translators: whether to fit the cover art in the cover; this will stretch or crop art that is not square
		component_submenu_model.append (_("Fit Art on Cover"), "win.component-cover-fit");
		// translators: whether to extract the colors of the cover and use them in UI elements (like Amberol or Material You)
		component_submenu_model.append (_("Extract Cover Colors"), "win.component-extract-colors");
		// translators: whether to hide the client icon when the controls are collapsed
		component_submenu_model.append (_("Hide Client Icon when Collapsed"), "win.hide-client-icon-collapsed");
		// translators: whether to show the shuffle and loop buttons
		component_submenu_model.append (_("More Player Controls"), "win.component-more-controls");
		// translators: whether to show a turntable tonearm in turntable styled cover art; tonearm is the 'arm' part of the turntable,
		//				you may translate it as 'arm' (mechanical part)
		component_submenu_model.append (_("Tonearm"), "win.component-tonearm");
		// translators: menu entry that opens a submenu; components = toggleable parts of the UI
		style_section_model.append_submenu (_("Components"), component_submenu_model);

		var cover_scaling_submenu_model = new GLib.Menu ();
		// translators: cover scaling algorithm name, probably leave as is
		cover_scaling_submenu_model.append (_("Linear"), "win.cover-scaling('linear')");
		// translators: cover scaling algorithm name, probably leave as is
		cover_scaling_submenu_model.append (_("Nearest"), "win.cover-scaling('nearest')");
		// translators: cover scaling algorithm name, probably leave as is
		cover_scaling_submenu_model.append (_("Trilinear"), "win.cover-scaling('trilinear')");
		// translators: menu entry that opens a submenu; cover scaling = algorithm used for down/upscaling cover art
		style_section_model.append_submenu (_("Cover Scaling"), cover_scaling_submenu_model);

		var orientation_submenu_model = new GLib.Menu ();
		// translators: orientation name
		orientation_submenu_model.append (_("Horizontal"), "win.toggle-orientation(true)");
		// translators: orientation name
		orientation_submenu_model.append (_("Vertical"), "win.toggle-orientation(false)");
		// translators: menu entry that opens a submenu; as in whether it's horizontal or vertical
		style_section_model.append_submenu (_("Orientation"), orientation_submenu_model);

		var size_submenu_model = new GLib.Menu ();
		var cover_size_submenu_model = new GLib.Menu ();
		// translators: cover size
		cover_size_submenu_model.append (_("Small"), "win.cover-size('small')");
		// translators: cover size
		cover_size_submenu_model.append (_("Regular"), "win.cover-size('regular')");
		// translators: cover size
		cover_size_submenu_model.append (_("Big"), "win.cover-size('big')");
		// translators: menu entry that opens a submenu; cover = the song cover art
		size_submenu_model.append_submenu ("%s ".printf (_("Cover")), cover_size_submenu_model); // https://gitlab.gnome.org/GNOME/gtk/-/issues/7064
		// translators: menu entry that opens a submenu
		style_section_model.append_submenu (_("Size"), size_submenu_model);

		var text_size_submenu_model = new GLib.Menu ();
		// translators: text style (size)
		text_size_submenu_model.append (_("Small"), "win.text-size('small')");
		// translators: text style (size)
		text_size_submenu_model.append (_("Regular"), "win.text-size('regular')");
		// translators: text style (size)
		text_size_submenu_model.append (_("Big"), "win.text-size('big')");
		// translators: menu entry that opens a submenu; text = all the app text, may be translated to fonts
		size_submenu_model.append_submenu (_("Text"), text_size_submenu_model);

		var style_submenu_model = new GLib.Menu ();
		var client_style_submenu_model = new GLib.Menu ();
		client_style_submenu_model.append (_("None"), "win.client-icon-style('none')");
		// translators: cover icon style; symbolic = the monochrome simplified version
		client_style_submenu_model.append (_("Symbolic"), "win.client-icon-style('symbolic')");
		// translators: cover icon style
		client_style_submenu_model.append (_("Full Color"), "win.client-icon-style('full-color')");
		// translators: menu entry that opens a submenu; client = music playing app
		style_submenu_model.append_submenu (_("Client Icon"), client_style_submenu_model);

		var cover_style_submenu_model = new GLib.Menu ();
		// translators: cover image style; it's a square with rounded corners
		cover_style_submenu_model.append (_("Card"), "win.cover-style('card')");
		// translators: cover image style; it's a rotating record like on a turntable
		cover_style_submenu_model.append (_("Turntable"), "win.cover-style('turntable')");
		// translators: cover image style; it's a fading out effect; may be translated to 'Fade'
		cover_style_submenu_model.append (_("Shadow"), "win.cover-style('shadow')");
		// translators: menu entry that opens a submenu
		style_submenu_model.append_submenu (_("Cover"), cover_style_submenu_model);

		var scale_style_submenu_model = new GLib.Menu ();
		// translators: progressbar style; disable it
		scale_style_submenu_model.append (_("None"), "win.progressscale-style('none')");
		// translators: progressbar style; default gtk style, has a big knob / circle as the position marker
		scale_style_submenu_model.append (_("Knob"), "win.progressscale-style('knob')");
		// translators: progressbar style; hard to explain, looks like amberol's volume bar
		scale_style_submenu_model.append (_("Overlay"), "win.progressscale-style('overlay')");
		// translators: menu entry that opens a submenu
		style_submenu_model.append_submenu (_("Progress Bar"), scale_style_submenu_model);

		var window_style_submenu_model = new GLib.Menu ();
		// translators: window style name
		window_style_submenu_model.append (_("Window"), "win.window-style('window')");
		// translators: window style name, probably leave it as is; OSD = on screen display,
		//				it's the dark semi-trasparent background and white text style
		window_style_submenu_model.append (_("OSD"), "win.window-style('osd')");
		// translators: window style name
		window_style_submenu_model.append (_("Transparent"), "win.window-style('transparent')");
		// translators: window style name
		window_style_submenu_model.append (_("Blur"), "win.window-style('blur')");
		// translators: menu entry that opens a submenu
		style_submenu_model.append_submenu (_("Window"), window_style_submenu_model);

		// translators: menu entry that opens a submenu
		style_section_model.append_submenu (_("Style"), style_submenu_model);
		menu_model.append_section (null, style_section_model);

		var misc_section_model = new GLib.Menu ();
		misc_section_model = new GLib.Menu ();
		//  misc_section_model.append (_("Keyboard Shortcuts"), "win.show-help-overlay");

		misc_section_model.append (_("Preferences"), "app.preferences");
		// translators: menu entry, variable is the app name (Turntable)
		misc_section_model.append (_("About %s").printf (Build.NAME), "app.about");
		// translators: menu entry
		misc_section_model.append (_("Quit"), "app.quit");
		menu_model.append_section (null, misc_section_model);

		#if SCROBBLING
			scrobble_button = new ScrobbleButton () {
				css_classes = {"circular", "osd", "min34px"},
				sensitive = false,
				enabled = false
			};
			scrobble_button.clicked.connect (on_scrobble_client_toggle);
			sub_box.append (scrobble_button);

			account_manager.accounts_changed.connect (on_accounts_changed);
			on_accounts_changed ();
		#endif

		toggle_controls_button = new Gtk.Button () {
			css_classes = {"circular", "osd", "min34px"},
			icon_name = "dock-right-symbolic",
			// translators: tooltip for button that hides/shows all the media controls and labels
			tooltip_text = _("Toggle Controls")
		};
		toggle_controls_button.clicked.connect (on_toggle_controls_button);
		sub_box.append (toggle_controls_button);

		menu_button = new Gtk.MenuButton () {
			icon_name = "menu-large-symbolic",
			primary = true,
			menu_model = menu_model,
			css_classes = {"circular", "osd"},
			tooltip_text = _("Menu")
		};
		sub_box.append (menu_button);
		main_box.append (sub_box);
		var main_bin = new Adw.Bin () {
			css_classes = {"osd"},
			child = main_box,
			opacity = 0
		};
		animation = new Adw.TimedAnimation (this, 0.0, 1.0, 250, new Adw.PropertyAnimationTarget (main_bin, "opacity")) {
			easing = Adw.Easing.EASE_IN_OUT
		};

		overlay.add_overlay (main_bin);
		this.child = overlay;

		update_store ();

		focus_controller = new Gtk.EventControllerFocus ();
		focus_controller.enter.connect (on_main_bin_enter);
		focus_controller.leave.connect (on_main_bin_leave_focus);
		main_bin.add_controller (focus_controller);

		pointer_controller = new Gtk.EventControllerMotion ();
		pointer_controller.enter.connect (on_main_bin_enter);
		pointer_controller.leave.connect (on_main_bin_leave_pointer);
		main_bin.add_controller (pointer_controller);
	}

	private void on_main_bin_enter () {
		animation.value_from = animation.value;
		animation.value_to = 1;
		animation.play ();
	}

	// properties updated AFTER the signals
	// so we have to assume here without using them
	private void on_main_bin_leave_focus () {
		if (pointer_controller.is_pointer || pointer_controller.contains_pointer) return;
		hide_main_bin_overlay ();
	}

	private void on_main_bin_leave_pointer () {
		if (focus_controller.is_focus || focus_controller.contains_focus) return;
		hide_main_bin_overlay ();
	}

	private void hide_main_bin_overlay () {
		animation.value_from = animation.value;
		animation.value_to = 0;
		animation.play ();
	}

	public ControlsOverlay (Widgets.Cover cover) {
		this.overlay.child = cover;
		cover.style_changed.connect (update_style);
		update_style (cover.style, cover.orientation);
	}

	public void update_toggle_controls_icon () {
		toggle_controls_button.icon_name = settings.orientation_horizontal
			? (Gtk.Widget.get_default_direction () == Gtk.TextDirection.RTL ? "dock-left-symbolic" : "dock-right-symbolic")
			: "dock-bottom-symbolic";
	}

	public bool hide_overlay () {
		if (
			pointer_controller.is_pointer
			|| pointer_controller.contains_pointer
			|| menu_button.active
			|| ((Gtk.ToggleButton) client_dropdown.get_first_child ()).active
		) return false;
		hide_main_bin_overlay ();
		return true;
	}

	private void on_toggle_controls_button () {
		toggle_controls ();
	}

	private bool done_initial_active_check = false;
	private void update_store () {
		players_store.splice (0, players_store.n_items, mpris_manager.get_players ());
		players_store.sort ((GLib.CompareDataFunc<Mpris.Entry>) compare_players);
		client_dropdown.enable_search = players_store.n_items > 10;

		if (!done_initial_active_check) {
			done_initial_active_check = true;
			if (players_store.n_items > 1) {
				mpris_manager.active_player.begin ((obj, res) => {
					Mpris.Entry? active_player = mpris_manager.active_player.end (res);
					if (active_player != null) {
						uint pos;
						if (players_store.find (active_player, out pos)) {
							client_dropdown.selected = pos;
						}
					}
				});
			}
		}

		if (this.last_player == null) selection_changed (); // if always ensure player
	}

	private static int compare_players (Mpris.Entry a, Mpris.Entry b) {
		return a.client_info.identity.collate (b.client_info.identity);
	}

	private void selection_changed () {
		debug ("Changed player");
		bool was_null = this.last_player == null;

		if (client_dropdown.selected == Gtk.INVALID_LIST_POSITION) {
			if (!was_null) {
				this.last_player.terminate_player ();
				this.last_player = null;
				trigger_player_changed (null);
			}
			return;
		}

		var new_last_player = (Mpris.Entry?) players_store.get_item (client_dropdown.selected);
		if (!was_null && new_last_player != null && new_last_player.bus_namespace == this.last_player.bus_namespace) return;

		if (!was_null) this.last_player.terminate_player ();
		this.last_player = new_last_player;
		if (this.last_player == null) {
			if (!was_null) trigger_player_changed (null);
			return;
		}

		this.last_player.initialize_player ();
		trigger_player_changed (this.last_player);
	}

	private inline void trigger_player_changed (Mpris.Entry? new_entry) {
		player_changed (new_entry);
		#if SCROBBLING
			update_scrobble_button ();
		#endif
	}

	#if SCROBBLING
		private void update_scrobble_button () {
			if (this.last_player == null) {
				scrobble_button.sensitive = false;
				scrobble_button.enabled = false;
				return;
			}

			scrobble_button.sensitive = true;
			scrobble_button.enabled = this.last_player.bus_namespace in settings.scrobbler_allowlist;
		}

		private void on_accounts_changed () {
			scrobble_button.visible = account_manager.accounts.length > 0;
		}

		private void on_scrobble_client_toggle () {
			update_scrobble_button ();

			if (scrobble_button.enabled) {
				settings.remove_from_allowlist (this.last_player.bus_namespace);
			} else {
				settings.add_to_allowlist (this.last_player.bus_namespace);
			}
			scrobble_button.enabled = !scrobble_button.enabled;
		}
	#endif
}
