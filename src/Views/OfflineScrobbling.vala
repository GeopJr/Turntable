public class Turntable.Views.OfflineScrobbling : Adw.NavigationPage {
	public class PayloadObject : GLib.Object {
		public string track { get; private set; }
		public string artist { get; private set; }
		public string? album { get; private set; default = null; }
		public GLib.DateTime date { get; private set; }
		public string payload_string { get; private set; }

		public PayloadObject (string payload_string) {
			this.payload_string = payload_string;
			var parser = new Json.Parser ();
			try {
				parser.load_from_data (payload_string, -1);

				var root = parser.get_root ();
				if (root == null) assert_not_reached ();

				var obj = root.get_object ();
				if (obj == null) assert_not_reached ();
				if (!obj.has_member ("track") || !obj.has_member ("artist") || !obj.has_member ("date")) assert_not_reached ();

				this.track = obj.get_string_member ("track");
				this.artist = obj.get_string_member ("artist");
				if (obj.has_member ("album")) this.album = obj.get_string_member ("album");
				this.date = new GLib.DateTime.from_iso8601 (obj.get_string_member ("date"), null);
			} catch {
				assert_not_reached ();
			}
		}
	}

	public class PayloadRow : Adw.ActionRow {
		public signal void removed (PayloadObject payload);
		public unowned PayloadObject payload { get; private set; }

		construct {
			this.add_css_class ("card");

			Gtk.Button delete_button = new Gtk.Button.from_icon_name ("user-trash-symbolic") {
				valign = Gtk.Align.CENTER,
				halign = Gtk.Align.CENTER,
				// translators: tooltip on offline scrobbles row button
				tooltip_text = _("Remove Scrobble"),
				css_classes = { "flat", "error" }
			};
			delete_button.clicked.connect (on_delete);
			this.add_suffix (delete_button);
		}

		public void populate (PayloadObject payload_object) {
			this.payload = payload_object;
			this.title = payload_object.track;
			this.subtitle = "%s%s\n%s".printf (
				payload_object.artist,
				payload_object.album == null ? "" : @"- $(payload_object.album)",
				payload_object.date.format ("%B %e, %Y · %R").replace (" ", "")
			);
		}

		private void on_delete () {
			removed (this.payload);
		}
	}

	Gtk.Button sync_now;
	Gtk.ListView listview;
	Gtk.NoSelection selection;
	GLib.ListStore store;
	Gtk.Stack stack;
	construct {
		this.title = _("Offline Scrobbling");

		Gtk.SignalListItemFactory signallistitemfactory = new Gtk.SignalListItemFactory ();
		signallistitemfactory.setup.connect (setup_listitem_cb);
		signallistitemfactory.bind.connect (bind_listitem_cb);

		store = new GLib.ListStore (typeof (PayloadObject));
		selection = new Gtk.NoSelection (store);
		listview = new Gtk.ListView (selection, signallistitemfactory) {
			single_click_activate = false,
			overflow = VISIBLE
		};
		//  grid.activate.connect (on_item_activated);
		listview.remove_css_class ("view");
		listview.add_css_class ("clear-view");

		// translators: button label that submits offline scrobbles
		sync_now = new Gtk.Button.with_label ("Submit") {
			css_classes = { "suggested-action" }
		};
		sync_now.clicked.connect (sync_now_clicked);

		stack = new Gtk.Stack () {
			vexpand = true,
			hexpand = true
		};
		stack.add_named (
			new Gtk.ScrolledWindow () {
				child = new Adw.ClampScrollable () {
					child = listview,
					maximum_size = 568,
					tightening_threshold = 200,
					overflow = HIDDEN,
					vexpand = true
				}
			},
			"content"
		);

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
			new Adw.StatusPage () {
				icon_name = "background-app-ghost-symbolic",
				// translators: shown when there's 0 offline scrobbles in the queue
				title = _("No Offline Scrobbles")
			},
			"empty"
		);
		update_batch_in_progress ();

		var toolbar_view = new Adw.ToolbarView () {
			content = stack
		};

		var header = new Adw.HeaderBar ();
		header.pack_end (sync_now);
		toolbar_view.add_top_bar (header);

		this.child = toolbar_view;
		settings.notify["offline-scrobbling"].connect (update_sync_now_sensitivity);
		application.notify["batch-in-progress"].connect (update_batch_in_progress);
		store.items_changed.connect (on_store_changed);
		populate_list ();
	}

	private void update_batch_in_progress () {
		update_sync_now_sensitivity ();
		listview.sensitive = !application.batch_in_progress;

		if (application.batch_in_progress) {
			stack.visible_child_name = "loading";
		} else if (store.n_items > 0) {
			populate_list ();
			on_store_changed ();
		} else {
			stack.visible_child_name = "empty";
		}
	}

	private void sync_now_clicked () {
		scrobbling_manager.submit_offline_scrobbles ();
	}

	private void update_sync_now_sensitivity () {
		sync_now.sensitive = settings.offline_scrobbling && network_monitor.network_available && !application.batch_in_progress && store.n_items > 0;
	}

	private void setup_listitem_cb (GLib.Object obj) {
		Gtk.ListItem list_item = (Gtk.ListItem) obj;
		var row = new PayloadRow ();
		list_item.set_child (row);
	}

	private void bind_listitem_cb (GLib.Object item) {
		var payload_object = (PayloadObject) ((Gtk.ListItem) item).item;
		var widget = (PayloadRow) ((Gtk.ListItem) item).child;
		widget.populate (payload_object);
		widget.removed.connect (remove_scrobble);

		var gtklistitemwidget = widget.get_parent ();
		if (gtklistitemwidget != null) {
			gtklistitemwidget.remove_css_class ("activatable");
			gtklistitemwidget.margin_top =
			gtklistitemwidget.margin_bottom = 3;
		}
	}

	private void populate_list () {
		PayloadObject[] objects = {};
		string[] offline_scrobbles = settings.get_strv ("offline-scrobbles");
		foreach (string scrobble in offline_scrobbles) {
			objects += new PayloadObject (scrobble);
		}
		store.splice (0, store.n_items, objects);
		update_sync_now_sensitivity ();
	}

	private void remove_scrobble (PayloadObject payload) {
		uint pos;
		if (store.find (payload, out pos)) {
			store.remove (pos);
		}

		string[] offline_scrobbles = {};
		foreach (string offline_scrobble in settings.get_strv ("offline-scrobbles")) {
			if (offline_scrobble != payload.payload_string) offline_scrobbles += offline_scrobble;
		}
		settings.set_strv ("offline-scrobbles", offline_scrobbles);
		update_sync_now_sensitivity ();
	}

	private void on_store_changed () {
		stack.visible_child_name = store.n_items > 0 ? "content" : "empty";
	}
}
