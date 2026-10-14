rm -f gamedata.*
rm -f _test.json
export MUD_WIZPWD=JE0PPA
export MUD_LANG=ru
perl ../cli.pl 13 'load test-ru.txt'
perl ../cli.pl 14 'load test2-ru.txt'
perl ../cli.pl 13 <<END
quit
END
