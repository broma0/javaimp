#!/bin/sh

# TODO: Figure out a real command line interface
# testing framework (expect maybe?) and
# implement tests

cd "$(dirname "$0")"

LUA_INTERP="$(luarocks config lua_interpreter)"
LUA_PATH="./src/?.lua;$LUA_PATH"

run()
{
  # rm javaimp.db

  echo
  # TODO: use busted for this

  # Update index
  $LUA_INTERP ../src/javaimp/cli.lua -i javaimp.db update m2

  # Cat everything in the index
  $LUA_INTERP ../src/javaimp/cli.lua -i javaimp.db find "rest"

  # TODO: Add import
  # $LUA_INTERP ../javaimp.lua -i javaimp.db -a RestController

  # TODO:
  #  | fzf <select completion or import>
}

if [ "$1" = "iterate" ]
then

  while true; do
    run
    inotifywait -qqr ../src \
      -e modify \
      -e close_write
  done

else

  run

fi
