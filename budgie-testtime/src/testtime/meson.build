
custom_target('plugin-file-testtime',
    input : 'TestTime.plugin.in',
    output : 'TestTime.plugin',
    command : [intltool, '--desktop-style', podir, '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir : LIB_INSTALL_DIR)

BudgieTestTimeSources = [
'BudgieTestTime.vala'
]

BudgieTestTimeDependencies = [
dependency('gtk+-3.0'),
dependency('budgie-1.0'),
dependency('gio-2.0'),
dependency('gdk-3.0'),
dependency('libwnck-3.0'),
meson.get_compiler('c').find_library('m', required: false)
]

BudgieTestTimeValaArgs = [
'--pkg=config',
'--vapidir=' + VAPI_DIR,
'--target-glib=2.38',
]


BudgieTestTimeCArgs = [
'-lm',
'-DWNCK_I_KNOW_THIS_IS_UNSTABLE'
]

shared_library(
    'budgietesttime',
    BudgieTestTimeSources,
    dependencies: BudgieTestTimeDependencies,
    vala_args: BudgieTestTimeValaArgs,
    c_args: BudgieTestTimeCArgs,
    include_directories: config_inc_dir,
    install: true,
    install_dir: LIB_INSTALL_DIR
)




