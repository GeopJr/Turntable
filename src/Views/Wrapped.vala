public class Turntable.Views.Wrapped : Adw.NavigationPage {
	~Wrapped () {
		debug ("Destroying");
	}

	enum Background {
		WINDOW,
		ACCENT,
		PRIDE,
		TRANS;

		public static Background from_string (string name) {
			switch (name.down ()) {
				case "accent": return ACCENT;
				case "pride": return PRIDE;
				case "trans": return TRANS;
				default: return WINDOW;
			}
		}

		public string to_string () {
			switch (this) {
				case ACCENT: return "style-accent";
				case PRIDE: return "style-pride";
				case TRANS: return "style-trans";
				default: return "style-window";
			}
		}
	}

	Background current_style = Background.WINDOW;
	private void on_change_style (GLib.SimpleAction action, GLib.Variant? value) {
		if (value == null) return;

		string current_style_class = current_style.to_string ();
		if (current_style_class != "" && this.has_css_class (current_style_class))
			this.remove_css_class (current_style_class);
		current_style = Background.from_string (value.get_string ());
		this.add_css_class (current_style.to_string ());
	}

	public class ProviderRow : Adw.ActionRow {
		public signal void selected (Scrobbling.Manager.Provider provider);

		Scrobbling.Manager.Provider provider;
		public ProviderRow (Scrobbling.Manager.Provider provider) {
			this.provider = provider;
			this.add_prefix (new Gtk.Image.from_icon_name (provider.to_icon_name ()) {
				icon_size = Gtk.IconSize.LARGE
			});
			this.add_suffix (new Gtk.Image.from_icon_name (Gtk.Widget.get_default_direction () == Gtk.TextDirection.RTL ? "left-large-symbolic" : "right-large-symbolic"));
			this.title = provider.to_string ();
			this.activatable = true;
			this.activated.connect (on_activate);
		}

		private void on_activate () {
			selected (this.provider);
		}

		~ProviderRow () {
			debug ("Destroying");
		}
	}

	Scrobbling.Manager.Provider? picked_provider = null;
	Gtk.Stack stack;
	Adw.StatusPage error_page;
	Gtk.Button try_again_button;
	Gtk.Button save_btn;
	Adw.Carousel carousel;
	GLib.Menu style_menu;
	Gtk.MenuButton style_button;
	construct {
		this.title = _("Wrapped");

		var actions = new SimpleActionGroup ();
		actions.add_action_entries (
			{
				{"change-style", on_change_style, "s"},
			},
			this
		);
		this.insert_action_group ("wrapped", actions);

		style_menu = new GLib.Menu ();
		style_menu.append (_("Default"), "wrapped.change-style('window')");
		// translators: Accent color
		style_menu.append (_("Accent"), "wrapped.change-style('accent')");
		style_menu.append ("Pride", "wrapped.change-style('pride')");
		style_menu.append ("Trans", "wrapped.change-style('trans')");

		// translators: button shown in error message that repeats the action that led to this
		try_again_button = new Gtk.Button.with_label (_("Try Again")) {
			css_classes = { "suggested-action", "pill" },
			halign = CENTER
		};
		try_again_button.clicked.connect (do_wrap);

		error_page = new Adw.StatusPage () {
			icon_name = "sad-computer-symbolic",
			// translators: error message with wrapped (as in Spotify wrapped see other comments on this)
			title = _("Couldn't generate Wrapped"),
			child = try_again_button
		};

		stack = new Gtk.Stack () {
			vexpand = true,
			hexpand = true
		};
		stack.add_named (
			new Adw.Spinner () {
				halign = CENTER,
				valign = CENTER,
				width_request = 48,
				height_request = 48
			},
			"loading"
		);

		stack.add_named (
			error_page,
			"error"
		);

		var toolbar_view = new Adw.ToolbarView () {
			content = stack
		};

		save_btn = new Gtk.Button.from_icon_name ("folder-download-symbolic") {
			// translators: as in save file
			tooltip_text = _("Save"),
			css_classes = {"suggested-action"},
			visible = false
		};
		save_btn.clicked.connect (on_save);

		style_button = new Gtk.MenuButton () {
			// translators: dropdown label for picking a window style in Wrapped experiment
			label = _("Style"),
			menu_model = style_menu,
			visible = false
		};

		var header = new Adw.HeaderBar ();
		header.pack_end (save_btn);
		header.pack_start (style_button);
		toolbar_view.add_top_bar (header);
		this.child = toolbar_view;

		var eligible_providers = scrobbling_manager.get_providers_with_experiment (WRAPPED);
		if (eligible_providers.length == 0) {
			// translators: error message shown when trying to generate a Wrapped
			//				but none of the accounts have the necessary functions
			show_error_page (_("Unfortunately, you don't have any eligible accounts"), false);
		} else if (eligible_providers.length == 1) {
			picked_provider = eligible_providers[0];
			do_wrap ();
		} else {
			var chooser_group = new Adw.PreferencesGroup () {
				// translators: services as in "Scrobbling Services", if it's easier,
				//				translate it into "Platforms" or "Providers"
				title = _("Service"),
				// translators: description of a group of rows, services as in "Scrobbling Services",
				//				if it's easier, translate it into "Platforms" or "Providers", wrapped
				//				as in Spotify Wrapped
				description = _("Choose which service to use for generating your Wrapped")
			};

			foreach (var provider in eligible_providers) {
				var row = new ProviderRow (provider);
				row.selected.connect (on_row_activated);
				chooser_group.add (row);
			}

			stack.add_named (
				new Gtk.ScrolledWindow () {
					child = new Adw.Clamp () {
						child = chooser_group,
						maximum_size = 568,
						tightening_threshold = 200,
						overflow = HIDDEN,
						vexpand = true
					}
				},
				"chooser"
			);
			stack.visible_child_name = "chooser";
		}
	}

	private void on_row_activated (Scrobbling.Manager.Provider provider) {
		this.picked_provider = provider;
		do_wrap ();
	}

	private void do_wrap () {
		stack.visible_child_name = "loading";

		if (!network_monitor.network_available) {
			// translators: error description when the user is not connected to the internet
			show_error_page (_("You are currently offline"));
			return;
		} else if (picked_provider == null) {
			show_error_page ("You shouldn't be seeing this, open an issue");
			return;
		}

		scrobbling_manager.wrapped.begin (picked_provider, account_manager.accounts.get (picked_provider.to_string ()).username, 5, (obj, res) => {
			try {
				generate_wrapped (scrobbling_manager.wrapped.end (res));
			} catch (Error e) {
				show_error_page (e.message);
			}
		});
	}

	// https://github.com/GeopJr/Tuba/blob/main/src/Widgets/FocusPicture.vala
	public class SizedCoverPicture : Gtk.Widget, Gtk.Buildable, Gtk.Accessible {
		ulong paintable_invalidate_contents_signal = 0;
		ulong paintable_invalidate_size_signal = 0;

		Gdk.Paintable? _paintable = null;
		public Gdk.Paintable? paintable {
			get { return _paintable; }
			set {
				if (_paintable == value) return;
				bool size_changed = paintable_size_equal (value);
				clear_paintable ();

				_paintable = value;
				if (_paintable != null) {
					Gdk.PaintableFlags flags = _paintable.get_flags ();
					if (!(Gdk.PaintableFlags.STATIC_CONTENTS in flags))
						paintable_invalidate_contents_signal = _paintable.invalidate_contents.connect (paintable_invalidate_contents);

					if (!(Gdk.PaintableFlags.STATIC_SIZE in flags))
						paintable_invalidate_size_signal = _paintable.invalidate_size.connect (paintable_invalidate_size);
				}

				if (size_changed) {
					this.queue_resize ();
				} else {
					this.queue_draw ();
				}
			}
		}

		static construct {
			set_css_name ("picture");
			set_accessible_role (Gtk.AccessibleRole.IMG);
		 }

		construct {
			this.overflow = Gtk.Overflow.HIDDEN;
		}

		public override Gtk.SizeRequestMode get_request_mode () {
			return Gtk.SizeRequestMode.CONSTANT_SIZE;
		}

		public override void snapshot (Gtk.Snapshot snapshot) {
			if (_paintable == null) return;

			int width = this.get_width ();
			int height = this.get_height ();
			double ratio = _paintable.get_intrinsic_aspect_ratio ();

			if (ratio == 0) {
				_paintable.snapshot (snapshot, width, height);
			} else {
				double w = 0.0;
				double h = 0.0;
				double picture_ratio = (double) width / height;

				if (ratio > picture_ratio) {
					w = height * ratio;
					h = height;
				} else {
					w = width;
					h = width / ratio;
				}

				w = Math.ceil (w);
				h = Math.ceil (h);

				double x = (width - w) / 2;
				double y = Math.floor (height - h) / 2;

				snapshot.save ();
				snapshot.translate (Graphene.Point () { x = (float) x, y = (float) y });
				_paintable.snapshot (snapshot, w, h);
				snapshot.restore ();
			}
		}

		public override void measure (
			Gtk.Orientation orientation,
			int for_size,
			out int minimum,
			out int natural,
			out int minimum_baseline,
			out int natural_baseline
		) {
			minimum_baseline = -1;
			natural_baseline = -1;

			if (_paintable == null || for_size == 0) {
				minimum = 0;
				natural = 0;
				return;
			}

			minimum = natural = 168;
		}

		private void paintable_invalidate_contents () {
			this.queue_draw ();
		}

		private void paintable_invalidate_size () {
			this.queue_resize ();
		}

		private void clear_paintable () {
			if (_paintable == null) return;

			if (paintable_invalidate_contents_signal != 0) _paintable.disconnect (paintable_invalidate_contents_signal);
			if (paintable_invalidate_size_signal != 0) _paintable.disconnect (paintable_invalidate_size_signal);

			paintable_invalidate_contents_signal = 0;
			paintable_invalidate_size_signal = 0;

			_paintable = null;
		}

		private bool paintable_size_equal (Gdk.Paintable? new_paintable) {
			if (_paintable == null) {
				return new_paintable == null;
			} else if (new_paintable == null) {
				return false;
			}

			return
				_paintable.get_intrinsic_width () == new_paintable.get_intrinsic_width ()
				&& _paintable.get_intrinsic_height () == new_paintable.get_intrinsic_height ()
				&& _paintable.get_intrinsic_aspect_ratio () == new_paintable.get_intrinsic_aspect_ratio ();
		}

		~SizedCoverPicture () {
			debug ("Destroying");
			clear_paintable ();
		}
	}

	public class PageBox : Adw.Bin {
		public string file_suffix { get; set; default = ""; }
		public string? mbid { get; set; default = null; }
		public string kind { get; set; default = "release"; }

		~PageBox () {
			debug ("Destroying");
		}

		Gtk.Label title_label;
		Gtk.Label desc_label;
		Gtk.Box box;
		SizedCoverPicture pic;
		construct {
			this.add_css_class ("pagebox");
			box = new Gtk.Box (VERTICAL, 0) {
				vexpand = true,
				hexpand = true,
				valign = CENTER,
				margin_top = margin_bottom = margin_start = margin_end = 16
			};

			title_label = new Gtk.Label ("") {
				css_classes = { "title-1" },
				wrap_mode = WORD_CHAR,
				wrap = true,
				lines = 3,
				ellipsize = END,
				justify = CENTER,
				use_markup = false
			};

			desc_label = new Gtk.Label ("") {
				css_classes = { "title-4", "body" },
				wrap_mode = WORD_CHAR,
				wrap = true,
				lines = 4,
				ellipsize = END,
				justify = CENTER,
				use_markup = true
			};

			pic = new SizedCoverPicture () {
				visible = false,
				width_request = 168,
				height_request = 168,
				halign = CENTER,
				valign = CENTER,
				overflow = HIDDEN,
				margin_bottom = 16,
				css_classes = {"card", "clear-view"}
			};

			box.append (pic);
			box.append (title_label);
			box.append (desc_label);
			this.child = box;
		}

		public PageBox (string title, string description, Gtk.Widget? child = null, string? cover = null) {
			if (title == "") {
				title_label.visible = false;
			} else {
				title_label.label = title;
			}

			if (description == "") {
				desc_label.visible = false;
			} else {
				desc_label.label = description;
			}

			if (child != null) box.append (child);
			if (cover != null) fetch_cover (cover);
		}

		private Widgets.Cover.CoverLoader? working_loader = null;
		private void fetch_cover (string cover) {
			working_loader = new Widgets.Cover.CoverLoader (cover);
			working_loader.done.connect (load_paintable);
			working_loader.done_completely.connect (done_completely_cb);
			try {
				new GLib.Thread<void>.try (@"CoverLoader $cover", working_loader.fetch);
			} catch (Error e) {
				warning (@"Couldn't fetch cover ($cover) for wrapped: $(e.message) $(e.code)");
			};
		}

		private bool tried = false;
		private void load_paintable (owned Gdk.Texture? texture) {
			pic.paintable = (owned) texture;
			if (pic.paintable != null) {
				pic.visible = true;
			} else if (!tried && mbid != null) {
				force_fetch_mbid ();
			}
		}

		private void done_completely_cb (owned Utils.Color.ExtractedColors? extracted_colors) {
			working_loader = null;
		}

		private async void fetch_from_mbid (string mbid, string kind) {
			Soup.Session session = new Soup.Session () {
				user_agent = @"$(Build.NAME)/$(Build.VERSION) libsoup/$(Soup.get_major_version()).$(Soup.get_minor_version()).$(Soup.get_micro_version()) ($(Soup.MAJOR_VERSION).$(Soup.MINOR_VERSION).$(Soup.MICRO_VERSION))" // vala-lint=line-length
			};
			var cover_url = yield Scrobbling.ListenBrainz.fetch_cover_from_wiki (session, mbid, kind);
			if (cover_url != null) fetch_cover (cover_url);
		}

		public void force_fetch_mbid () {
			tried = true;
			if (mbid == null) return;
			fetch_from_mbid.begin (mbid, kind);
		}
	}

	private void generate_wrapped (Scrobbling.Scrobbler.Wrapped wrapped) {
		if (
			wrapped.tracks == null
			|| wrapped.artists == null
			|| wrapped.tracks.length == 0
			|| wrapped.artists.length == 0
		) {
			// translators: error message shown on wrapped when theres not enough info to generate one
			show_error_page (_("Not enough info available, go and scrobble some more!"));
			return;
		} else {
			stack.visible_child_name = "loading";
		}

		var box = new Gtk.Box (VERTICAL, 0);
		carousel = new Adw.Carousel () {
			vexpand = true,
			hexpand = true,
			allow_long_swipes = false,
			allow_scroll_wheel = false
		};
		var dots = new Adw.CarouselIndicatorLines () {
			carousel = carousel
		};
		box.append (dots);
		box.append (carousel);

		var page_1 = new PageBox (
			// translators: wrapped page 1, fun title, feel free to change it something similar in your language
			_("What a year, huh?"),
			// translators: wrapped page 1 description
			_("Let's rewind the year!")
		) {
			vexpand = true,
			hexpand = true,
			file_suffix = "welcome"
		};
		carousel.append (page_1);

		string? stat_art = null;
		string? stat_mbid = null;
		string? stat_kind = null;
		if (wrapped.albums != null && wrapped.albums.length > 0) {
			var top_album = wrapped.albums[0];
			string? cover = top_album.image;
			if (cover == null) cover = top_album.id == null ? null : @"https://coverartarchive.org/release-group/$(top_album.id)/front-250.jpg";
			stat_art = cover;
			stat_mbid = top_album.id;
			// translators: how many times you listened to **something** in wrapped, variable is a number
			string desc = top_album.count == 0 ? "" : _("You listened to it %lld times!").printf (top_album.count);
			var page_2 = new PageBox (
				top_album.text,
				"<b>%s</b>\n%s".printf (
					// translators: number 1 album shown in wrapped
					_("#1 Album"),
					desc
				),
				null,
				stat_art
			) {
				vexpand = true,
				hexpand = true,
				file_suffix = "album",
				mbid = top_album.id
			};
			carousel.append (page_2);
		}

		if (wrapped.tracks != null && wrapped.tracks.length > 0) {
			var top_track = wrapped.tracks[0];
			string desc = top_track.count == 0 ? "" : _("You listened to it %lld times!").printf (top_track.count);
			string? cover = top_track.image;
			if (cover == null) cover = top_track.id == null ? null : @"https://coverartarchive.org/release/$(top_track.id)/front-250.jpg";
			stat_art = cover;
			stat_mbid = top_track.id;
			var page_3 = new PageBox (
				top_track.text,
				"<b>%s</b>\n%s".printf (
					// translators: number 1 song shown in wrapped
					_("#1 Track"),
					desc
				),
				null,
				cover
			) {
				vexpand = true,
				hexpand = true,
				file_suffix = "track",
				mbid = top_track.id
			};
			if (picked_provider == LASTFM) stat_kind = page_3.kind = "artist";
			carousel.append (page_3);
		}

		if (wrapped.artists != null && wrapped.artists.length > 0) {
			var top_artist = wrapped.artists[0];
			// how many times you listened to **someone** in wrapped, variable is a number
			string desc = top_artist.count == 0 ? "" : _("You listened to them %lld times!").printf (top_artist.count);
			var page_4 = new PageBox (
				top_artist.text,
				"<b>%s</b>\n%s".printf (
					// translators: number 1 artist shown in wrapped
					_("#1 Artist"),
					desc
				),
				null,
				top_artist.image
			) {
				vexpand = true,
				hexpand = true,
				file_suffix = "artist",
				mbid = top_artist.id,
				kind = "artist"
			};
			page_4.force_fetch_mbid ();
			carousel.append (page_4);
		}

		var columns = new Gtk.Box (HORIZONTAL, 12) {
			halign = CENTER
		};
		if (wrapped.tracks != null && wrapped.tracks.length > 0) {
			var col_1 = new Gtk.Box (VERTICAL, 0);
			col_1.append (new Gtk.Label (_("Top Tracks")) { wrap = true, wrap_mode = WORD_CHAR, css_classes = {"title-4"}, margin_bottom = 8 });

			int i = 0;
			foreach (var track in wrapped.tracks) {
				i++;
				col_1.append (new Gtk.Label (@"$i. $(track.text)") { wrap = true, wrap_mode = WORD_CHAR, ellipsize = END, halign = START });
			}
			columns.append (col_1);
		}

		if (wrapped.artists != null && wrapped.artists.length > 0) {
			var col_2 = new Gtk.Box (VERTICAL, 0);
			col_2.append (new Gtk.Label (_("Top Artists")) { wrap = true, wrap_mode = WORD_CHAR, css_classes = {"title-4"}, margin_bottom = 8 });

			int i = 0;
			foreach (var artist in wrapped.artists) {
				i++;
				col_2.append (new Gtk.Label (@"$i. $(artist.text)") { wrap = true, wrap_mode = WORD_CHAR, ellipsize = END, halign = START });
			}
			columns.append (col_2);
		}

		var page_5 = new PageBox (
			"",
			"",
			columns,
			stat_art
		) {
			vexpand = true,
			hexpand = true,
			file_suffix = "overall",
			mbid = stat_mbid
		};
		if (stat_kind != null) page_5.kind = stat_kind;
		carousel.append (page_5);

		var page_6 = new PageBox (
			// translators: wrapped page 6, fun title, feel free to change it something similar in your language
			_("That's all folks!"),
			// translators: wrapped page 6 description
			_("Keep scrobbling!")
		) {
			vexpand = true,
			hexpand = true,
			file_suffix = "goodbye"
		};
		carousel.append (page_6);


		stack.add_named (box, "wrapped");
		stack.visible_child_name = "wrapped";
		save_btn.visible = true;
		style_button.visible = true;
	}

	private Gdk.Texture? snap () {
		Gtk.Widget wdgt = carousel.get_nth_page ((uint) carousel.position);
		Gtk.WidgetPaintable screenshot_paintable = new Gtk.WidgetPaintable (wdgt);

		int width = wdgt.get_width ();
		int height = wdgt.get_height ();
		if (int.min (width, height) < 512) {
			if (width < height) {
				height = (int) (((float) height / (float) width) * 512);
				width = 512;
			} else {
				width = (int) (((float) width / (float) height) * 512);
				height = 512;
			}
		}

		Graphene.Rect rect = Graphene.Rect.zero ();
		rect.init (0, 0, (float) width, (float) height);

		Gtk.Snapshot snapshot = new Gtk.Snapshot ();
		screenshot_paintable.snapshot (snapshot, width, height);

		Gsk.RenderNode? node = snapshot.to_node ();
		if (node == null) {
			critical (@"Could not get node snapshot, width: $width, height: $height");
			return null;
		}

		Gsk.Renderer renderer = wdgt.get_native ().get_renderer ();
		return renderer.render_texture (node, rect);
	}

	private void on_save () {
		save_as_async.begin ();
	}

	private async void save_as_async () {
		string suff = "";
		{
			PageBox page = carousel.get_nth_page ((uint) carousel.position) as PageBox;
			if (page != null) {
				suff = page.file_suffix;
				if (suff != "") suff = @"-$suff";
			}
		}

		var chooser = new Gtk.FileDialog () {
			// translators: save dialog title, refer to the other Wrapped strings for more info
			title = _("Save Wrapped"),
			modal = true,
			initial_name = @"wrapped$suff.png"
		};

		try {
			var file = yield chooser.save (application.active_window, null);
			if (file != null) {
				var texture = snap ();
				if (texture != null) {
					FileOutputStream stream = file.replace (null, false, FileCreateFlags.PRIVATE);
					try {
						yield stream.write_bytes_async (texture.save_to_png_bytes ());
					} catch (GLib.IOError e) {
						warning (e.message);
					}
				}
			}
		} catch (Error e) {
			// User dismissing the dialog also ends here so don't make it sound like
			// it's an error
			warning (@"Couldn't get the result of FileDialog for wrapped: $(e.message)");
		}
	}

	private void show_error_page (string error, bool with_try_again = true) {
		error_page.description = error;
		try_again_button.visible = with_try_again;
		stack.visible_child_name = "error";
		debug (error);
	}
}
