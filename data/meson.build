install_data(
    meson.project_name() + '.gschema.xml',
    install_dir: join_paths(
        get_option('prefix'),
        get_option('datadir'),
        'glib-2.0',
        'schemas',
    ),
)

desktop_file = i18n.merge_file(
    input: meson.project_name() + '.desktop.in',
    output: meson.project_name() + '.desktop',
    po_dir: join_paths(meson.project_source_root(), 'po'),
    type: 'desktop',
    install: true,
    install_dir: join_paths(get_option('datadir'), 'applications'),
)

desktop_utils = find_program('desktop-file-validate', required: false)
if desktop_utils.found()
    test('Validate desktop file', desktop_utils, args: [desktop_file])
endif

if host_machine.system() != 'windows' and host_machine.system() != 'darwin'
    appstream_file = i18n.merge_file(
        input: meson.project_name() + '.metainfo.xml.in',
        output: meson.project_name() + '.metainfo.xml',
        po_dir: join_paths(meson.project_source_root(), 'po'),
        install: true,
        install_dir: join_paths(get_option('datadir'), 'metainfo'),
    )

    appstream_util = find_program('appstream-util', required: false)
    if appstream_util.found()
        test(
            'Validate appstream file',
            appstream_util,
            args: ['validate-relax', '--nonet', appstream_file],
        )
    endif
endif

subdir('icons')
