public class Turntable.Views.Window : Adw.ApplicationWindow {
	GLib.SimpleAction toggle_orientation_action;
	GLib.SimpleAction cover_style_action;
	GLib.SimpleAction component_progressbin_action;
	GLib.SimpleAction component_extract_colors_action;
	GLib.SimpleAction window_style_action;
	GLib.SimpleAction client_icon_style_symbolic_action;
	GLib.SimpleAction component_client_icon_action;
	string uuid = GLib.Uuid.string_random ();

	public enum Style {
		WINDOW,
		OSD,
		TRANSPARENT;

		public string to_string () {
			switch (this) {
				case OSD: return "osd";
				case TRANSPARENT: return "transparent";
				default: return "window";
			}
		}

		public static Style from_string (string string_style) {
			switch (string_style) {
				case "osd": return OSD;
				case "transparent": return TRANSPARENT;
				default: return WINDOW;
			}
		}
	}

	private Style _window_style = Style.WINDOW;
	public Style window_style {
		get { return _window_style; }
		set {
			if (value != _window_style) {
				switch (_window_style) {
					case Style.WINDOW: break;
					case Style.TRANSPARENT:
						this.add_css_class ("csd");
						this.remove_css_class (Style.TRANSPARENT.to_string ());
						break;
					default:
						string old_css_class = _window_style.to_string ();
						if (this.has_css_class (old_css_class)) this.remove_css_class (old_css_class);
						break;
				}

				_window_style = value;
				string window_style_string = value.to_string ();

				switch (_window_style) {
					case Style.WINDOW: return;
					case Style.TRANSPARENT:
						this.remove_css_class ("csd");
						break;
				}

				this.add_css_class (window_style_string);
			}
		}
	}

	public string? song_title {
		set {
			title_label.content = value == null ? _("Unknown Title") : value;
		}
	}

	private string _artist = _("Unknown Artist");
	public string? artist {
		get { return _artist; }
		set {
			string old_val = _artist;
			_artist = value == null ? _("Unknown Artist") : value;

			if (old_val != _artist)
				update_album_artist_title ();
		}
	}

	private string _album = _("Unknown Album");
	public string? album {
		get { return _album; }
		set {
			string old_val = _album;
			_album = value == null ? _("Unknown Album") : value;

			if (old_val != _album)
				update_album_artist_title ();
		}
	}

	public string? art {
		set {
			if (value == null) {
				art_pic.file_path = null;
			} else {
				art_pic.file_path = value;
			}
		}
	}

	private int64 _position = 0;
	public int64 position {
		get { return _position; }
		set {
			if (this.length == 0) {
				_position = 0;
				prog.progress = 0;
			} else {
				_position = value;
				prog.progress = (double)value / (double)this.length;
			}
		}
	}

	private int64 _length = 0;
	public int64 length {
		get { return _length; }
		set {
			_length = value;

			prog.progress = value == 0 ? 0 : (double)this.position / (double)value;
			#if SCROBBLING
				add_to_scrobbler ();
			#endif
		}
	}

	private bool _playing = false;
	public bool playing {
		get { return _playing; }
		set {
			_playing = value;
			art_pic.turntable_playing = value;
			button_play.icon_name = value ? "media-playback-pause-symbolic" : "media-playback-start-symbolic";
			#if SCROBBLING
				update_scrobbler_playing ();
			#endif
		}
	}

	private Gtk.Orientation _orientation = Gtk.Orientation.HORIZONTAL;
	public Gtk.Orientation orientation {
		get { return _orientation; }
		set {
			if (value != _orientation) {
				_orientation = value;
				update_orientation ();
			}
		}
	}

	private void update_orientation () {
		switch (this.orientation) {
			case Gtk.Orientation.VERTICAL:
				this.default_width = 0;
				this.default_height = 300;
				album_label.visible = false;
				break;
			default:
				this.default_width = 534;
				this.default_height = 0;
				album_label.visible = true;
				break;
		}

		art_pic.orientation =
		main_box.orientation =
		prog.orientation = this.orientation;

		update_album_artist_title ();
	}

