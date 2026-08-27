#!/bin/sh
# Shared by Stagehand's POSIX Bolt tasks. The caller resolves $RUBY first.

json_escape() {
  printf '%s' "$1" | "$RUBY" -Eutf-8:utf-8 -rjson -e 'print JSON.generate(STDIN.read)'
}
