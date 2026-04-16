#!/usr/bin/env bash

DB_NAME=... DB_USER=... DB_PWD=... \
TOKEN_SECRET='...' MUD_LANG=... MUD_WIZPWD=... \
perl ./cgi.pl 2>err.log
