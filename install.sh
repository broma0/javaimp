#!/bin/sh

set -e

LUA_ENV=$(luarocks path)
LUA_INTERP=$(luarocks config lua_interpreter)
LUA_LUADIR=$(luarocks config deploy_lua_dir)
LUA_BINDIR=$(luarocks config deploy_bin_dir)

luarocks build

mkdir -p ${LUA_BINDIR}
cat > ${LUA_BINDIR}/javaimp <<EOF
#!/bin/sh
$LUA_ENV
$LUA_INTERP $LUA_LUADIR/javaimp/cli.lua "\$@"
EOF

chmod +x ${LUA_BINDIR}/javaimp

echo Installed to ${LUA_BINDIR}/javaimp
echo Make sure it is on your PATH
