rm -f gamedata.*
rm -f _test.json
rm -f _game.log
export MUD_WIZPWD=JE0PPA
export MUD_LANG=ru
perl ../cli.pl 13 'load _demo-set.txt'
perl -CA ../cli.pl 13 'огл; з; з; з; вв; з; вн; юз; имя Зая Заи Зае Заю Заей Зае; верно; жен; ятакая Просто Красавица'
