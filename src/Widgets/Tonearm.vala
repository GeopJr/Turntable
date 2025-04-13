public class Turntable.Widgets.Tonearm : Gtk.Widget {
	Adw.TimedAnimation animation;

	const int ARM_WIDTH = 12;
	const Gsk.ColorStop[] ARM_GRADIENT = {
		{0, {0.6039f, 0.6f, 0.5882f, 1}},
		{0.5f, {0.8706f, 0.8667f, 0.8549f, 1}},
		{1, {0.4667f, 0.4627f, 0.4824f, 1}},
	};
	const Gsk.ColorStop[] NEEDLE_GRADIENT = {
		{0, {0.3686f, 0.3608f, 0.3922f, 1}},
		{0.5f, {0.6039f, 0.6f, 0.5882f, 1}},
		{1, {0.2392f, 0.2196f, 0.2745f, 1}},
	};
	const Gsk.ColorStop[] CIRCLE_GRADIENT = {
		{0, {0.7529f, 0.7490f, 0.7373f, 0.3f}},
		{1, {0.8706f, 0.8667f, 0.8549f, 0.3f}},
	};

	private void animation_target_cb (double value) {
		this.queue_draw ();
	}

	private int circle_size = 36;
	private int arm_height = 150;
	private float rotation_start = 2.5f;
	private float rotation_end = 17.2f;

	private Views.Window.Size _size = REGULAR;
	public Views.Window.Size size {
		get { return _size; }
		set {
			_size = value;
			if (enabled) update_rotation ();
		}
	}

	private bool _enabled = false;
	public bool enabled {
		get { return _enabled; }
		set {
			if (_enabled != value) {
				_enabled = value;
				if (value) {
					update_size ();
					update_rotation ();
				} else {
					this.queue_draw ();
				}
			}
		}
	}
	private double _progress = 0;
	public double progress {
		get { return _progress; }
		set {
			if (this.enabled) {
				double new_val = value.clamp (0.0, 1.0);
				if (_progress != new_val) {
					animation.value_from = animation.state == Adw.AnimationState.PLAYING ? animation.value : _progress;
					animation.value_to = new_val;

					_progress = new_val;
					animation.play ();
				}
			}
		}
	}

	private void update_rotation () {
		switch (this.size) {
			case SMALL:
				this.visible = false;
				break;
			case BIG:
				this.visible = true;
				circle_size = 36;
				if (is_rtl) {
					this.margin_end = 14;
				} else {
					this.margin_start = 272;
				}
				this.margin_top = 12;
				arm_height = 170;
				rotation_start = 0;
				rotation_end = 14.9f;
				break;
			default:
				this.visible = true;
				circle_size = 36;
				if (is_rtl) {
					this.margin_end = 10;
				} else {
					this.margin_start = 214;
				}
				this.margin_top = 12;
				arm_height = 150;
				rotation_start = 8.5f;
				rotation_end = 22.2f;
				break;
		}

		this.queue_draw ();
	}

	static construct {
		set_accessible_role (Gtk.AccessibleRole.NONE); // it's probably better if it doesn't get announced
	}

	construct {
		this.size = Views.Window.Size.REGULAR;
		this.halign = is_rtl ? Gtk.Align.END : Gtk.Align.START;
		this.focusable =
		this.can_target =
		this.focus_on_click =
		this.can_focus = false;
		this.set_direction (Gtk.TextDirection.LTR);

		var target = new Adw.CallbackAnimationTarget (animation_target_cb);
		animation = new Adw.TimedAnimation (this, 0.0, 1.0, PROGRESS_UPDATE_TIME, target) {
			easing = Adw.Easing.LINEAR
		};

		settings.notify["cover-size"].connect (update_size);
		if (this.enabled) update_size ();
	}

	private void update_size () {
		this.size = Views.Window.Size.from_string (settings.cover_size);
	}

	public override void snapshot (Gtk.Snapshot snapshot) {
		base.snapshot (snapshot);
		if (!this.enabled) return;

		snapshot.save ();
		snapshot.translate ({-circle_size / 2, circle_size / 2});

		var rounded_rect = Gsk.RoundedRect ().init_from_rect ({
			{ -ARM_WIDTH / 2, 0 },
			{ ARM_WIDTH, arm_height }
		}, 3f);
		snapshot.rotate ((float) (rotation_start + (rotation_end - rotation_start) * animation.value));
		snapshot.push_rounded_clip (rounded_rect);
		snapshot.append_linear_gradient (
			{
				{-ARM_WIDTH / 2, 0},
				{ ARM_WIDTH, arm_height }
			},
			{ -ARM_WIDTH / 2, 0 },
			{ ARM_WIDTH, 0 },
			ARM_GRADIENT
		);
		snapshot.pop ();
		Graphene.Rect rect = {
			{- (ARM_WIDTH + 2) / 2, arm_height - 6},
			{ (ARM_WIDTH + 2), 20 }
		};
		rounded_rect = Gsk.RoundedRect ().init_from_rect (rect, 3f);
		snapshot.push_rounded_clip (rounded_rect);
		snapshot.append_linear_gradient (
			rect,
			{ rect.origin.x, 0 },
			{ rect.size.width, 0 },
			NEEDLE_GRADIENT
		);
		snapshot.pop ();
		snapshot.restore ();
		snapshot.translate ({-circle_size, 0});

		rounded_rect = Gsk.RoundedRect ().init_from_rect ({{0, 0}, {circle_size, circle_size + 2}}, 9999f);
		snapshot.push_rounded_clip (rounded_rect);
		snapshot.append_color ({0.7529f, 0.7490f, 0.7373f, 1}, {{0, 0}, {circle_size, circle_size + 2}});
		snapshot.pop ();

		Graphene.Rect circle_rect = {{0, 0}, {circle_size, circle_size}};
		rounded_rect = Gsk.RoundedRect ().init_from_rect (circle_rect, 9999f);
		snapshot.push_rounded_clip (rounded_rect);
		snapshot.append_linear_gradient (
			circle_rect,
			{ 0, 0 },
			{ 0, circle_size },
			CIRCLE_GRADIENT
		);
		snapshot.pop ();

	}
}
