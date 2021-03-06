#!/usr/bin/env fish
set -x ROBOT_HOME (realpath (dirname (status -f)))
set -x LUA_PATH "$ROBOT_HOME/luajit-?/?.lua;$ROBOT_HOME/lua-?/?.lua;;"
# set -x LUA_PATH "$ROBOT_HOME/?/init.lua;$ROBOT_HOME/?/ffi.lua;;"
set -x LUA_CPATH "$ROBOT_HOME/lua-?/?.so;;"
set -x LCM_DEFAULT_URL "udpm://239.255.65.56:6556?ttl=0"

# Set to 2^23 bytes
set MAXSOCKBUF_LCM 8388608
set MAXSOCKBUF (sysctl -n kern.ipc.maxsockbuf)
test ! $MAXSOCKBUF -eq $MAXSOCKBUF_LCM ; and sudo sysctl -w kern.ipc.maxsockbuf=$MAXSOCKBUF_LCM

# Set to 2^21 bytes
set RECVSPACE_LCM 2097152
set RECVSPACE (sysctl -n net.inet.udp.recvspace)
test ! $RECVSPACE -eq $RECVSPACE_LCM ; and sudo sysctl -w net.inet.udp.recvspace=$RECVSPACE_LCM

# Set to 2^16 bytes
set MAXDGRAM_LCM 65535
set MAXDGRAM (sysctl -n net.inet.udp.maxdgram)
test ! $MAXDGRAM -eq $MAXDGRAM_LCM ; and sudo sysctl -w net.inet.udp.maxdgram=$MAXDGRAM_LCM

# For managing the routes as the interfaces change...
# sudo route add -net 224.0.0.0 -interface lo0 240.0.0.0
# sudo route del -net 224.0.0.0 -interface lo0 240.0.0.0
# sudo route change -net 224.0.0.0 -interface en4 240.0.0.0

set -x DYLD_LIBRARY_PATH "$DYLD_LIBRARY_PATH:$ROBOT_HOME/luajit-skt:$ROBOT_HOME/luajit-proj"