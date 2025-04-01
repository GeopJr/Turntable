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
		overlay = new Gtk.Overlay ();
		revealer = new Gtk.Revealer () {
			reveal_child = false,
			transition_duration = 250,
			transition_type = Gtk.RevealerTransitionType.CROSSFADE
		};

		players_store = new GLib.ListStore (typeof (Mpris.Entry));
		mpris_manager.players_changed.connect (update_store);

		client_dropdown = new Gtk.DropDown (players_store, new Gtk.PropertyExpression (typeof (Mpris.Entry), null, "client-info-name")) {
			//  enable_search = false,
			valign = Gtk.Align.CENTER,
			halign = Gtk.Align.CENTER,
			vexpand = true,
			hexpand = true,
			factory = new Gtk.BuilderListItemFactory.from_resource (null, @"$(Build.RESOURCES)gtk/dropdown/client_display.ui"),
			list_factory = new Gtk.BuilderListItemFactory.from_resource (null, @"$(Build.RESOURCES)gtk/dropdown/client.ui"),
			tooltip_text = _("Select Player"),
			css_classes = { "client-chooser" },
			margin_start = 8,
			margin_end = 8
		};
		client_dropdown.notify["selected"].connect (selection_changed);

		var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
			css_classes = {"osd"},
			vexpand = true,
			hexpand = true
		};
		main_box.append (client_dropdown);
		revealer.child = main_box;

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
