public class Turntable.Widgets.Tonearm : Adw.Bin {
	Adw.TimedAnimation animation;

	const int ARM_WIDTH = 10;
	const int CIRCLE_SIZE = 36;
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

	~Tonearm () {
		debug ("Destroying");
	}

	// fix leak
	// callback animation target seems to leak
	public double animation_cb {
		set {
			this.queue_draw ();
		}
	}

	private int arm_height = 150;
	private float rotation_start = 2.5f;
	private float rotation_end = 15.5f;

	private Views.Window.Size _size = REGULAR;
	public Views.Window.Size size {
		get { return _size; }
		set {
			_size = value;
			if (enabled) update_cover_style ();
		}
	}

	private bool tonearm_visible = false;
	private bool _enabled = false;
	public bool enabled {
		get { return _enabled; }
		set {
			if (_enabled != value) {
				_enabled = value;
				if (value) {
					update_size ();
					update_cover_style ();
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
			if (this.enabled && this.tonearm_visible) {
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

	private void update_cover_style () {
		bool is_turntable = settings.cover_style == Widgets.Cover.Style.TURNTABLE.to_string ();
		switch (this.size) {
			case SMALL:
				this.tonearm_visible = false;
				break;
			case BIG:
				this.tonearm_visible = is_turntable;
				arm_height = 192;
				rotation_start = 1.5f;
				rotation_end = 14.6f;
				break;
			default:
				this.tonearm_visible = is_turntable;
				arm_height = 150;
				rotation_start = 2.5f;
				rotation_end = 15.5f;
				break;
		}

		this.queue_draw ();
	}

	construct {
		this.size = Views.Window.Size.REGULAR;

		animation = new Adw.TimedAnimation (this, 0.0, 1.0, PROGRESS_UPDATE_TIME, new Adw.PropertyAnimationTarget (this, "animation-cb")) {
			easing = Adw.Easing.LINEAR
		};

		settings.notify["cover-size"].connect (update_size);
		settings.notify["cover-style"].connect (update_cover_style);
		if (this.enabled) update_size ();
	}

	private void update_size () {
		this.size = Views.Window.Size.from_string (settings.cover_size);
	}

	public override void snapshot (Gtk.Snapshot snapshot) {
		base.snapshot (snapshot);
		if (!this.enabled || !this.tonearm_visible) return;

		snapshot.translate ({ this.get_width () - 8 , 0 });
		snapshot.save ();
		snapshot.translate ({-CIRCLE_SIZE / 2, 0});

		var rounded_rect = Gsk.RoundedRect ().init_from_rect ({
			{ -ARM_WIDTH / 2, 0 },
			{ ARM_WIDTH, arm_height + CIRCLE_SIZE / 2 }
		}, 3f);

		int y = CIRCLE_SIZE / 2 + 8;
		var transform = new Gsk.Transform ();
		transform = transform.translate ({ 0, y });
		transform = transform.rotate ((float) (rotation_start + (rotation_end - rotation_start) * animation.value));
		transform = transform.translate ({ 0, -y });
		snapshot.transform (transform);

		snapshot.push_rounded_clip (rounded_rect);
		snapshot.append_linear_gradient (
			{
				{-ARM_WIDTH / 2, 0},
				{ ARM_WIDTH, arm_height + CIRCLE_SIZE / 2 }
			},
			{ -ARM_WIDTH / 2, 0 },
			{ ARM_WIDTH, 0 },
			ARM_GRADIENT
		);
		snapshot.pop ();

		Graphene.Rect rect = {
			{- (ARM_WIDTH + 2) / 2, arm_height + CIRCLE_SIZE / 2 - 24},
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
		snapshot.translate ({-CIRCLE_SIZE, 8 });

		rounded_rect = Gsk.RoundedRect ().init_from_rect ({{0, 0}, {CIRCLE_SIZE, CIRCLE_SIZE + 2}}, 9999f);
		snapshot.push_rounded_clip (rounded_rect);
		snapshot.append_color ({0.7529f, 0.7490f, 0.7373f, 1}, {{0, 0}, {CIRCLE_SIZE, CIRCLE_SIZE + 2}});
		snapshot.pop ();

		Graphene.Rect circle_rect = {{0, 0}, {CIRCLE_SIZE, CIRCLE_SIZE}};
		rounded_rect = Gsk.RoundedRect ().init_from_rect (circle_rect, 9999f);
		snapshot.push_rounded_clip (rounded_rect);
		snapshot.append_linear_gradient (
			circle_rect,
			{ 0, 0 },
			{ 0, CIRCLE_SIZE },
			CIRCLE_GRADIENT
		);
		snapshot.pop ();
	}
}
