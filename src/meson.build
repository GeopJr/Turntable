sources += configure_file(
    input : 'Build.vala.in',
    output : 'Build.vala',
    configuration : config
)

sources += files(
    'Application.vala'
)

subdir('Mpris')
if scrobbling
  subdir('Scrobbling')
endif
subdir('Utils')
subdir('Views')
subdir('Widgets')
