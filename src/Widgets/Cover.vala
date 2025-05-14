public class Turntable.Widgets.Cover : Gtk.Widget {
	public const float FADE_WIDTH = 64f;
	const Gsk.ColorStop[] GRADIENT = {
		{ 0f, { 0, 0, 0, 1f } },
		{ 1f, { 0, 0, 0, 0f } },
	};
	const Gsk.ColorStop[] GRADIENT_SHINE = {
		{ 0f, { 1, 1, 1, 0f } },
		{ 0.11f, { 1, 1, 1, 0.18f } },
		{ 0.13f, { 1, 1, 1, 0.18f } },
		{ 0.16f, { 1, 1, 1, 0f } },
		{ 0.5f, { 1, 1, 1, 0f } },
		{ 0.61f, { 1, 1, 1, 0.1f } },
		{ 0.63f, { 1, 1, 1, 0.1f } },
		{ 0.69f, { 1, 1, 1, 0f } },
		{ 1f, { 1, 1, 1, 0f } },
	};
	public signal void style_changed (Style style, Gtk.Orientation orientation);

	~Cover () {
		debug ("Destroying");
	}

	Gdk.RGBA vinyl_color;
	private void update_vinyl_color () {
		Gdk.RGBA new_color = { 0f, 0f, 0f, 1f };

		if (this.extracted_colors != null && settings.component_extract_colors) {
			new_color = Adw.StyleManager.get_default ().dark
				? extracted_colors.light
				: extracted_colors.dark;
		}

		if (new_color != vinyl_color) {
			vinyl_color = new_color;
			if (this.turntable) this.queue_draw ();
		}
	}
	Gtk.IconPaintable fallback_icon;
	Gdk.Texture? cover = null;
	Adw.TimedAnimation animation;
	Gsk.RoundedRect record_center;
	Graphene.Rect record_center_inner;

	private void update_record_rects () {
		record_center_inner = Graphene.Rect () {
			origin = Graphene.Point () {
				x = 0,
				y = 0
			},
			size = Graphene.Size () {
				width = 128 * this.scale_factor,
				height = 128 * this.scale_factor
			}
		};

		record_center = Gsk.RoundedRect ().init_from_rect (
			record_center_inner,
			9999f
		);
	}

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

	public enum Scaling {
		LINEAR,
		NEAREST,
		TRILINEAR;

		public string to_string () {
			switch (this) {
				case NEAREST: return "nearest";
				case TRILINEAR: return "trilinear";
				default: return "linear";
			}
		}

		public Gsk.ScalingFilter to_filter () {
			switch (this) {
				case NEAREST: return Gsk.ScalingFilter.NEAREST;
				case TRILINEAR: return Gsk.ScalingFilter.TRILINEAR;
				default: return Gsk.ScalingFilter.LINEAR;
			}
		}

		public static Scaling from_string (string string_scaling) {
			switch (string_scaling) {
				case "nearest": return NEAREST;
				case "trilinear": return TRILINEAR;
				default: return LINEAR;
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


	private Utils.Color.ExtractedColors? _extracted_colors = null;
	public Utils.Color.ExtractedColors? extracted_colors {
		get { return _extracted_colors; }
		set {
			_extracted_colors = value;
			update_vinyl_color ();
			this.notify_property ("extracted-colors");
		}
	}

	private class CoverLoader : GLib.Object {
		private string file_path;
		private Cancellable cancellable = new Cancellable ();
		private Gdk.Texture? texture = null;
		private Utils.Color.ExtractedColors? extracted_colors = null;
		public signal void done (Gdk.Texture texture);
		public signal void done_completely (Utils.Color.ExtractedColors? extracted_colors);

		private uint done_idle_id = -1;
		private uint done_completely_idle_id = -1;
		private bool extract = true;

		~CoverLoader () {
			debug ("[CoverLoader] Destroying");
			if (done_idle_id != -1) GLib.Source.remove (done_idle_id);
			if (done_completely_idle_id != -1) GLib.Source.remove (done_completely_idle_id);
			done_idle_id = done_completely_idle_id = -1;

			this.texture = null;
		}

		public CoverLoader (string file_path) {
			this.file_path = file_path;
			this.extract = settings.component_extract_colors;
		}

		public CoverLoader.painter (Gdk.Texture texture) {
			this.texture = texture;
		}

		public void fetch () {
			debug ("[CoverLoader] Spawned Fetch");

			string clean_path = file_path;
			if (clean_path.has_prefix ("file://")) {
				clean_path = this.file_path.splice (0, 7);
			}

			//  var t_texture = Gdk.Texture.from_filename (clean_path);
			//  if (cancellable.is_cancelled ()) return;

			//  this.texture = t_texture;
			//  GLib.Idle.add_once (done_idle);

			Gdk.Pixbuf pixbuf;
			try {
				if (clean_path.has_prefix ("data:")) {
					int comma_pos = clean_path.index_of (",");
					if (comma_pos == -1) throw new Error.literal (-1, 3, "Invalid base64 encoded image");
					var base64_data = GLib.Base64.decode (clean_path.substring (comma_pos + 1));
					var loader = new Gdk.PixbufLoader ();
					loader.write (base64_data);
					loader.close ();
					pixbuf = loader.get_pixbuf ();
				} else if (clean_path.down ().has_prefix ("https://")) {
					var session = new Soup.Session () {
						user_agent = @"$(Build.NAME)/$(Build.VERSION) libsoup/$(Soup.get_major_version()).$(Soup.get_minor_version()).$(Soup.get_micro_version()) ($(Soup.MAJOR_VERSION).$(Soup.MINOR_VERSION).$(Soup.MICRO_VERSION))" // vala-lint=line-length
					};
					var in_stream = session.send (new Soup.Message ("GET", this.file_path), cancellable);
					pixbuf = new Gdk.Pixbuf.from_stream (in_stream, cancellable);
				} else {
					pixbuf = new Gdk.Pixbuf.from_file (clean_path);
				}
			} catch (Error e) {
				debug ("Couldn't get pixbuf %s: %s", clean_path, e.message);
				stop_it (true);
				return;
			}

			if (cancellable.is_cancelled ()) {
				stop_it (true);
				return;
			}

			var t_texture = Gdk.Texture.for_pixbuf (pixbuf);
			if (cancellable.is_cancelled ()) {
				stop_it (true);
				return;
			}

			this.texture = t_texture;
			done_idle_id = GLib.Idle.add_once (done_idle);

			if (!this.extract) {
				stop_it (false);
				return;
			}

			extract_colors_from_pixbuf (pixbuf);
		}

		private inline void stop_it (bool both = false) {
			if (both) done_idle_id = GLib.Idle.add_once (done_idle);
			done_completely_idle_id = GLib.Idle.add_once (done_completely_idle);
		}

		private void extract_colors_from_pixbuf (Gdk.Pixbuf? pixbuf) {
			if (pixbuf == null) {
				stop_it (false);
				return;
			}

			Gdk.RGBA avg = Utils.Color.get_prominent_color (pixbuf, cancellable);
			if (cancellable.is_cancelled ()) {
				stop_it (false);
				return;
			}

			this.extracted_colors = Utils.Color.get_contrasting_colors (avg);
			done_completely_idle_id = GLib.Idle.add_once (done_completely_idle);
		}

		public void extract_colors () {
			debug ("[CoverLoader] Spawned Extract");

			if (this.texture == null) {
				stop_it (false);
				return;
			}

			File tmp;
			try {
				FileIOStream ios;
				tmp = File.new_tmp (null, out ios);
				this.texture.save_to_png (tmp.get_path ());
			} catch {
				stop_it (false);
				return;
			}

			if (cancellable.is_cancelled ()) {
				stop_it (false);
				return;
			}

			try {
				var texture_pixbuf = new Gdk.Pixbuf.from_file (tmp.get_path ());
				extract_colors_from_pixbuf (texture_pixbuf);
			} catch (Error e) {
				debug ("Couldn't get pixbuf from temp file: %s", e.message);
				stop_it (false);
			}
		}

		private void done_idle () {
			done (this.texture);
			done_idle_id = -1;
		}

		private void done_completely_idle () {
			this.texture = null;
			done_completely (this.extracted_colors);
			// flatpak crashes?
			//  this.extracted_colors = null;
			//  done_completely_idle_id = -1;
		}

		public void cancel () {
			cancellable.cancel ();
			if (done_idle_id != -1) GLib.Source.remove (done_idle_id);
			if (done_completely_idle_id != -1) GLib.Source.remove (done_completely_idle_id);
			done_idle_id = done_completely_idle_id = -1;
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
				//  if (cache.contains (value)) {
				//  	debug ("[CoverLoader] Cache Hit")
				//  	var cache_item = cache.get (value);
				//  	this.cover = cache_item.texture;
				//  	this.extract_colors = cache_item.colors;
				//  	this.queue_draw ();
				//  	return;
				//  }

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

	private bool _fit_cover = true;
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
		set_accessible_role (Gtk.AccessibleRole.NONE); // it's probably better if it doesn't get announced
	}

	private void animation_target_cb (double value) {
		this.queue_draw ();
	}

	construct {
		update_record_rects ();
		this.overflow = Gtk.Overflow.HIDDEN;
		this.notify["scale-factor"].connect (on_scale_factor_changed);

		var target = new Adw.CallbackAnimationTarget (animation_target_cb);
		animation = new Adw.TimedAnimation (this, 0.0, 1.0, 5000, target) {
			easing = Adw.Easing.LINEAR,
			repeat_count = 0,
			follow_enable_animations_setting = false // it's slow and opt-in
		};

		fallback_icon = (Gtk.IconTheme.get_for_display (Gdk.Display.get_default ())).lookup_icon (
			"music-note-outline-symbolic",
			null,
			48,
			this.scale_factor,
			Gtk.TextDirection.NONE,
			Gtk.IconLookupFlags.PRELOAD
		);

		Adw.StyleManager.get_default ().notify["dark"].connect (update_vinyl_color);
		settings.notify["component-extract-colors"].connect (update_extracted_colors_setting);
		update_vinyl_color ();
	}

	private void on_scale_factor_changed () {
		update_record_rects ();
		this.queue_draw ();
	}

	private void update_extracted_colors_setting () {
		if (settings.component_extract_colors && this.cover != null) {
			working_loader = new CoverLoader.painter (this.cover);

			try {
				working_loader.done.connect (queue_draw_cb);
				working_loader.done_completely.connect (done_completely_cb);
				new GLib.Thread<void>.try ("CoverLoader - Painter", working_loader.extract_colors);
			} catch {
				if (working_loader != null) {
					working_loader.cancel ();
					working_loader = null;
				}

				this.extracted_colors = null;
				this.queue_draw ();
			}
		} else {
			update_vinyl_color ();
		}
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
		float t_w = 0;
		float t_h = 0;

		if (ratio == 1) {
			w = width;
			h = height;
			if (this.turntable) {
				t_w = this.record_center_inner.size.width;
				t_h = this.record_center_inner.size.height;
			}
		} else if (ratio > 1) {
			if (fit_cover) {
				w = height * ratio;
				h = height;
				if (this.turntable) {
					t_w = this.record_center_inner.size.height * ratio;
					t_h = this.record_center_inner.size.height;
				}
			} else {
				w = width;
				h = width / ratio;
				if (this.turntable) {
					t_w = this.record_center_inner.size.width;
					t_h = this.record_center_inner.size.width / ratio;
				}
			}
		} else {
			if (fit_cover) {
				w = width;
				h = width / ratio;
				if (this.turntable) {
					t_w = this.record_center_inner.size.width;
					t_h = this.record_center_inner.size.width / ratio;
				}
			} else {
				w = height * ratio;
				h = height;
				if (this.turntable) {
					t_w = this.record_center_inner.size.height * ratio;
					t_h = this.record_center_inner.size.height;
				}
			}
		}

		float x = (width - Math.ceilf (w)) / 2f;
		float y = Math.floorf ((height - h)) / 2f;

		snapshot.save ();
		if (this.scale_factor != 1) snapshot.scale (1.0f / this.scale_factor, 1.0f / this.scale_factor);
		if (this.turntable) {
			var snapshot_vinyl_color_groove = vinyl_color;
			snapshot_vinyl_color_groove.alpha = 0.8f;

			snapshot.append_repeating_radial_gradient (
				Graphene.Rect () {
					origin = Graphene.Point () {
						x = 0,
						y = 0
					},
					size = Graphene.Size () {
						width = width,
						height = height
					}
				},
				Graphene.Point () {
					x = width / 2,
					y = height / 2
				},
				2f,
				2f,
				0f,
				2f,
				{
					{ 0f, vinyl_color },
					{ 0.95f, vinyl_color },
					{ 1f, snapshot_vinyl_color_groove },
				}
			);

			snapshot.append_conic_gradient (
				Graphene.Rect () {
					origin = Graphene.Point () {
						x = 0,
						y = 0
					},
					size = Graphene.Size () {
						width = width,
						height = height
					}
				},
				Graphene.Point () {
					x = width / 2,
					y = height / 2
				},
				0,
				GRADIENT_SHINE
			);

			var translation_point = Graphene.Point () {
				x = width / 2,
				y = height / 2
			};
			snapshot.translate (translation_point);
			//  snapshot.scale (0.65f / this.scale_factor, 0.65f / this.scale_factor);
			snapshot.rotate ((float) (360 * animation.value));
			snapshot.translate (Graphene.Point () {
				x = - translation_point.x,
				y = - translation_point.y
			});
		}

		if (this.style == Style.SHADOW) {
			snapshot.push_mask (Gsk.MaskMode.INVERTED_ALPHA);

			if (this.orientation == Gtk.Orientation.HORIZONTAL) {
				var new_fade = is_rtl ? 0 : width - FADE_WIDTH;
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
						x = is_rtl ? new_fade : width,
						y = 0
					},
					Graphene.Point () {
						x = is_rtl ? FADE_WIDTH : new_fade,
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
			Gdk.RGBA note_color = this.get_color ();
			if (this.turntable) {
				var translation_point = Graphene.Point () {
					x = width / 2 - this.record_center_inner.size.width / 2,
					y = height / 2 - this.record_center_inner.size.height / 2
				};
				snapshot.translate (translation_point);

				snapshot.push_rounded_clip (this.record_center);
				snapshot.append_color (
					{
						1f - vinyl_color.red,
						1f - vinyl_color.green,
						1f - vinyl_color.blue,
						1f
					},
					record_center_inner
				);
				snapshot.pop ();

				snapshot.translate (Graphene.Point () {
					x = -translation_point.x,
					y = -translation_point.y
				});

				note_color = {0, 0, 0, 0.5f};
			}

			int scaled_size = 64 * this.scale_factor; // always int
			snapshot.translate (Graphene.Point () {
				x = width / 2 - scaled_size / 2,
				y = height / 2 - scaled_size / 2
			});

			fallback_icon.snapshot_symbolic (snapshot, scaled_size, scaled_size, {note_color});
		} else {
			float texture_w = w;
			float texture_h = h;
			if (this.turntable) {
				texture_w = t_w;
				texture_h = t_h;

				var center_point = Graphene.Point () {
					x = width / 2 - this.record_center_inner.size.width / 2,
					y = height / 2 - this.record_center_inner.size.height / 2
				};

				snapshot.push_rounded_clip (
					Gsk.RoundedRect ().init_from_rect (
						Graphene.Rect () {
							origin = center_point,
							size = this.record_center_inner.size
						},
						9999f
					)
				);

				if (ratio == 1) {
					snapshot.translate (center_point);
				} else if (this.fit_cover) {
					float new_x = 0;
					float new_y = 0;

					if (ratio < 1) {
						new_x = width / 2 - this.record_center_inner.size.width / 2;
						new_y = height / 2 - texture_h / 2;
					} else {
						new_y = height / 2 - this.record_center_inner.size.height / 2;
						new_x = width / 2 - texture_w / 2;
					}

					snapshot.translate (Graphene.Point () {
						x = new_x,
						y = new_y
					});
				} else {
					snapshot.translate (Graphene.Point () {
						x = width / 2 - texture_w / 2,
						y = height / 2 - texture_h / 2
					});
				}
			} else if (this.style == Style.SHADOW) {
				snapshot.translate (Graphene.Point () {
					x = 0,
					y = 0
				});

				snapshot.push_blur (15);
				snapshot.append_texture (
					cover,
					Graphene.Rect () {
						origin = Graphene.Point () { x = 0, y = 0 },
						size = Graphene.Size () { width = width, height = height }
					}
				);
				snapshot.pop ();

				snapshot.translate (Graphene.Point () {
					x = x,
					y = y
				});
			} else {
				snapshot.translate (Graphene.Point () {
					x = x,
					y = y
				});
			}

			snapshot.append_scaled_texture (
				cover,
				this.scaling_filter,
				Graphene.Rect () {
					origin = Graphene.Point () { x = 0, y = 0 },
					size = Graphene.Size () { width = texture_w, height = texture_h }
				}
			);

			if (this.turntable) {
				snapshot.pop ();
			}
		}

		if (style == Style.SHADOW) {
			snapshot.pop ();
			snapshot.pop ();
		}

		snapshot.restore ();

		base.snapshot (snapshot);
	}
}
