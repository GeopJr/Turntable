icon_name = meson.project_name()
if get_option('devel')
  icon_name = ('@0@.Devel').format(icon_name)
endif

scalable_dir = 'hicolor' / 'scalable' / 'apps'
install_data(
  scalable_dir / ('@0@.svg').format(meson.project_name()),
  install_dir: get_option('datadir') / 'icons' / scalable_dir,
  rename: ('@0@.svg').format(icon_name)
)

symbolic_dir = 'hicolor' / 'symbolic' / 'apps'
install_data(
  symbolic_dir / ('@0@-symbolic.svg').format(meson.project_name()),
  install_dir: get_option('datadir') / 'icons' / symbolic_dir
)
