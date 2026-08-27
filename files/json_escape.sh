#!/bin/sh
# Shared by Stagehand's POSIX Bolt tasks. The caller resolves $RUBY first.

json_escape() {
  printf '%s' "$1" | "$RUBY" -rjson -e 'print JSON.generate(STDIN.read)'
}
