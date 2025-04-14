public class Turntable.Widgets.ProgressBin : Adw.Bin {
	Gdk.RGBA color;
	Gdk.RGBA accent_color;
	Adw.TimedAnimation animation;
	uint update_timeout = 0;
	Gtk.Overlay overlay;
	Gtk.Image client_icon_widget;
	Widgets.Tonearm tonearm;

	~ProgressBin () {
		debug ("Destroying");
	}

	public enum ClientIconStyle {
		SYMBOLIC,
		FULL_COLOR;

		public string to_string () {
			switch (this) {
				case FULL_COLOR: return "full-color";
				default: return "symbolic";
			}
		}

		public static ClientIconStyle from_string (string string_style) {
			switch (string_style) {
				case "full-color": return FULL_COLOR;
				default: return SYMBOLIC;
			}
		}
	}

	public bool client_icon_enabled {
		set {
			client_icon_widget.visible = value;
		}
	}

	private void update_client_icon () {
		string name = this.client_icon;

		switch (this.client_icon_style) {
			case FULL_COLOR:
				if (name.down ().has_suffix ("-symbolic")) {
					name = name.substring (0, name.length - 9);
				}
				break;
			case SYMBOLIC:
				if (!name.down ().has_suffix ("-symbolic")) {
					name = @"$name-symbolic";
				}
				break;
		}

		_client_icon = client_icon_widget.icon_name = name;
	}

	public Gtk.Widget content {
		set {
			overlay.child = value;
		}
	}

	private ClientIconStyle _client_icon_style = ClientIconStyle.SYMBOLIC;
	public ClientIconStyle client_icon_style {
		get { return _client_icon_style; }
		set {
			if (value != _client_icon_style) {
				_client_icon_style = value;
				update_client_icon ();
			}
		}
	}

	public bool client_icon_large {
		get { return client_icon_widget.icon_size == Gtk.IconSize.LARGE; }
		set {
			client_icon_widget.icon_size = value ? Gtk.IconSize.LARGE : Gtk.IconSize.NORMAL;
		}
	}

	private string _client_icon = "application-x-executable-symbolic";
	public string client_icon {
		get { return _client_icon; }
		set {
			if (value == null) value = "application-x-executable-symbolic";
			if (_client_icon != value) {
				_client_icon = value;
				update_client_icon ();
			}
		}
	}

	public string? client_name {
		set {
			client_icon_widget.tooltip_text = value == null || value == "" ? _("Unknown Client") : value;
		}
	}

	private Utils.Color.ExtractedColors? _extracted_colors = null;
	public Utils.Color.ExtractedColors? extracted_colors {
		get { return _extracted_colors; }
		set {
			_extracted_colors = value;

			if (update_timeout > 0) GLib.Source.remove (update_timeout);
			update_timeout = GLib.Timeout.add (200, update_color_cb, Priority.LOW);
		}
	}

	private bool _enabled = true;
	public bool enabled {
		get { return _enabled; }
		set {
			if (_enabled != value) {
				_enabled = value;
				this.queue_draw ();
			}
		}
	}

	public bool tonearm_enabled {
		get { return tonearm.enabled; }
		set { tonearm.enabled = value; }
	}

	private bool _extract_colors_enabled = true;
	public bool extract_colors_enabled {
		get { return _extract_colors_enabled; }
		set {
			if (_extract_colors_enabled != value) {
				_extract_colors_enabled = value;
				update_color ();
			}
		}
	}

	private bool update_color_cb () {
		update_timeout = 0;
		update_color ();
		return GLib.Source.REMOVE;
	}

	private void update_color () {
		Gdk.RGBA new_color = accent_color;

		if (this.extracted_colors != null && this.extract_colors_enabled) {
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
				animation.value_from = animation.state == Adw.AnimationState.PLAYING ? animation.value : _progress;
				animation.value_to = new_val;

				_progress =
				tonearm.progress = new_val;
				if (this.enabled) animation.play ();
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

		overlay = new Gtk.Overlay ();
		client_icon_widget = new Gtk.Image.from_icon_name ("application-x-executable-symbolic") {
			tooltip_text = _("Unknown Client"),
			valign = Gtk.Align.END,
			halign = Gtk.Align.END,
			margin_end = 6,
			margin_bottom = 6,
			icon_size = Gtk.IconSize.LARGE
		};

		overlay.add_overlay (client_icon_widget);

		tonearm = new Widgets.Tonearm ();
		overlay.add_overlay (tonearm);
		this.child = overlay;
	}

	public override void snapshot (Gtk.Snapshot snapshot) {
		if (this.enabled && this.animation.value > 0) {
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
