public class Turntable.Views.ProviderPage : Adw.NavigationPage {
	public signal void errored (string error_message);
	protected Gtk.Button add_button { get; set; }
	protected Adw.PreferencesPage page { get; set; }
	public Soup.Session session { get; set; }

	construct {
		page = new Adw.PreferencesPage ();
		add_button = new Gtk.Button.with_label ("Continue") {
			sensitive = false,
			css_classes = {"pill", "suggested-action" },
			valign = Gtk.Align.CENTER,
			halign = Gtk.Align.CENTER,
			margin_top = 8,
			margin_bottom = 8
		};
		add_button.clicked.connect (on_continue);

		var toolbar_view = new Adw.ToolbarView () {
			content = page
		};
		toolbar_view.add_top_bar (new Adw.HeaderBar ());
		toolbar_view.add_bottom_bar (add_button);

		this.child = toolbar_view;
	}

	protected virtual void update_validity () {}
	protected virtual void on_continue () {}
}
