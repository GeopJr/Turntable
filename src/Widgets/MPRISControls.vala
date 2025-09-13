public class Turntable.Widgets.MPRISControls : Gtk.Grid {
	public enum Command {
		PREVIOUS,
		PLAY_PAUSE,
		NEXT,
		SHUFFLE,
		LOOP_NONE,
		LOOP_TRACK,
		LOOP_PLAYLIST;
	}
	public signal void commanded (Command command);

	public class StatefulLoopButton : Gtk.Button {
		// this is the command to trigger when clicked
		public Command next_command { get; private set; default = Command.LOOP_PLAYLIST; }

		public Mpris.Entry.LoopStatus loop_status {
			set {
				switch (value) {
					case NONE:
						// translators: repeat = loop, tooltip text
						this.tooltip_text = _("No Repeat");
						this.icon_name = "playlist-consecutive-symbolic";
						this.next_command = LOOP_PLAYLIST;
						break;
					case PLAYLIST:
						// translators: repeat = loop, tooltip text
						this.tooltip_text = _("Repeat Playlist");
						this.icon_name = "playlist-repeat-symbolic";
						this.next_command = LOOP_TRACK;
						break;
					case TRACK:
						// translators: repeat = loop, track = song, tooltip text
						this.tooltip_text = _("Repeat Track");
						this.icon_name = "playlist-repeat-song-symbolic";
						this.next_command = LOOP_NONE;
						break;
					default:
						assert_not_reached ();
				}
			}
		}

		construct {
			this.loop_status = NONE;
		}
	}

	public bool playing {
		set {
			button_play.icon_name = value ? "pause-large-symbolic" : "play-large-symbolic";
			// translators: button tooltip text
			button_play.tooltip_text = value ? _("Pause") : _("Play");
		}
	}

	public bool can_control {
		set {
			button_play.sensitive =
			button_loop.sensitive =
			button_shuffle.sensitive = value;

			if (!value) {
				button_prev.sensitive =
				button_next.sensitive = false;
			}
		}
	}

	public bool can_go_back {
		set {
			button_prev.sensitive = value;
		}
	}

	public bool can_go_next {
		set {
			button_next.sensitive = value;
		}
	}

	public bool shuffle {
		set {
			button_shuffle.active = value;
		}
	}

	public Mpris.Entry.LoopStatus loop_status {
		set {
			button_loop.loop_status = value;
		}
	}

	public bool more_controls {
		set {
			button_loop.visible =
			button_shuffle.visible = value;
		}
	}

	public void grab_play_focus () {
		button_play.grab_focus ();
	}

	bool _newline = false;
	public bool newline {
		get { return _newline; }
		set {
			if (_newline == value) return;
			_newline = value;

			Gtk.GridLayout layout_manager = (Gtk.GridLayout) this.get_layout_manager ();
			Gtk.GridLayoutChild button_shuffle_layout_child = (Gtk.GridLayoutChild) layout_manager.get_layout_child (button_shuffle);
			Gtk.GridLayoutChild button_prev_layout_child = (Gtk.GridLayoutChild) layout_manager.get_layout_child (button_prev);
			Gtk.GridLayoutChild button_play_layout_child = (Gtk.GridLayoutChild) layout_manager.get_layout_child (button_play);
			Gtk.GridLayoutChild button_next_layout_child = (Gtk.GridLayoutChild) layout_manager.get_layout_child (button_next);
			Gtk.GridLayoutChild button_loop_layout_child = (Gtk.GridLayoutChild) layout_manager.get_layout_child (button_loop);

			if (value) {
				button_shuffle_layout_child.column = 0;
				button_shuffle_layout_child.row = 1;

				button_prev_layout_child.column = 0;
				button_prev_layout_child.row = 0;

				button_play_layout_child.column = 1;
				button_play_layout_child.row = 0;

				button_next_layout_child.column = 2;
				button_next_layout_child.row = 0;

				button_loop_layout_child.column = 2;
				button_loop_layout_child.row = 1;
			} else {
				button_shuffle_layout_child.column = 0;
				button_shuffle_layout_child.row = 0;

				button_prev_layout_child.column = 1;
				button_prev_layout_child.row = 0;

				button_play_layout_child.column = 2;
				button_play_layout_child.row = 0;

				button_next_layout_child.column = 3;
				button_next_layout_child.row = 0;

				button_loop_layout_child.column = 4;
				button_loop_layout_child.row = 0;
			}
		}
	}

	Gtk.Button button_play;
	Gtk.Button button_prev;
	Gtk.Button button_next;
	StatefulLoopButton button_loop;
	Gtk.ToggleButton button_shuffle;
	construct {
		this.column_spacing =
		this.row_spacing = 8;

		button_shuffle = new Gtk.ToggleButton () {
			icon_name = "playlist-shuffle-symbolic",
			halign = Gtk.Align.CENTER,
			valign = Gtk.Align.CENTER,
			// translators: button tooltip text
			tooltip_text = _("Shuffle")
		};
		button_shuffle.add_css_class ("circular");
		this.attach (button_shuffle, 0, 0);

		button_prev = new Gtk.Button.from_icon_name (is_rtl ? "skip-forward-large-symbolic" : "skip-backward-large-symbolic") {
			css_classes = {"circular"},
			halign = Gtk.Align.CENTER,
			valign = Gtk.Align.CENTER,
			// translators: button tooltip text
			tooltip_text = _("Previous Song")
		};
		this.attach (button_prev, 1, 0);

		button_play = new Gtk.Button.from_icon_name ("play-large-symbolic") {
			css_classes = {"circular", "large"},
			halign = Gtk.Align.CENTER,
			valign = Gtk.Align.CENTER,
			tooltip_text = _("Play")
		};
		this.attach (button_play, 2, 0);

		button_next = new Gtk.Button.from_icon_name (is_rtl ? "skip-backward-large-symbolic" : "skip-forward-large-symbolic") {
			css_classes = {"circular"},
			halign = Gtk.Align.CENTER,
			valign = Gtk.Align.CENTER,
			// translators: button tooltip text
			tooltip_text = _("Next Song")
		};
		this.attach (button_next, 3, 0);

		button_loop = new StatefulLoopButton () {
			css_classes = {"circular"},
			halign = Gtk.Align.CENTER,
			valign = Gtk.Align.CENTER
		};
		this.attach (button_loop, 4, 0);

		button_next.clicked.connect (play_next);
		button_play.clicked.connect (play_pause);
		button_prev.clicked.connect (play_back);
		button_shuffle.clicked.connect (toggle_shuffle);
		button_loop.clicked.connect (loop_update);
	}

	private void loop_update () {
		commanded (button_loop.next_command);
	}

	private void toggle_shuffle () {
		// hack for togglebutton being checked regardless on clicked
		button_shuffle.active = !button_shuffle.active;
		commanded (Command.SHUFFLE);
	}

	private void play_next () {
		commanded (Command.NEXT);
	}

	private void play_pause () {
		commanded (Command.PLAY_PAUSE);
	}

	private void play_back () {
		commanded (Command.PREVIOUS);
	}
}
