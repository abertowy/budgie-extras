
BudgieTestTimeSources = [
'testtime_desktop.vala'
]

BudgieTestTimeDependencies = [
dependency('libwnck-3.0'),
dependency('gtk+-3.0'),
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

executable(
    'testtime_desktop', BudgieTestTimeSources,
    dependencies: BudgieTestTimeDependencies,
    install: true,
    vala_args: BudgieTestTimeValaArgs,
    c_args: BudgieTestTimeCArgs,
    include_directories: config_inc_dir,
    install_dir: LIB_INSTALL_DIR,
)

