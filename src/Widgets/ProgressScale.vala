public class Turntable.Widgets.ProgressScale : Adw.BreakpointBin {
	~ProgressScale () {
		debug ("Destroying");
		if (changed_timeout > 0) GLib.Source.remove (changed_timeout);
	}
	public signal void progress_changed (double new_progress);

	public enum Style {
		NONE,
		KNOB,
		OVERLAY;

		public string to_string () {
			switch (this) {
				case OVERLAY: return "overlay";
				case KNOB: return "knob";
				default: return "none";
			}
		}

		public static Style from_string (string string_style) {
			switch (string_style.down ()) {
				case "overlay": return OVERLAY;
				case "knob": return KNOB;
				default: return NONE;
			}
		}
	}

	private Style _style = NONE;
	public Style style {
		get { return _style; }
		set {
			_style = value;
			switch (value) {
				case NONE:
					this.visible = false;
					return;
				case KNOB:
					this.css_classes = {"progressscale" };
					this.visible = true;
					return;
				case OVERLAY:
					this.css_classes = {"progressscale", "overlay"};
					this.visible = true;
					return;
				default:
					assert_not_reached ();
			}
		}
	}

	private double _progress = 0;
	public double progress {
		get { return scale.get_value (); }
		set {
			double new_val = value.clamp (0.0, 1.0);
			if (_progress != new_val) {
				_progress = new_val;
				scale.set_value (new_val);
			}
		}
	}

	public int64 playtime {
		set {
			playtime_label.label = playtime_label.label = micro_to_mmss (value);
		}
	}

	public int64 length {
		set {
			length_label.label = micro_to_mmss (value);
		}
	}

	private string micro_to_mmss (int64 value) {
		int64 total_seconds = value / 1000000;
		return "%02d:%02d".printf ((int) (total_seconds / 60), (int) (total_seconds % 60));
	}

	bool _newline = false;
	public bool newline {
		get { return _newline; }
		set {
			if (_newline == value) return;
			_newline = value;

			Gtk.GridLayout layout_manager = (Gtk.GridLayout) grid.get_layout_manager ();
			Gtk.GridLayoutChild playtime_label_layout_child = (Gtk.GridLayoutChild) layout_manager.get_layout_child (playtime_label);
			Gtk.GridLayoutChild scale_layout_child = (Gtk.GridLayoutChild) layout_manager.get_layout_child (scale);
			Gtk.GridLayoutChild length_label_layout_child = (Gtk.GridLayoutChild) layout_manager.get_layout_child (length_label);

			if (value) {
				playtime_label_layout_child.column = 0;
				playtime_label_layout_child.row = 1;
				playtime_label_layout_child.column_span = 1;
				playtime_label_layout_child.row_span = 1;

				scale_layout_child.column = 0;
				scale_layout_child.row = 0;
				scale_layout_child.column_span = 3;
				scale_layout_child.row_span = 1;

				length_label_layout_child.column = 2;
				length_label_layout_child.row = 1;
				length_label_layout_child.column_span = 1;
				length_label_layout_child.row_span = 1;
			} else {
				playtime_label_layout_child.column = 0;
				playtime_label_layout_child.row = 0;
				playtime_label_layout_child.column_span = 1;
				playtime_label_layout_child.row_span = 1;

				scale_layout_child.column = 1;
				scale_layout_child.row = 0;
				scale_layout_child.column_span = 1;
				scale_layout_child.row_span = 1;

				length_label_layout_child.column = 2;
				length_label_layout_child.row = 0;
				length_label_layout_child.column_span = 1;
				length_label_layout_child.row_span = 1;
			}
		}
	}

	Gtk.Grid grid;
	Gtk.Label playtime_label;
	Gtk.Label length_label;
	Gtk.Scale scale;
	construct {
		this.width_request = 156;
		this.height_request = 51;
		grid = new Gtk.Grid () {
			valign = CENTER
		};

		playtime_label = new Gtk.Label ("0:00") {
			focusable = false,
			halign = START,
			valign = CENTER,
			css_classes = { "dim-label", "numeric", "small-text" }
		};
		grid.attach (playtime_label, 0, 0);

		scale = new Gtk.Scale.with_range (HORIZONTAL, 0, 1, 0.01) {
			hexpand = true,
			valign = CENTER,
			focusable = true,
			draw_value = false
		};
		scale.change_value.connect (on_value_changed);
		grid.attach (scale, 1, 0);

		length_label = new Gtk.Label ("0:00") {
			focusable = false,
			halign = END,
			valign = CENTER,
			css_classes = { "dim-label", "numeric", "small-text" }
		};
		grid.attach (length_label, 2, 0);
		this.child = grid;

		var bp = new Adw.Breakpoint (
			new Adw.BreakpointCondition.length (
				Adw.BreakpointConditionLengthType.MAX_WIDTH,
				200,
				Adw.LengthUnit.PX
			)
		);
		bp.add_setter (this, "newline", true);
		this.add_breakpoint (bp);
	}

	uint changed_timeout = 0;
	double final_new_value = 0;
	private bool on_value_changed (Gtk.ScrollType scroll, double new_value) {
		final_new_value = new_value;
		if (changed_timeout > 0) GLib.Source.remove (changed_timeout);
		changed_timeout = GLib.Timeout.add (PROGRESS_UPDATE_TIME, on_position_changed, Priority.LOW);
		return true;
	}

	private bool on_position_changed () {
		if (changed_timeout == 0) return GLib.Source.REMOVE;

		changed_timeout = 0;
		progress_changed (final_new_value);
		return GLib.Source.REMOVE;
	}
}
