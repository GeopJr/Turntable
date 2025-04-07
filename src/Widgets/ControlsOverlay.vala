public class Turntable.Widgets.ControlsOverlay : Adw.Bin {
	public signal void player_changed (Mpris.Entry? new_player);
	public Mpris.Entry? last_player { get; set; default = null; }

	private void update_style (Widgets.Cover.Style style, Gtk.Orientation orientation) {
		switch (style) {
			case CARD:
				this.css_classes = { "card", "card-like" };
				break;
			case TURNTABLE:
				this.css_classes = { "card", "circular-art", "card-like" };
				break;
			case SHADOW:
				this.css_classes = {};
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

	Gtk.Overlay overlay;
	Gtk.Revealer revealer;
	GLib.ListStore players_store;
	Gtk.DropDown client_dropdown;
	construct {
		this.overflow = Gtk.Overflow.HIDDEN;
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
			//  enable_search = false, // maybe enable if there are more than 10 items
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
		main_section_model.append (_("Clients"), "app.refresh");
		main_section_model.append (_("Scrobbling"), "app.refresh");
		menu_model.append_section (null, main_section_model);

		var style_section_model = new GLib.Menu ();
		var component_submenu_model = new GLib.Menu ();
		component_submenu_model.append (_("Background Progress"), "win.component-progressbin");
		component_submenu_model.append (_("Extract Cover Colors"), "win.component-extract-colors");
		style_section_model.append_submenu (_("Components"), component_submenu_model);

		var cover_style_submenu_model = new GLib.Menu ();
		cover_style_submenu_model.append (_("Card"), "win.cover-style('card')");
		cover_style_submenu_model.append (_("Turntable"), "win.cover-style('turntable')");
		cover_style_submenu_model.append (_("Shadow"), "win.cover-style('shadow')");
		style_section_model.append_submenu (_("Cover Style"), cover_style_submenu_model);

		var orientation_submenu_model = new GLib.Menu ();
		orientation_submenu_model.append (_("Horizontal"), "win.toggle-orientation(true)");
		orientation_submenu_model.append (_("Vertical"), "win.toggle-orientation(false)");
		style_section_model.append_submenu (_("Orientation"), orientation_submenu_model);

		var window_style_submenu_model = new GLib.Menu ();
		window_style_submenu_model.append (_("Window"), "win.window-style('window')");
		window_style_submenu_model.append (_("OSD"), "win.window-style('osd')");
		window_style_submenu_model.append (_("Transparent"), "win.window-style('transparent')");
		style_section_model.append_submenu (_("Window Style"), window_style_submenu_model);
		menu_model.append_section (null, style_section_model);

		var misc_section_model = new GLib.Menu ();
		misc_section_model = new GLib.Menu ();
		misc_section_model.append (_("Keyboard Shortcuts"), "win.show-help-overlay");
		misc_section_model.append (_("About %s").printf (Build.NAME), "app.about");
		misc_section_model.append (_("Quit"), "app.quit");
		menu_model.append_section (null, misc_section_model);

		sub_box.append (new Gtk.MenuButton () {
			icon_name = "open-menu-symbolic",
			primary = true,
			menu_model = menu_model,
			css_classes = {"circular", "osd"}
		});
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

	private void update_store () {
		players_store.splice (0, players_store.n_items, mpris_manager.players);
		players_store.sort ((GLib.CompareDataFunc<Mpris.Entry>) compare_players);

		if (this.last_player == null) selection_changed (); // if always ensure player
	}

	public override bool contains (double x, double y) {
		return this.child.contains (x, y);
	}

	private static int compare_players (Mpris.Entry a, Mpris.Entry b) {
		return a.client_info.identity.collate (b.client_info.identity);
	}

	private void selection_changed () {
		bool was_null = this.last_player == null;

		if (!was_null) this.last_player.terminate_player ();
		if (client_dropdown.selected == Gtk.INVALID_LIST_POSITION) {
			if (!was_null) player_changed (null);
			return;
		}

		this.last_player = (Mpris.Entry?) players_store.get_item (client_dropdown.selected);
		if (this.last_player == null) {
			if (!was_null) player_changed (null);
			return;
		}

		this.last_player.initialize_player ();
		player_changed (this.last_player);
	}
}
