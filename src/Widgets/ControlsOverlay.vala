public class Turntable.Widgets.ControlsOverlay : Adw.Bin {
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
	construct {
		this.overflow = Gtk.Overflow.HIDDEN;
		overlay = new Gtk.Overlay ();
		revealer = new Gtk.Revealer () {
			reveal_child = false,
			transition_duration = 250,
			transition_type = Gtk.RevealerTransitionType.CROSSFADE
		};

		var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
			css_classes = {"osd"}
		};
		box.append (new Gtk.Label ("TODO"));
		revealer.child = box;

		overlay.add_overlay (revealer);
		this.child = overlay;

		this.state_flags_changed.connect (on_state_flags_changed);
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
}
