public class Turntable.Views.Window : Adw.ApplicationWindow {
	GLib.SimpleAction toggle_orientation_action;
	GLib.SimpleAction cover_style_action;
	GLib.SimpleAction component_progressbin_action;
	GLib.SimpleAction component_extract_colors_action;
	GLib.SimpleAction window_style_action;
	GLib.SimpleAction client_icon_style_symbolic_action;
	GLib.SimpleAction component_client_icon_action;
	GLib.SimpleAction component_cover_fit_action;
	GLib.SimpleAction meta_dim_action;
	GLib.SimpleAction text_size_action;
	GLib.SimpleAction cover_size_action;
	GLib.SimpleAction cover_scaling_action;
	GLib.SimpleAction component_tonearm_action;
	GLib.SimpleAction component_center_text_action;
	public string uuid { get; private set; }

	~Window () {
		debug ("Destroying: %s", uuid);
	}

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
			switch (string_style.down ()) {
				case "osd": return OSD;
				case "transparent": return TRANSPARENT;
				default: return WINDOW;
			}
		}
	}

	public enum Size {
		SMALL,
		REGULAR,
		BIG;

		public string to_string () {
			switch (this) {
				case SMALL: return "small";
				case BIG: return "big";
				default: return "regular";
			}
		}

		public static Size from_string (string string_size) {
			switch (string_size.down ()) {
				case "small": return SMALL;
				case "big": return BIG;
				default: return REGULAR;
			}
		}
	}

	private Size _cover_size = Size.REGULAR;
	public Size cover_size {
		get { return _cover_size; }
		set {
			if (value != _cover_size) {
				_cover_size = value;
				switch (_cover_size) {
					case SMALL:
						art_pic.size = 124;
						prog.client_icon_large = false;
						break;
					case BIG:
						art_pic.size = 256;
						prog.client_icon_large = true;
						break;
					default:
						art_pic.size = 192;
						prog.client_icon_large = true;
						break;
				}

				update_orientation ();
				update_offset ();
			}
		}
	}

	private Size _text_size = Size.REGULAR;
	public Size text_size {
		get { return _text_size; }
		set {
			if (value != _text_size) {
				switch (_text_size) {
					case SMALL:
						title_label.remove_css_class ("title-3");
						album_label.remove_css_class ("smaller-label");
						artist_label.remove_css_class ("smaller-label");
						break;
					case BIG:
						title_label.remove_css_class ("title-1");
						album_label.remove_css_class ("bigger-label");
						artist_label.remove_css_class ("bigger-label");
						break;
					default:
						title_label.remove_css_class ("title-2");
						break;
				}

				_text_size = value;

				switch (_text_size) {
					case SMALL:
						title_label.add_css_class ("title-3");
						album_label.add_css_class ("smaller-label");
						artist_label.add_css_class ("smaller-label");
						break;
					case BIG:
						title_label.add_css_class ("title-1");
						album_label.add_css_class ("bigger-label");
						artist_label.add_css_class ("bigger-label");
						break;
					default:
						title_label.add_css_class ("title-2");
						break;
				}
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
					default:
						break;
				}

				this.add_css_class (window_style_string);
			}
		}
	}

	public string? song_title {
		set {
			// translators: default string when title is missing
			title_label.content = value == null ? _("Unknown Title") : value;
		}
	}

	// translators: default string when artist is missing
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

	// translators: default string when album is missing
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
				#if SCROBBLING
					if (value == 0 && this.player != null && this.player.looping && _position > 0) {
						this.length = this.length; // re-trigger it
					}
				#endif
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
				if (value > 0) {
					add_to_scrobbler ();
					if (this.playing) update_scrobbler_playing ();
				}
			#endif
		}
	}

	private bool _playing = false;
	public bool playing {
		get { return _playing; }
		set {
			_playing = value;
			art_pic.turntable_playing = value;
			button_play.icon_name = value ? "pause-large-symbolic" : "play-large-symbolic";
			// translators: button tooltip text
			button_play.tooltip_text = value ? _("Pause") : _("Play");
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
				this.default_height = this.cover_size == Size.SMALL ? 300 : 400;
				break;
			default:
				this.default_width = 534;
				this.default_height = 0;
				break;
		}

		art_pic.orientation =
		main_box.orientation =
		prog.orientation = this.orientation;

		update_album_artist_title ();
	}

	private void update_album_artist_title () {
		if (this.orientation == Gtk.Orientation.VERTICAL || this.cover_size == Size.SMALL) {
			album_label.visible = false;
			artist_label.content = @"$(this.artist) - $(this.album)";
		} else {
			artist_label.content = this.artist;
			album_label.content = this.album;
			album_label.visible = true;
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
				art_pic.turntable_playing = this.playing;
				update_offset ();
			}
		}
	}

	private void update_offset () {
		switch (this.cover_style) {
			case Widgets.Cover.Style.SHADOW:
				prog.offset = art_pic.size - (int32) (Widgets.Cover.FADE_WIDTH / 2);
				break;
			default:
				prog.offset = 0;
				break;
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
		this.uuid = GLib.Uuid.string_random ();
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

		button_prev = new Gtk.Button.from_icon_name (is_rtl ? "skip-forward-large-symbolic" : "skip-backward-large-symbolic") {
			css_classes = {"circular"},
			halign = Gtk.Align.CENTER,
			valign = Gtk.Align.CENTER,
			// translators: button tooltip text
			tooltip_text = _("Previous Song")
		};
		box3.append (button_prev);

		button_play = new Gtk.Button.from_icon_name ("play-large-symbolic") {
			css_classes = {"circular", "large"},
			halign = Gtk.Align.CENTER,
			valign = Gtk.Align.CENTER,
			tooltip_text = _("Play")
		};
		box3.append (button_play);

		button_next = new Gtk.Button.from_icon_name (is_rtl ? "skip-backward-large-symbolic" : "skip-forward-large-symbolic") {
			css_classes = {"circular"},
			halign = Gtk.Align.CENTER,
			valign = Gtk.Align.CENTER,
			// translators: button tooltip text
			tooltip_text = _("Next Song")
		};
		box3.append (button_next);

		button_next.clicked.connect (play_next);
		button_play.clicked.connect (play_pause);
		button_prev.clicked.connect (play_back);

		#if SCROBBLING
			var scrobbling_action = new GLib.SimpleAction ("open-scrobbling-setup", null);
			scrobbling_action.activate.connect (open_scrobbling_setup);
			this.add_action (scrobbling_action);
		#endif

		text_size_action = new GLib.SimpleAction.stateful ("text-size", GLib.VariantType.STRING, this.text_size.to_string ());
		text_size_action.change_state.connect (on_change_text_size);
		this.add_action (text_size_action);

		cover_size_action = new GLib.SimpleAction.stateful ("cover-size", GLib.VariantType.STRING, this.cover_size.to_string ());
		cover_size_action.change_state.connect (on_change_cover_size);
		this.add_action (cover_size_action);

		cover_scaling_action = new GLib.SimpleAction.stateful ("cover-scaling", GLib.VariantType.STRING, settings.cover_scaling.to_string ());
		cover_scaling_action.change_state.connect (on_change_cover_scaling);
		this.add_action (cover_scaling_action);

		toggle_orientation_action = new GLib.SimpleAction.stateful ("toggle-orientation", GLib.VariantType.BOOLEAN, settings.orientation_horizontal);
		toggle_orientation_action.change_state.connect (on_toggle_orientation);
		this.add_action (toggle_orientation_action);

		cover_style_action = new GLib.SimpleAction.stateful ("cover-style", GLib.VariantType.STRING, this.cover_style.to_string ());
		cover_style_action.change_state.connect (on_change_cover_style);
		this.add_action (cover_style_action);

		component_extract_colors_action = new GLib.SimpleAction.stateful ("component-extract-colors", null, settings.component_extract_colors);
		component_extract_colors_action.change_state.connect (on_change_component_extract_colors);
		this.add_action (component_extract_colors_action);

		meta_dim_action = new GLib.SimpleAction.stateful ("meta-dim", null, settings.meta_dim);
		meta_dim_action.change_state.connect (on_change_meta_dim);
		this.add_action (meta_dim_action);

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

		component_tonearm_action = new GLib.SimpleAction.stateful ("component-tonearm", null, settings.component_tonearm);
		component_tonearm_action.change_state.connect (on_change_component_tonearm);
		this.add_action (component_tonearm_action);

		component_center_text_action = new GLib.SimpleAction.stateful ("component-center-text", null, settings.component_center_text);
		component_center_text_action.change_state.connect (on_change_component_center_text);
		this.add_action (component_center_text_action);

		component_cover_fit_action = new GLib.SimpleAction.stateful ("component-cover-fit", null, settings.component_cover_fit);
		component_cover_fit_action.change_state.connect (on_change_component_cover_fit);
		this.add_action (component_cover_fit_action);

		update_orientation ();
		update_from_settings ();

		this.content = new Gtk.WindowHandle () {
			child = prog
		};

		controls_overlay.player_changed.connect (update_player);
		update_player (controls_overlay.last_player); // always ensure

		settings.notify["cover-style"].connect (update_cover_from_settings);
		settings.notify["orientation-horizontal"].connect (update_orientation_from_settings);
		settings.notify["component-progressbin"].connect (update_progressbin_from_settings);
		settings.notify["component-extract-colors"].connect (update_extract_colors_from_settings);
		settings.notify["window-style"].connect (update_window_from_settings);
		settings.notify["client-icon-style-symbolic"].connect (update_client_icon_from_settings);
		settings.notify["component-client-icon"].connect (update_component_client_icon_from_settings);
		settings.notify["component-tonearm"].connect (update_component_tonearm_from_settings);
		settings.notify["component-center-text"].connect (update_component_center_text_from_settings);
		settings.notify["component-cover-fit"].connect (update_component_cover_fit_from_settings);
		settings.notify["meta-dim"].connect (update_meta_dim_from_settings);
		settings.notify["text-size"].connect (update_text_size_from_settings);
		settings.notify["cover-size"].connect (update_cover_size_from_settings);
		settings.notify["cover-scaling"].connect (update_cover_scaling_from_settings);

		#if SCROBBLING
			settings.notify["scrobbler-allowlist"].connect (update_scrobble_status);
			account_manager.accounts_changed.connect (update_scrobble_status);
		#endif

		box2.state_flags_changed.connect (on_state_flags_changed);
		art_pic.map.connect (on_mapped);
	}

	private void play_next () {
		if (this.player != null) this.player.next ();
	}

	private void play_back () {
		if (this.player != null) this.player.back ();
	}

	private void play_pause () {
		if (this.player != null) this.player.play_pause ();
	}

	private void on_mapped () {
		update_offset ();
		art_pic.turntable_playing = this.playing;
	}

	#if SCROBBLING
		bool scrobble_enabled = false;
		private void update_scrobble_status () {
			bool new_val = account_manager.accounts.length > 0
				&& this.player != null
				&& this.player.bus_namespace in settings.scrobbler_allowlist;

			if (scrobble_enabled != new_val) {
				scrobble_enabled = new_val;
				if (this.length > 0) {
					add_to_scrobbler ();
					update_scrobbler_playing ();
				}
			}
		}
	#endif

	private void update_from_settings () {
		update_orientation_from_settings ();
		update_cover_from_settings ();
		update_progressbin_from_settings ();
		update_extract_colors_from_settings ();
		update_window_from_settings ();
		update_client_icon_from_settings ();
		update_component_client_icon_from_settings ();
		update_component_tonearm_from_settings ();
		update_component_cover_fit_from_settings ();
		update_meta_dim_from_settings ();
		update_text_size_from_settings ();
		update_cover_size_from_settings ();
		update_cover_scaling_from_settings ();
		update_component_center_text_from_settings ();
	}

	private void update_cover_scaling_from_settings () {
		Widgets.Cover.Scaling new_size = Widgets.Cover.Scaling.from_string (settings.cover_scaling);
		art_pic.scaling_filter = new_size.to_filter ();
		cover_scaling_action.set_state (new_size.to_string ());
	}

	private void update_cover_size_from_settings () {
		this.cover_size = Size.from_string (settings.cover_size);
		cover_size_action.set_state (this.cover_size.to_string ());
	}

	private void update_text_size_from_settings () {
		this.text_size = Size.from_string (settings.text_size);
		text_size_action.set_state (this.text_size.to_string ());
	}

	private void update_cover_from_settings () {
		this.cover_style = Widgets.Cover.Style.from_string (settings.cover_style);
		cover_style_action.set_state (this.cover_style.to_string ());
	}

	private void update_window_from_settings () {
		this.window_style = Style.from_string (settings.window_style);
		window_style_action.set_state (this.window_style.to_string ());
	}

	private void update_client_icon_from_settings () {
		this.prog.client_icon_style = settings.client_icon_style_symbolic ? Widgets.ProgressBin.ClientIconStyle.SYMBOLIC : Widgets.ProgressBin.ClientIconStyle.FULL_COLOR;
		client_icon_style_symbolic_action.set_state (settings.client_icon_style_symbolic);
	}

	private void update_meta_dim_from_settings () {
		if (settings.meta_dim) {
			if (!artist_label.has_css_class ("dim-label")) artist_label.add_css_class ("dim-label");
			if (!album_label.has_css_class ("dim-label")) album_label.add_css_class ("dim-label");
		} else {
			if (artist_label.has_css_class ("dim-label")) artist_label.remove_css_class ("dim-label");
			if (album_label.has_css_class ("dim-label")) album_label.remove_css_class ("dim-label");
		}

		meta_dim_action.set_state (settings.meta_dim);
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

	private void update_component_tonearm_from_settings () {
		this.prog.tonearm_enabled = settings.component_tonearm;
		component_tonearm_action.set_state (settings.component_tonearm);
	}

	private void update_component_center_text_from_settings () {
		album_label.xalign =
		artist_label.xalign =
		title_label.xalign = settings.component_center_text ? 0.5f : 0f;
		component_center_text_action.set_state (settings.component_center_text);
	}

	private void update_component_cover_fit_from_settings () {
		this.art_pic.fit_cover = settings.component_cover_fit;
		component_cover_fit_action.set_state (settings.component_cover_fit);
	}

	private void on_state_flags_changed (Gtk.Widget box, Gtk.StateFlags old_flags) {
		if (!(Gtk.StateFlags.PRELIGHT in old_flags) && (Gtk.StateFlags.PRELIGHT in box.get_state_flags ())) {
			if (controls_overlay.hide_overlay ()) this.focus_widget = null;
		}
	}

	#if SCROBBLING
		private void open_scrobbling_setup () {
			(new Views.ScrobblerSetup ()).present (this);
		}
	#endif

	GLib.Binding[] player_bindings = {};
	private void update_player (Mpris.Entry? new_player) {
		debug ("[%s] Player Changed", uuid);

		#if SCROBBLING
			scrobbling_manager.clear_queue (uuid);
			scrobble_enabled = false;
		#endif
		this.player = new_player;
		foreach (var binding in player_bindings) {
			binding.unbind ();
		}
		player_bindings = {};

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
			button_play.sensitive = false;

			return;
		}

		player_bindings += this.player.bind_property ("title", this, "song-title", GLib.BindingFlags.SYNC_CREATE);
		player_bindings += this.player.bind_property ("artist", this, "artist", GLib.BindingFlags.SYNC_CREATE);
		player_bindings += this.player.bind_property ("album", this, "album", GLib.BindingFlags.SYNC_CREATE);
		player_bindings += this.player.bind_property ("art", this, "art", GLib.BindingFlags.SYNC_CREATE);
		player_bindings += this.player.bind_property ("position", this, "position", GLib.BindingFlags.SYNC_CREATE);
		player_bindings += this.player.bind_property ("length", this, "length", GLib.BindingFlags.SYNC_CREATE);
		player_bindings += this.player.bind_property ("playing", this, "playing", GLib.BindingFlags.SYNC_CREATE);
		player_bindings += this.player.bind_property ("can-go-next", button_next, "sensitive", GLib.BindingFlags.SYNC_CREATE);
		player_bindings += this.player.bind_property ("can-go-back", button_prev, "sensitive", GLib.BindingFlags.SYNC_CREATE);
		player_bindings += this.player.bind_property ("can-control", button_play, "sensitive", GLib.BindingFlags.SYNC_CREATE);

		prog.client_icon = this.player.client_info_icon;
		prog.client_name = this.player.client_info_name;

		button_play.grab_focus ();
		#if SCROBBLING
			update_scrobble_status ();
		#endif
	}

	#if SCROBBLING
		private void add_to_scrobbler () {
			if (this.player == null || this.player.length == 0 || !scrobble_enabled) return;

			scrobbling_manager.queue_payload (
				uuid,
				this.player.bus_namespace,
				{ this.player.title, this.player.artist, this.player.album },
				this.player.length
			);
		}

		private void update_scrobbler_playing () {
			if (this.player == null || this.player.length == 0 || !scrobble_enabled) return;

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

	private void on_change_text_size (GLib.SimpleAction action, GLib.Variant? value) {
		if (value == null) return;
		settings.text_size = value.get_string ();
	}

	private void on_change_cover_size (GLib.SimpleAction action, GLib.Variant? value) {
		if (value == null) return;
		settings.cover_size = value.get_string ();
	}

	private void on_change_cover_scaling (GLib.SimpleAction action, GLib.Variant? value) {
		if (value == null) return;
		settings.cover_scaling = value.get_string ();
	}

	private void on_change_cover_style (GLib.SimpleAction action, GLib.Variant? value) {
		if (value == null) return;
		settings.cover_style = value.get_string ();
	}

	private void on_change_meta_dim (GLib.SimpleAction action, GLib.Variant? value) {
		if (value == null) return;
		settings.meta_dim = value.get_boolean ();
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

	private void on_change_component_tonearm (GLib.SimpleAction action, GLib.Variant? value) {
		if (value == null) return;
		settings.component_tonearm = value.get_boolean ();
	}

	private void on_change_component_center_text (GLib.SimpleAction action, GLib.Variant? value) {
		if (value == null) return;
		settings.component_center_text = value.get_boolean ();
	}

	private void on_change_component_cover_fit (GLib.SimpleAction action, GLib.Variant? value) {
		if (value == null) return;
		settings.component_cover_fit = value.get_boolean ();
	}
}
