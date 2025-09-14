// Ported from Amberol https://gitlab.gnome.org/World/amberol/-/blob/36872777b77b0bdae8811867d3acce3185bef8fd/src/marquee.rs
public class Turntable.Widgets.Marquee : Gtk.Widget {
	const float SPACING = 32f;
	const uint ANIMATION_DURATION = 250;

	Adw.TimedAnimation animation;
	Gtk.Label label;
	bool label_fits = false;
	Gdk.RGBA black = Gdk.RGBA () { red = 0f, green = 0f, blue = 0f, alpha = 1f };
	Gdk.RGBA transparent = Gdk.RGBA () { red = 0f, green = 0f, blue = 0f, alpha = 0f };

	private float _rotation_progress = 0.0f;
	public float rotation_progress {
		get { return _rotation_progress; }
		set {
			float new_val = rem_euclid (value, 1.0f);
			if (_rotation_progress != new_val) {
				_rotation_progress = new_val;
				this.queue_draw ();
			}
		}
	}

	private float _width_chars = 1f;
	public float width_chars {
		get { return _width_chars; }
		set {
			if (_width_chars != value) {
				_width_chars = value;
				this.queue_resize ();
			}
		}
	}

	public int32 width_pixels {
		get {
			Pango.FontMetrics metrics = this.get_pango_context ().get_metrics (null, null);
			int char_width = int.max (
				metrics.get_approximate_char_width (),
				metrics.get_approximate_digit_width ()
			);

			return (int32) (char_width * this.width_chars / Pango.SCALE);
		}
	}

	public float xalign {
		get { return label.xalign; }
		set { label.xalign = value; }
	}

	private bool _force_width = false;
	public bool force_width {
		get { return _force_width; }
		set {
			if (_force_width != value) {
				_force_width = value;
				this.queue_resize ();
			}
		}
	}

	private float rem_euclid (float value, float mod) {
		float r = value % mod;
		return (r < 0.0) ? r + mod : r;
	}

	static construct {
		set_css_name ("label");
		set_accessible_role (Gtk.AccessibleRole.LABEL);
	}

	uint animation_end_id = 0;
	private void on_animation_end () {
		animation_end_id = GLib.Timeout.add_once (1500, start_animation_once);
	}

	private void start_animation_once () {
		if (animation_end_id == 0) return;
		animation_end_id = 0;
		start_animation ();
	}

	private void start_animation () {
		if (label_fits || animation.state == Adw.AnimationState.PLAYING) return;
		animation.play ();
	}

	private void stop_animation () {
		animation.pause ();
	}

	private string _content = "";
	public string content {
		get { return _content; }
		set {
			if (_content != value) {
				_content = value == null ? "" : value;
				label.label = _content;
				if (animation.state == Adw.AnimationState.PLAYING) animation.skip ();
			}
		}
	}

	construct {
		label = new Gtk.Label ("");
		label.set_parent (this);

		animation = new Adw.TimedAnimation (this, 0.0, 1.0, ANIMATION_DURATION, new Adw.PropertyAnimationTarget (this, "rotation-progress")) {
			easing = Adw.Easing.EASE_IN_OUT_CUBIC
		};
		animation.done.connect (on_animation_end);
	}

	~Marquee () {
		debug ("Destroying");
		label.unparent ();
		if (animation_end_id != 0) GLib.Source.remove (animation_end_id);
		animation_end_id = 0;
	}

	public override void measure (
		Gtk.Orientation orientation,
		int for_size,
		out int minimum,
		out int natural,
		out int minimum_baseline,
		out int natural_baseline
	) {
		label.measure (orientation, for_size, out minimum, out natural, out minimum_baseline, out natural_baseline);

		if (orientation == Gtk.Orientation.HORIZONTAL) {
			minimum = 0;
			natural = this.force_width ? 308 : int.min (308, natural);
			minimum_baseline = -1;
			natural_baseline = -1;
		}
	}

	public override void size_allocate (int width, int height, int baseline) {
		Gtk.Requisition natural;
		label.get_preferred_size (null, out natural);

		int child_width = int.max (natural.width, width);
		label.allocate (child_width, natural.height, -1, null);
		animation.duration = (uint) (int.max (child_width, 20) * 30);

		if (label.get_width () > width) {
			label_fits = false;
			start_animation ();
		} else {
			label_fits = true;
			stop_animation ();
		}
	}

	public override void snapshot (Gtk.Snapshot snapshot) {
		if (label_fits) {
			base.snapshot (snapshot);
			return;
		}

		int width = this.get_width ();
		Gtk.Snapshot parent_snapshot = new Gtk.Snapshot ();
		base.snapshot (parent_snapshot);

		Gsk.RenderNode? node = parent_snapshot.to_node ();
		if (node == null) {
			base.snapshot (snapshot);
			return;
		}

		Graphene.Rect node_bounds = node.get_bounds ();
		float label_width = node_bounds.size.width;
		float label_height = node_bounds.size.height;
		float gradient_width = SPACING * 0.5f;

		Graphene.Rect bounds = Graphene.Rect () {
			origin = Graphene.Point () {
				x = -gradient_width,
				y = node_bounds.origin.y
			},
			size = Graphene.Size () {
				width = width + gradient_width,
				height = label_height
			}
		};

		snapshot.push_mask (Gsk.MaskMode.INVERTED_ALPHA);

		Graphene.Point l_start = bounds.get_top_left ();
		Graphene.Point l_end = bounds.get_top_left ();
		l_end.x += gradient_width;
		snapshot.append_linear_gradient (bounds, l_start, l_end, {
			Gsk.ColorStop () { offset = 0.0f, color = black },
			Gsk.ColorStop () { offset = 1.0f, color = transparent }
		});

		Graphene.Point r_start = bounds.get_top_right ();
		Graphene.Point r_end = bounds.get_top_right ();
		r_start.x -= gradient_width;
		snapshot.append_linear_gradient (bounds, r_start, r_end, {
			Gsk.ColorStop () { offset = 0.0f, color = transparent },
			Gsk.ColorStop () { offset = 1.0f, color = black }
		});

		snapshot.pop ();
		snapshot.push_clip (bounds);

		snapshot.translate (Graphene.Point () {
			x = - (label_width + SPACING) * this.rotation_progress,
			y = 0f
		});

		snapshot.append_node (node);
		snapshot.translate (Graphene.Point () {
			x = label_width + SPACING,
			y = 0f
		});
		snapshot.append_node (node);

		snapshot.pop ();
		snapshot.pop ();
	}
}
