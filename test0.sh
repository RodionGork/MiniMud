rm -f gamedata.sdbm.*
rm -f _test.json
export MUD_WIZPWD=JE0PPA
perl cli.pl 13 'ready; wizpwd JE0PPA' <test.txt
