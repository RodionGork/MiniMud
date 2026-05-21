rm -f gamedata.*
rm -f _test.json
rm -f _game.log
export MUD_WIZPWD=JE0PPA
export MUD_LANG=ru
perl cli.pl 13 < _demo-set.txt
perl -CA cli.pl 13 'жен; имя Зая Заи Зае Заю; верно; в; вв'
