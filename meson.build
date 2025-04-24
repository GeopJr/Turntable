project('dev.geopjr.Turntable', ['c', 'vala'],
          version: '0.1.0',
    meson_version: '>= 1.0.0',
  default_options: [ 'warning_level=2', 'werror=false', ],
)

# https://gitlab.gnome.org/GNOME/vala/-/issues/1413#note_1707480
if meson.get_compiler ('c').get_id () == 'clang'
  add_project_arguments('-Wno-incompatible-function-pointer-types', language: 'c')
endif

devel = get_option('devel')

# Setup configuration file
config = configuration_data()
config.set('EXEC_NAME', meson.project_name())
config.set('GETTEXT_PACKAGE', meson.project_name())
config.set('LOCALEDIR', join_paths(get_option('prefix'), get_option('localedir')))
config.set('DOMAIN', meson.project_name ())
config.set('G_LOG_DOMAIN', 'Turntable')
config.set('RESOURCES', '/' + '/'.join(meson.project_name().split('.')) + '/')
config.set('VERSION', meson.project_version())
config.set('PREFIX', get_option('prefix'))
config.set('NAME', 'Turntable')
config.set('WEBSITE', 'https://turntable.geopjr.dev')
config.set('ISSUES_WEBSITE', 'https://codeberg.org/GeopJr/Turntable/issues')
config.set('DONATE_WEBSITE', 'https://geopjr.dev/donate')
config.set('TRANSLATE_WEBSITE', 'https://translate.codeberg.org/engage/turntable/')
config.set('PROFILE', devel ? 'development' : 'production')

config.set('LIBREFM_KEY', '778aa5b9a1a796dce785f1416ba7265a') # can be anything, 'Turntable' | md5sum
config.set('LIBREFM_SECRET', '7a4e4df2400597eb184eabe65dfc3310') # above | md5sum
if devel
  config.set('LASTFM_KEY', '7c7320be36b02ba3b8639ab6867c9471') # Devel key, will be renewed often, do not use in prod.
  config.set('LASTFM_SECRET', 'bc183481df70a23d23f7f145af61a3a6') # Devel key, will be renewed often, do not use in prod.
else
  config.set('LASTFM_KEY', get_option('lastfm_key'))
  config.set('LASTFM_SECRET', get_option('lastfm_secret'))
endif

if devel
  git = find_program('git')
  if git.found()
    branch = run_command('git', 'branch', '--show-current', check: true).stdout().strip()
    revision = run_command('git', 'rev-parse', '--short', 'HEAD', check: true).stdout().strip()
    version = '@0@-@1@'.format(branch, revision)
    config.set('VERSION', version)
  endif
endif

if host_machine.system() == 'windows'
  add_project_arguments(['--define=WINDOWS'], language: 'vala')
elif host_machine.system() == 'darwin'
  add_project_arguments(['--define=DARWIN'], language: 'vala')
endif

add_project_arguments (
  '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
  '-DG_LOG_DOMAIN="Turntable"',
  language: 'c'
)

i18n = import('i18n')
gnome = import('gnome')

asresources = gnome.compile_resources(
    'as-resources',
    'data/dev.geopjr.Turntable.gresource.xml',
    source_dir: 'data',
    c_name: 'as',
)

if get_option('sandboxed')
  add_project_arguments(['--define=SANDBOXED'], language: 'vala')
endif

scrobbling = false
libsoup_dep = dependency('libsoup-3.0', required: false)
json_glib_dep = dependency('json-glib-1.0', version: '>=1.4.4', required: false)
libsecret_dep = dependency('libsecret-1', required: false)

if get_option('scrobbling') and libsoup_dep.found () and json_glib_dep.found () and libsecret_dep.found ()
  scrobbling = true
  add_project_arguments(['--define=SCROBBLING'], language: 'vala')
endif

sources = files()
subdir('src')

final_deps = [
  dependency('glib-2.0', version: '>=2.76.0'),
  dependency('gtk4', version: '>=4.13.4', required: true),
  dependency('libadwaita-1', version: '>=1.5', required: true),
  dependency('gio-unix-2.0', required: true),
  libsoup_dep,
  json_glib_dep,
  libsecret_dep,
  meson.get_compiler('c').find_library('m', required: false)
]

executable(
    meson.project_name(),
    asresources,
    sources,
    dependencies: final_deps,
    install: true,
    win_subsystem: 'windows'
)

subdir('data')
subdir('po')

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)
