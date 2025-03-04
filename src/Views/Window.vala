public class Turntable.Views.Window : Adw.ApplicationWindow {
	public string? song_title {
		set {
			title_label.content = value == null ? _("No Title") : value;
		}
	}

	public string? artist {
		set {
			artist_label.content = value == null ? _("No Artist") : value;
		}
	}

	public string? album {
		set {
			album_label.content = value == null ? _("No Album") : value;
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
			_position = value;
			prog.progress = (double)value / (double)this.length;
		}
	}

	private int64 _length = 0;
	public int64 length {
		get { return _length; }
		set {
			// FIXME: length can be 0
			_length = value;
			prog.progress = (double)this.position / (double)value;
		}
	}

	public bool playing {
		set {
			art_pic.turntable_playing = value;
			button_play.icon_name = value ? "media-playback-pause-symbolic" : "media-playback-start-symbolic";
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
				break;
			default:
				this.default_width = 534;
				this.default_height = 0;
				break;
		}

		art_pic.orientation =
		main_box.orientation =
		prog.orientation = this.orientation;
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
			child = main_box
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
			foreach (var player in mpris_manager.players) {
				player.next ();
			}
		});

		button_play.clicked.connect (() => {
			foreach (var player in mpris_manager.players) {
				player.play_pause ();
			}
		});

		button_prev.clicked.connect (() => {
			foreach (var player in mpris_manager.players) {
				player.back ();
			}
		});

		foreach (var player in mpris_manager.players) {
			player.initialize_player ();
			player.bind_property ("title", this, "song-title", GLib.BindingFlags.SYNC_CREATE);
			player.bind_property ("artist", this, "artist", GLib.BindingFlags.SYNC_CREATE);
			player.bind_property ("album", this, "album", GLib.BindingFlags.SYNC_CREATE);
			player.bind_property ("art", this, "art", GLib.BindingFlags.SYNC_CREATE);
			player.bind_property ("position", this, "position", GLib.BindingFlags.SYNC_CREATE);
			player.bind_property ("length", this, "length", GLib.BindingFlags.SYNC_CREATE);
			player.bind_property ("playing", this, "playing", GLib.BindingFlags.SYNC_CREATE);
			player.bind_property ("can-go-next", button_next, "sensitive", GLib.BindingFlags.SYNC_CREATE);
			player.bind_property ("can-go-back", button_prev, "sensitive", GLib.BindingFlags.SYNC_CREATE);
		}

		update_orientation ();

		this.content = new Gtk.WindowHandle () {
			child = prog
		};

		//  GLib.Timeout.add (250, () => {
		//  	art_pic.turntable = true;
		//  	return GLib.Source.REMOVE;
		//  });
	}
}