	private void update_album_artist_title () {
		switch (this.orientation) {
			case Gtk.Orientation.VERTICAL:
				artist_label.content = @"$(this.artist) - $(this.album)";
				break;
			default:
				artist_label.content = this.artist;
				album_label.content = this.album;
				break;
		}
	}

	public Window (Adw.Application app) {
		this.application = app;
	}

	public Widgets.Cover.Style cover_style {
		get { return art_pic.style; }
		set {
			if (value != art_pic.style ) {
				art_pic.style = value;

				switch (value) {
					case Widgets.Cover.Style.SHADOW:
						prog.offset = (
							this.orientation == Gtk.Orientation.HORIZONTAL
							? controls_overlay.get_width ()
							: controls_overlay.get_height ()
						) - (int32) (Widgets.Cover.FADE_WIDTH / 2);
						break;
					default:
						prog.offset = 0;
						break;
				}
			}
		}
	}

	private void update_extracted_colors () {
		prog.extracted_colors = art_pic.extracted_colors;
	}

	Mpris.Entry? player = null;
	Widgets.Marquee artist_label;
	Widgets.Marquee title_label;
	Widgets.Marquee album_label;
	Widgets.Cover art_pic;
	Widgets.ProgressBin prog;
	Gtk.Box main_box;
	Gtk.Button button_play;
	Gtk.Button button_prev;
	Gtk.Button button_next;
	Widgets.ControlsOverlay controls_overlay;
	construct {
		this.icon_name = Build.DOMAIN;
		this.resizable = false;
		this.title = Build.NAME;

		this.default_width = 0;
		this.default_height = 0;
		this.height_request = -1;
		this.width_request = -1;

		main_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
		art_pic = new Widgets.Cover () {
			valign = Gtk.Align.START,
			halign = Gtk.Align.START
		};
		art_pic.notify["extracted-colors"].connect (update_extracted_colors);
		controls_overlay = new Widgets.ControlsOverlay (art_pic);
		main_box.append (controls_overlay);

		var box2 = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
			hexpand = true,
			margin_top = 16,
			margin_bottom = 16,
			margin_end = 16,
			margin_start = 16
		};
		main_box.append (box2);


		title_label = new Widgets.Marquee () {
			css_classes = {"title-2"},
			xalign = 0.0f
		};
		artist_label = new Widgets.Marquee () {
			xalign = 0.0f
		};
		album_label = new Widgets.Marquee () {
			xalign = 0.0f
		};

		box2.append (title_label);
		box2.append (artist_label);
		box2.append (album_label);

		prog = new Widgets.ProgressBin () {
			content = main_box
		};

