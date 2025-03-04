public class Turntable.Widgets.ProgressBin : Adw.Bin {
	Gdk.RGBA color;
	Gdk.RGBA accent_color;
	Gdk.RGBA? custom_color = null;
	Adw.TimedAnimation animation;

	private Widgets.Cover.ExtractedColors? _extracted_colors = null;
	public Widgets.Cover.ExtractedColors? extracted_colors {
		get { return _extracted_colors; }
		set {
			_extracted_colors = value;
			update_color ();
		}
	}

	private void update_color () {
		Gdk.RGBA new_color = accent_color;

		if (this.extracted_colors != null) {
			new_color = Adw.StyleManager.get_default ().dark
				? extracted_colors.dark
				: extracted_colors.light;
			new_color.alpha = 0.5f;
		}

		if (new_color != color) {
			color = new_color;
			if (this.progress != 0) this.queue_draw ();
		}
	}

	private double _progress = 0;
	public double progress {
		get { return _progress; }
		set {
			double new_val = value.clamp (0.0, 1.0);
			if (_progress != new_val) {
				animation.value_from = _progress;
				animation.value_to = new_val;

				_progress = new_val;
				animation.play ();
			}
		}
	}

	private int32 _offset = 0;
	public int32 offset {
		get { return _offset; }
		set {
			if (_offset != value && value >= 0) {
				_offset = value;
				this.queue_draw ();
			}
		}
	}

	private Gtk.Orientation _orientation = Gtk.Orientation.HORIZONTAL;
	public Gtk.Orientation orientation {
		get { return _orientation; }
		set {
			if (_orientation != value) {
				_orientation = value;
				this.queue_draw ();
			}
		}
	}

	private void update_accent_color () {
		accent_color = Adw.StyleManager.get_default ().get_accent_color_rgba ();
		accent_color.alpha = 0.5f;
		update_color ();
	}

	private void animation_target_cb (double value) {
		this.queue_draw ();
	}

	construct {
		var default_sm = Adw.StyleManager.get_default ();
		if (default_sm.system_supports_accent_colors) {
			default_sm.notify["accent-color-rgba"].connect (update_accent_color);
			default_sm.notify["dark"].connect (update_color);
			update_accent_color ();
		} else {
			accent_color = {
				120 / 255.0f,
				174 / 255.0f,
				237 / 255.0f,
				0.5f
			};
		}

		var target = new Adw.CallbackAnimationTarget (animation_target_cb);
		animation = new Adw.TimedAnimation (this, 0.0, 1.0, PROGRESS_UPDATE_TIME, target) {
			easing = Adw.Easing.LINEAR
		};
	}

	public override void snapshot (Gtk.Snapshot snapshot) {
		if (this.animation.value > 0) {
			switch (this.orientation) {
				case Gtk.Orientation.VERTICAL:
					snapshot.append_color (
						this.color,
						Graphene.Rect () {
							origin = Graphene.Point () {
								x = 0,
								y = 0
							},
							size = Graphene.Size () {
								height = (float) ((this.get_height () - this.offset) * this.animation.value) + this.offset,
								width = this.get_width ()
							}
						}
					);
					break;
				default:
					snapshot.append_color (
						this.color,
						Graphene.Rect () {
							origin = Graphene.Point () {
								x = 0,
								y = 0
							},
							size = Graphene.Size () {
								height = this.get_height (),
								width = (float) ((this.get_width () - this.offset) * this.animation.value) + this.offset
							}
						}
					);
					break;
			}
		}

		base.snapshot (snapshot);
	}
}
