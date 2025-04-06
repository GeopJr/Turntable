public class Turntable.Widgets.Cover : Gtk.Widget {
	public const float FADE_WIDTH = 64f;
	const Gsk.ColorStop[] GRADIENT = {
		{ 0f, { 0, 0, 0, 1f } },
		{ 1f, { 0, 0, 0, 0f } },
	};
	public signal void style_changed (Style style, Gtk.Orientation orientation);

	Gtk.IconPaintable fallback_icon;
	Gdk.Texture? cover = null;
	Adw.TimedAnimation animation;
	Gsk.RoundedRect? record_center = null;
	Graphene.Rect record_center_inner = Graphene.Rect () {
		origin = Graphene.Point () {
			x = 0,
			y = 0
		},
		size = Graphene.Size () {
			width = 64,
			height = 64
		}
	};

	public enum Style {
		CARD,
		TURNTABLE,
		SHADOW;

		public string to_string () {
			switch (this) {
				case TURNTABLE: return "turntable";
				case SHADOW: return "shadow";
				default: return "card";
			}
		}

		public static Style from_string (string string_style) {
			switch (string_style) {
				case "turntable": return TURNTABLE;
				case "shadow": return SHADOW;
				default: return CARD;
			}
		}
	}

	private Style _style = Style.CARD;
	public Style style {
		get { return _style; }
		set {
			if (_style != value) {
				_style = value;
				this.turntable = value == Style.TURNTABLE;
				this.style_changed (value, this.orientation);
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
				this.style_changed (this.style, value);
				this.queue_draw ();
			}
		}
	}

	private bool _turntable = false;
	private bool turntable {
		get { return _turntable; }
		set {
			if (_turntable != value) {
				_turntable = value;
				if (value) {
					if (record_center == null) {
						record_center = Gsk.RoundedRect ().init_from_rect (
							record_center_inner,
							9999f
						);
					}

					animation.play ();
				} else {
					animation.pause ();
					this.queue_draw ();
				}

				this.notify_property ("turntable-playing");
			}
		}
	}

	public bool turntable_playing {
		get { return this.turntable && animation.state == Adw.AnimationState.PLAYING; }
		set {
			if (this.turntable) {
				if (value) {
					if (animation.state == Adw.AnimationState.PAUSED) {
						animation.resume ();
					} else {
						animation.play ();
					}
				} else {
					animation.pause ();
				}
			}
		}
	}


	public Utils.Color.ExtractedColors? extracted_colors { get; set; default = null; }

	private class CoverLoader : GLib.Object {
		private string file_path;
		private Cancellable cancellable;
		private Gdk.Texture? texture = null;
		private Utils.Color.ExtractedColors? extracted_colors = null;
		public signal void done (Gdk.Texture texture);
		public signal void done_completely (Utils.Color.ExtractedColors? extracted_colors);

		~CoverLoader () {
			this.texture = null;
		}

		public CoverLoader (string file_path) {
			this.file_path = file_path;
		}

		public void fetch () {
			string clean_path = this.file_path.has_prefix ("file://")
				? this.file_path.splice (0, 7)
				: this.file_path;
			//  var t_texture = Gdk.Texture.from_filename (clean_path);
			//  if (cancellable.is_cancelled ()) return;

			//  this.texture = t_texture;
			//  GLib.Idle.add_once (done_idle);

			var pixbuf = new Gdk.Pixbuf.from_file (clean_path);
			if (cancellable.is_cancelled ()) return;

			var t_texture = Gdk.Texture.for_pixbuf (pixbuf);
			if (cancellable.is_cancelled ()) return;

			this.texture = t_texture;
			GLib.Idle.add_once (done_idle);

			var avg = Utils.Color.get_average_color (pixbuf);
			if (cancellable.is_cancelled ()) return;

			this.extracted_colors = Utils.Color.get_contrasting_colors (avg);
			GLib.Idle.add_once (done_completely_idle);
		}

		private void done_idle () {
			done (this.texture);
		}

		private void done_completely_idle () {
			this.texture = null;
			done_completely (this.extracted_colors);
			this.extracted_colors = null;
		}

		public void cancel () {
			cancellable.cancel ();
		}
	}

	private CoverLoader? working_loader = null;
	public string? file_path {
		set {
			if (working_loader != null) {
				working_loader.cancel ();
				working_loader = null;
			}

			if (value == null) {
				cover = null;
				this.extracted_colors = null;
				this.queue_draw ();
			} else {
				try {
					working_loader = new CoverLoader (value);
					working_loader.done.connect (queue_draw_cb);
					working_loader.done_completely.connect (done_completely_cb);
					new GLib.Thread<void>.try (@"CoverLoader $value", working_loader.fetch);
				} catch {
					if (working_loader != null) {
						working_loader.cancel ();
						working_loader = null;
					}

					cover = null;
					this.extracted_colors = null;
					this.queue_draw ();
				}
			}
		}
	}

	private void queue_draw_cb (Gdk.Texture? texture) {
		cover = texture;
		this.queue_draw ();
	}

	private void done_completely_cb (Utils.Color.ExtractedColors? extracted_colors) {
		working_loader = null;
		this.extracted_colors = extracted_colors;
	}

	private int32 _size = 192;
	public int32 size {
		get {
			return _size;
		}

		set {
			if (_size != value) {
				_size = value;
				this.queue_resize ();
			}
		}
	}

	private bool _fit_cover = false;
	public bool fit_cover {
		get {
			return _fit_cover;
		}

		set {
			if (_fit_cover != value) {
				_fit_cover = value;
				this.queue_draw ();
			}
		}
	}

	private Gsk.ScalingFilter _scaling_filter = Gsk.ScalingFilter.LINEAR;
	public Gsk.ScalingFilter scaling_filter {
		get {
			return _scaling_filter;
		}

		set {
			if (_scaling_filter != value) {
				_scaling_filter = value;
				this.queue_draw ();
			}
		}
	}

	static construct {
		set_css_name ("picture");
		set_accessible_role (Gtk.AccessibleRole.IMG);
	}

	private void animation_target_cb (double value) {
		this.queue_draw ();
	}

	construct {
		this.overflow = Gtk.Overflow.HIDDEN;
		this.notify["scale-factor"].connect (this.queue_draw);

		var target = new Adw.CallbackAnimationTarget (animation_target_cb);
		animation = new Adw.TimedAnimation (this, 0.0, 1.0, 5000, target) {
			easing = Adw.Easing.LINEAR,
			repeat_count = 0
		};

		fallback_icon = (Gtk.IconTheme.get_for_display (Gdk.Display.get_default ())).lookup_icon (
			"music-note-outline-symbolic",
			null,
			48,
			this.scale_factor,
			Gtk.TextDirection.NONE,
			Gtk.IconLookupFlags.PRELOAD
		);
	}

	public override Gtk.SizeRequestMode get_request_mode () {
		return Gtk.SizeRequestMode.CONSTANT_SIZE;
	}

	public override void measure (
		Gtk.Orientation orientation,
		int for_size,
		out int minimum,
		out int natural,
		out int minimum_baseline,
		out int natural_baseline
	) {
		minimum = this.size;
		natural = this.size;
		minimum_baseline = -1;
		natural_baseline = -1;
	}

	public override void snapshot (Gtk.Snapshot snapshot) {
		float width = this.get_width () * this.scale_factor;
		float height = this.get_height () * this.scale_factor;
		float ratio = cover == null ? 1f : (float) cover.get_intrinsic_aspect_ratio ();
		float w = 0;
		float h = 0;

		if (ratio > 1) {
			if (fit_cover) {
				w = height * ratio;
				h = height;
			} else {
				w = width;
				h = width / ratio;
			}
		} else {
			if (fit_cover) {
				w = width;
				h = width / ratio;
			} else {
				w = height * ratio;
				h = height;
			}
		}

		float x = (width - Math.ceilf (w)) / 2f;
		float y = Math.floorf ((height - h)) / 2f;

		snapshot.save ();
		snapshot.scale (1.0f / this.scale_factor, 1.0f / this.scale_factor);
		if (this.turntable) {
			snapshot.translate (Graphene.Point () {
				x = width / 2,
				y = height / 2
			});
			snapshot.rotate ((float) (360 * animation.value));
			snapshot.translate (Graphene.Point () {
				x = - (width / 2),
				y = - (height / 2)
			});
		} else if (this.style == Style.SHADOW) {
			snapshot.push_mask (Gsk.MaskMode.INVERTED_ALPHA);

			if (this.orientation == Gtk.Orientation.HORIZONTAL) {
				var new_fade = width - FADE_WIDTH;
				snapshot.append_linear_gradient (
					Graphene.Rect () {
						origin = Graphene.Point () {
							x = new_fade,
							y = 0
						},
						size = Graphene.Size () {
							width = FADE_WIDTH,
							height = height
						}
					},
					Graphene.Point () {
						x = width,
						y = 0
					},
					Graphene.Point () {
						x = new_fade,
						y = 0
					},
					GRADIENT
				);

				snapshot.pop ();
				snapshot.push_clip (Graphene.Rect () {
					origin = Graphene.Point () {
						x = 0,
						y = 0
					},
					size = Graphene.Size () {
						width = width,
						height = Math.ceilf (height) + 1
					}
				});
			} else {
				var new_fade = height - FADE_WIDTH;
				snapshot.append_linear_gradient (
					Graphene.Rect () {
						origin = Graphene.Point () {
							x = 0,
							y = new_fade
						},
						size = Graphene.Size () {
							width = width,
							height = FADE_WIDTH
						}
					},
					Graphene.Point () {
						x = 0,
						y = height
					},
					Graphene.Point () {
						x = 0,
						y = new_fade
					},
					GRADIENT
				);

				snapshot.pop ();
				snapshot.push_clip (Graphene.Rect () {
					origin = Graphene.Point () {
						x = 0,
						y = 0
					},
					size = Graphene.Size () {
						width = Math.ceilf (width) + 1,
						height = height
					}
				});
			}
		}

		if (cover == null) {
			snapshot.translate (Graphene.Point () {
				x = width / 2 - 64 / 2,
				y = height / 2 - 64 / 2
			});

			fallback_icon.snapshot_symbolic (snapshot, 64, 64, {});
		} else {
			snapshot.translate (Graphene.Point () {
				x = x,
				y = y
			});

			snapshot.append_scaled_texture (
				cover,
				this.scaling_filter,
				Graphene.Rect () {
					origin = Graphene.Point () { x=0, y=0 },
					size = Graphene.Size () { width = w, height = h }
				}
			);
		}

		if (style == Style.SHADOW) {
			snapshot.pop ();
			snapshot.pop ();
		}

		snapshot.restore ();

		if (this.turntable && this.record_center != null) {
			snapshot.translate (Graphene.Point () {
				x = width / 2 - this.record_center_inner.size.width / 2,
				y = height / 2 - this.record_center_inner.size.height / 2
			});
			snapshot.push_rounded_clip (this.record_center);

			if (this.cover != null) {
				var color = this.get_color ();
				color.alpha = 1f;
				snapshot.append_color (color, record_center_inner);
			}
			snapshot.pop ();
		}

		base.snapshot (snapshot);
	}
}
