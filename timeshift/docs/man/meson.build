help2man = find_program('help2man')

mans = [
  ['linuxrollback', [help2man, '-N', '--output=@OUTPUT@', linuxrollback]],
  ['linuxrollback-gtk', [help2man, '-N', '--output=@OUTPUT@', linuxrollback_gtk]],
]

foreach man: mans
  custom_target(
    man[0],
    output: man[0] + '.1',
    command: man[1],
    install: true,
    install_dir: join_paths(get_option('mandir'), 'man1'),
  )
endforeach