		var box3 = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8) {
			hexpand = true,
			vexpand = true,
			halign = Gtk.Align.CENTER,
			valign = Gtk.Align.CENTER,
		};
		box2.append (box3);

		button_prev = new Gtk.Button.from_icon_name ("media-skip-backward-symbolic") {
			css_classes = {"circular"},
			halign = Gtk.Align.CENTER,
			valign = Gtk.Align.CENTER,
		};
		box3.append (button_prev);

		button_play = new Gtk.Button.from_icon_name ("media-playback-start-symbolic") {
			css_classes = {"circular", "large"},
			halign = Gtk.Align.CENTER,
			valign = Gtk.Align.CENTER
		};
		box3.append (button_play);

		button_next = new Gtk.Button.from_icon_name ("media-skip-forward-symbolic") {
			css_classes = {"circular"},
			halign = Gtk.Align.CENTER,
			valign = Gtk.Align.CENTER,
		};
		box3.append (button_next);

		button_next.clicked.connect (() => {
			player.next ();
		});

		button_play.clicked.connect (() => {
			player.play_pause ();
		});

		button_prev.clicked.connect (() => {
			player.back ();
		});

		toggle_orientation_action = new GLib.SimpleAction.stateful ("toggle-orientation", GLib.VariantType.BOOLEAN, settings.orientation_horizontal);
		toggle_orientation_action.change_state.connect (on_toggle_orientation);
		this.add_action (toggle_orientation_action);

		cover_style_action = new GLib.SimpleAction.stateful ("cover-style", GLib.VariantType.STRING, this.cover_style.to_string ());
		cover_style_action.change_state.connect (on_change_cover_style);
		this.add_action (cover_style_action);

		component_extract_colors_action = new GLib.SimpleAction.stateful ("component-extract-colors", null, settings.component_extract_colors);
		component_extract_colors_action.change_state.connect (on_change_component_extract_colors);
		this.add_action (component_extract_colors_action);

		component_progressbin_action = new GLib.SimpleAction.stateful ("component-progressbin", null, settings.component_progressbin);
		component_progressbin_action.change_state.connect (on_change_component_progressbin);
		this.add_action (component_progressbin_action);

		window_style_action = new GLib.SimpleAction.stateful ("window-style", GLib.VariantType.STRING, this.window_style.to_string ());
		window_style_action.change_state.connect (on_change_window_style);
		this.add_action (window_style_action);

		client_icon_style_symbolic_action = new GLib.SimpleAction.stateful ("client-icon-style-symbolic", GLib.VariantType.BOOLEAN, settings.client_icon_style_symbolic);
		client_icon_style_symbolic_action.change_state.connect (on_change_client_icon_style);
		this.add_action (client_icon_style_symbolic_action);

		component_client_icon_action = new GLib.SimpleAction.stateful ("component-client-icon", null, settings.component_client_icon);
		component_client_icon_action.change_state.connect (on_change_component_client_icon);
		this.add_action (component_client_icon_action);

		update_orientation ();
		update_from_settings ();

		this.content = new Gtk.WindowHandle () {
			child = prog
		};

		//  GLib.Timeout.add (250, () => {
		//  	art_pic.turntable = true;
		//  	return GLib.Source.REMOVE;
		//  });

		controls_overlay.player_changed.connect (update_player);
		update_player (controls_overlay.last_player); // always ensure

		Gtk.GestureClick click_gesture = new Gtk.GestureClick () {
			button = Gdk.BUTTON_PRIMARY
		};
		click_gesture.pressed.connect (on_clicked);
		prog.add_controller (click_gesture);

		settings.notify["cover-style"].connect (update_cover_from_settings);
		settings.notify["orientation-horizontal"].connect (update_orientation_from_settings);
		settings.notify["component-progressbin"].connect (update_progressbin_from_settings);
		settings.notify["component-extract-colors"].connect (update_extract_colors_from_settings);
		settings.notify["window-style"].connect (update_cover_from_settings);
		settings.notify["client-icon-style-symbolic"].connect (update_client_icon_from_settings);
		settings.notify["component-client-icon"].connect (update_component_client_icon_from_settings);

		this.show.connect (on_realize);
	}

	private void on_realize () {
		art_pic.turntable_playing = this.playing;
	}

	private void update_from_settings () {
		update_orientation_from_settings ();
		update_cover_from_settings ();
		update_progressbin_from_settings ();
		update_extract_colors_from_settings ();
		update_window_from_settings ();
		update_client_icon_from_settings ();
		update_component_client_icon_from_settings ();
	}

	private void update_cover_from_settings () {
		this.cover_style = Widgets.Cover.Style.from_string (settings.cover_style);
		cover_style_action.set_state (this.cover_style.to_string ());
	}

	private void update_window_from_settings () {
		this.window_style = Style.from_string (settings.cover_style);
		window_style_action.set_state (this.window_style.to_string ());
	}

	private void update_client_icon_from_settings () {
		this.prog.client_icon_style = settings.client_icon_style_symbolic ? Widgets.ProgressBin.ClientIconStyle.SYMBOLIC : Widgets.ProgressBin.ClientIconStyle.FULL_COLOR;
		client_icon_style_symbolic_action.set_state (settings.client_icon_style_symbolic);
	}

	private void update_progressbin_from_settings () {
		this.prog.enabled = settings.component_progressbin;
		component_progressbin_action.set_state (this.prog.enabled);
	}

	private void update_extract_colors_from_settings () {
		this.prog.extract_colors_enabled = settings.component_extract_colors;
		component_extract_colors_action.set_state (this.prog.extract_colors_enabled);
	}

	private void update_orientation_from_settings () {
		this.orientation = settings.orientation_horizontal ? Gtk.Orientation.HORIZONTAL : Gtk.Orientation.VERTICAL;
		toggle_orientation_action.set_state (settings.orientation_horizontal);
	}

	private void update_component_client_icon_from_settings () {
		this.prog.client_icon_enabled = settings.component_client_icon;
		component_client_icon_action.set_state (settings.component_client_icon);
	}

	private void on_clicked (Gtk.GestureClick gesture, int n_press, double x, double y) {
		if (!controls_overlay.contains (x, y) && controls_overlay.get_focus_child () != null) this.focus_widget = null;
	}

	private void update_player (Mpris.Entry? new_player) {
		this.player = new_player;
		if (new_player == null) {
			this.song_title =
			this.artist =
			this.album =
			this.art =
			prog.client_icon =
			prog.client_name = null;

			this.position =
			this.length = 0;

			this.playing =
			button_next.sensitive =
			button_prev.sensitive =
				false;

			return;
		}

		this.player.bind_property ("title", this, "song-title", GLib.BindingFlags.SYNC_CREATE);
		this.player.bind_property ("artist", this, "artist", GLib.BindingFlags.SYNC_CREATE);
		this.player.bind_property ("album", this, "album", GLib.BindingFlags.SYNC_CREATE);
		this.player.bind_property ("art", this, "art", GLib.BindingFlags.SYNC_CREATE);
		this.player.bind_property ("position", this, "position", GLib.BindingFlags.SYNC_CREATE);
		this.player.bind_property ("length", this, "length", GLib.BindingFlags.SYNC_CREATE);
		this.player.bind_property ("playing", this, "playing", GLib.BindingFlags.SYNC_CREATE);
		this.player.bind_property ("can-go-next", button_next, "sensitive", GLib.BindingFlags.SYNC_CREATE);
		this.player.bind_property ("can-go-back", button_prev, "sensitive", GLib.BindingFlags.SYNC_CREATE);

		prog.client_icon = this.player.client_info_icon;
		prog.client_name = this.player.client_info_name;

		button_play.grab_focus ();
	}

	#if SCROBBLING
		private void add_to_scrobbler () {
			if (this.player == null || this.player.length == 0) return;

			scrobbling_manager.queue_payload (
				uuid,
				{ this.player.title, this.player.artist, this.player.album },
				this.player.length
			);
		}

		private void update_scrobbler_playing () {
			if (this.player == null || this.player.length == 0) return;

			scrobbling_manager.set_playing_for_id (
				uuid,
				this.playing
			);
		}
	#endif

	private void on_toggle_orientation (GLib.SimpleAction action, GLib.Variant? value) {
		if (value == null) return;
		settings.orientation_horizontal = value.get_boolean ();
	}

	private void on_change_cover_style (GLib.SimpleAction action, GLib.Variant? value) {
		if (value == null) return;
		settings.cover_style = value.get_string ();
	}

	private void on_change_component_progressbin (GLib.SimpleAction action, GLib.Variant? value) {
		if (value == null) return;
		settings.component_progressbin = value.get_boolean ();
	}

	private void on_change_component_extract_colors (GLib.SimpleAction action, GLib.Variant? value) {
		if (value == null) return;
		settings.component_extract_colors = value.get_boolean ();
	}

	private void on_change_window_style (GLib.SimpleAction action, GLib.Variant? value) {
		if (value == null) return;
		settings.window_style = value.get_string ();
	}

	private void on_change_client_icon_style (GLib.SimpleAction action, GLib.Variant? value) {
		if (value == null) return;
		settings.client_icon_style_symbolic = value.get_boolean ();
		settings.component_client_icon = true;
	}

	private void on_change_component_client_icon (GLib.SimpleAction action, GLib.Variant? value) {
		if (value == null) return;
		settings.component_client_icon = value.get_boolean ();
	}
}
