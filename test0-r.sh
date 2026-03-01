rm -f gamedata.sdbm.*
rm -f _test.json
export MUD_WIZPWD=JE0PPA
MUD_LANG=ru perl cli.pl 13 'wizpwd JE0PPA' <test-ru.txt
