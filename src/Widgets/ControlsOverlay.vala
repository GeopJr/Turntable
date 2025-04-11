public class Turntable.Widgets.ControlsOverlay : Adw.Bin {
	public signal void player_changed (Mpris.Entry? new_player);
	public Mpris.Entry? last_player { get; set; default = null; }

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
				this.css_classes = { "card", "circular-art", "card-like" };
				break;
			case SHADOW:
				this.css_classes = {};
				this.overlay.child.valign =
				this.overlay.child.halign =
				this.valign =
				this.halign = Gtk.Align.FILL;
				break;
			default:
				assert_not_reached ();
				break;
		}

		switch (orientation) {
			case Gtk.Orientation.HORIZONTAL:
				this.add_css_class ("horizontal");
				break;
			default:
				this.add_css_class ("vertical");
				break;
		}
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
							this.tooltip_text = _("Disable Scrobbling");
							this.icon_name = "fingerprint2-symbolic";
						} else {
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

	Gtk.Overlay overlay;
	Gtk.Revealer revealer;
	GLib.ListStore players_store;
	Gtk.DropDown client_dropdown;
	Gtk.MenuButton menu_button;
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
		revealer = new Gtk.Revealer () {
			reveal_child = false,
			transition_duration = 250,
			transition_type = Gtk.RevealerTransitionType.CROSSFADE
		};

		players_store = new GLib.ListStore (typeof (Mpris.Entry));
		mpris_manager.players_changed.connect (update_store);

		client_dropdown = new Gtk.DropDown (players_store, new Gtk.PropertyExpression (typeof (Mpris.Entry), null, "client-info-name")) {
			enable_search = false,
			factory = new Gtk.BuilderListItemFactory.from_resource (null, @"$(Build.RESOURCES)gtk/dropdown/client_display.ui"),
			list_factory = new Gtk.BuilderListItemFactory.from_resource (null, @"$(Build.RESOURCES)gtk/dropdown/client.ui"),
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
		main_section_model.append (_("New Window"), "app.new-window");
		#if SCROBBLING
			main_section_model.append (_("Scrobbling"), "win.open-scrobbling-setup");
		#endif
		menu_model.append_section (null, main_section_model);

		var style_section_model = new GLib.Menu ();
		var component_submenu_model = new GLib.Menu ();
		component_submenu_model.append (_("Background Progress"), "win.component-progressbin");
		component_submenu_model.append (_("Client Icon"), "win.component-client-icon");
		component_submenu_model.append (_("Dim Metadata Labels"), "win.meta-dim");
		component_submenu_model.append (_("Fit Art on Cover"), "win.component-cover-fit");
		component_submenu_model.append (_("Extract Cover Colors"), "win.component-extract-colors");
		style_section_model.append_submenu (_("Components"), component_submenu_model);

		var cover_scaling_submenu_model = new GLib.Menu ();
		cover_scaling_submenu_model.append (_("Linear"), "win.cover-scaling('linear')");
		cover_scaling_submenu_model.append (_("Nearest"), "win.cover-scaling('nearest')");
		cover_scaling_submenu_model.append (_("Trilinear"), "win.cover-scaling('trilinear')");
		style_section_model.append_submenu (_("Cover Scaling"), cover_scaling_submenu_model);

		var orientation_submenu_model = new GLib.Menu ();
		orientation_submenu_model.append (_("Horizontal"), "win.toggle-orientation(true)");
		orientation_submenu_model.append (_("Vertical"), "win.toggle-orientation(false)");
		style_section_model.append_submenu (_("Orientation"), orientation_submenu_model);

		var size_submenu_model = new GLib.Menu ();
		var cover_size_submenu_model = new GLib.Menu ();
		cover_size_submenu_model.append (_("Small"), "win.cover-size('small')");
		cover_size_submenu_model.append (_("Regular"), "win.cover-size('regular')");
		cover_size_submenu_model.append (_("Big"), "win.cover-size('big')");
		size_submenu_model.append_submenu ("%s ".printf (_("Cover")), cover_size_submenu_model); // https://gitlab.gnome.org/GNOME/gtk/-/issues/7064
		style_section_model.append_submenu (_("Size"), size_submenu_model);

		var text_size_submenu_model = new GLib.Menu ();
		text_size_submenu_model.append (_("Small"), "win.text-size('small')");
		text_size_submenu_model.append (_("Regular"), "win.text-size('regular')");
		text_size_submenu_model.append (_("Big"), "win.text-size('big')");
		size_submenu_model.append_submenu (_("Text"), text_size_submenu_model);

		var style_submenu_model = new GLib.Menu ();
		var client_style_submenu_model = new GLib.Menu ();
		client_style_submenu_model.append (_("Symbolic"), "win.client-icon-style-symbolic(true)");
		client_style_submenu_model.append (_("Full Color"), "win.client-icon-style-symbolic(false)");
		style_submenu_model.append_submenu (_("Client Icon"), client_style_submenu_model);

		var cover_style_submenu_model = new GLib.Menu ();
		cover_style_submenu_model.append (_("Card"), "win.cover-style('card')");
		cover_style_submenu_model.append (_("Turntable"), "win.cover-style('turntable')");
		cover_style_submenu_model.append (_("Shadow"), "win.cover-style('shadow')");
		style_submenu_model.append_submenu (_("Cover"), cover_style_submenu_model);

		var window_style_submenu_model = new GLib.Menu ();
		window_style_submenu_model.append (_("Window"), "win.window-style('window')");
		window_style_submenu_model.append (_("OSD"), "win.window-style('osd')");
		window_style_submenu_model.append (_("Transparent"), "win.window-style('transparent')");
		style_submenu_model.append_submenu (_("Window"), window_style_submenu_model);

		style_section_model.append_submenu (_("Style"), style_submenu_model);
		menu_model.append_section (null, style_section_model);

		var misc_section_model = new GLib.Menu ();
		misc_section_model = new GLib.Menu ();
		//  misc_section_model.append (_("Keyboard Shortcuts"), "win.show-help-overlay");
		misc_section_model.append (_("About %s").printf (Build.NAME), "app.about");
		misc_section_model.append (_("Quit"), "app.quit");
		menu_model.append_section (null, misc_section_model);

		#if SCROBBLING
			scrobble_button = new ScrobbleButton () {
				css_classes = {"circular", "osd", "min34px"}
			};
			scrobble_button.clicked.connect (on_scrobble_client_toggle);
			sub_box.append (scrobble_button);

			account_manager.accounts_changed.connect (on_accounts_changed);
			on_accounts_changed ();
		#endif

		menu_button = new Gtk.MenuButton () {
			icon_name = "menu-large-symbolic",
			primary = true,
			menu_model = menu_model,
			css_classes = {"circular", "osd"}
		};
		sub_box.append (menu_button);
		main_box.append (sub_box);
		revealer.child = new Adw.Bin () {
			css_classes = {"osd"},
			child = main_box
		};

		overlay.add_overlay (revealer);
		this.child = overlay;

		this.state_flags_changed.connect (on_state_flags_changed);
		update_store ();
	}

	public ControlsOverlay (Widgets.Cover cover) {
		this.overlay.child = cover;
		cover.style_changed.connect (update_style);
		update_style (cover.style, cover.orientation);
	}

	private void on_state_flags_changed () {
		bool should_reveal_child = (
			this.get_state_flags ()
			& (
				Gtk.StateFlags.PRELIGHT
				| Gtk.StateFlags.ACTIVE
				| Gtk.StateFlags.SELECTED
				| Gtk.StateFlags.FOCUSED
				| Gtk.StateFlags.FOCUS_VISIBLE
				| Gtk.StateFlags.FOCUS_WITHIN
			)
		) != 0;

		if (revealer.reveal_child != should_reveal_child)
			revealer.reveal_child = should_reveal_child;
	}

	public bool hide_overlay () {
		if (!revealer.reveal_child || menu_button.active || ((Gtk.ToggleButton) client_dropdown.get_first_child ()).active) return false;
		revealer.reveal_child = false;
		return true;
	}

	private void update_store () {
		players_store.splice (0, players_store.n_items, mpris_manager.players);
		players_store.sort ((GLib.CompareDataFunc<Mpris.Entry>) compare_players);

		client_dropdown.enable_search = players_store.n_items > 10;
		if (this.last_player == null) selection_changed (); // if always ensure player
	}

	private static int compare_players (Mpris.Entry a, Mpris.Entry b) {
		return a.client_info.identity.collate (b.client_info.identity);
	}

	private void selection_changed () {
		bool was_null = this.last_player == null;

		if (!was_null) this.last_player.terminate_player ();
		if (client_dropdown.selected == Gtk.INVALID_LIST_POSITION) {
			if (!was_null) trigger_player_changed (null);
			return;
		}

		this.last_player = (Mpris.Entry?) players_store.get_item (client_dropdown.selected);
		if (this.last_player == null) {
			if (!was_null) trigger_player_changed (null);
			return;
		}

		this.last_player.initialize_player ();
		trigger_player_changed (this.last_player);
	}

	private inline void trigger_player_changed (Mpris.Entry? new_entry) {
		player_changed (new_entry);
		update_scrobble_button ();
	}

	#if SCROBBLING
		private void update_scrobble_button () {
			if (this.last_player == null) {
				scrobble_button.sensitive = false;
				scrobble_button.enabled = false;
				return;
			}

			scrobble_button.sensitive = true;
			scrobble_button.enabled = this.last_player.parent_bus_namespace in settings.scrobbler_allowlist;
		}

		private void on_accounts_changed () {
			scrobble_button.visible = account_manager.accounts.length > 0;
		}

		private void on_scrobble_client_toggle () {
			update_scrobble_button ();

			if (scrobble_button.enabled) {
				settings.remove_from_allowlist (this.last_player.parent_bus_namespace);
			} else {
				settings.add_to_allowlist (this.last_player.parent_bus_namespace);
			}
			scrobble_button.enabled = !scrobble_button.enabled;
		}
	#endif
}
