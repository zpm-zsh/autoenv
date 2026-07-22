#!/usr/bin/env zsh
#
# The suites elsewhere put functions/ on fpath themselves, so they would not
# notice the plugin's own entry point failing to do it. These load through
# autoenv.plugin.zsh the way a user would.

emulate -L zsh

local here=${0:A:h}
local plugin=${AUTOENV_TEST_PLUGIN:-${here:h}}
local -i failed=0

check() {
  local label=$1 want=$2 got=$3
  if [[ "$want" == "$got" ]]; then
    print "PASS  $label"
  else
    print "FAIL  $label -- want '$want' got '$got'"
    (( ++failed ))
  fi
}

# Sources the plugin in a fresh shell with a given environment and reports
# whether entering a directory actually ran its envfile.
load_and_enter() {
  local root=$1; shift
  env "$@" zsh -f -c '
    export XDG_STATE_HOME=$(mktemp -d)
    source '"$plugin"'/autoenv.plugin.zsh 2>/dev/null
    print -r -- "'"$root"'/proj/.in:$(shasum '"$root"'/proj/.in | cut -d" " -f1)" >> $AUTOENV_AUTH_FILE
    builtin cd '"$root"'/proj
    print "RAN=${PROJ:-no}"
    print "FPATH_ENTRIES=${#${(M)fpath:#*/functions}}"
  ' </dev/null 2>&1
}

local root=$(mktemp -d)
mkdir -p $root/proj
print 'export PROJ=yes' > $root/proj/.in

local out; local -a lines

out=$(load_and_enter $root -u PMSPEC); lines=( ${(f)out} )
check "loads with no plugin manager present" "RAN=yes" "${lines[(r)RAN=*]}"

# A manager that advertises fpath support but is not actually there, which is
# what an exported PMSPEC leaking into a child shell looks like.
out=$(load_and_enter $root PMSPEC=0fbs); lines=( ${(f)out} )
check "loads when PMSPEC claims fpath but nothing set it" "RAN=yes" "${lines[(r)RAN=*]}"

# Sourcing twice must not stack duplicate fpath entries.
local probe=$(mktemp)
{
  print -r -- "source $plugin/autoenv.plugin.zsh"
  print -r -- "source $plugin/autoenv.plugin.zsh"
  print -r -- "typeset -a hits=( \${(M)fpath:#\${plugin_functions}} )"
  print -r -- 'print "DUPES=${#hits}"'
} > $probe
out=$(env -u PMSPEC plugin_functions="${plugin:A}/functions" zsh -f $probe </dev/null 2>&1)
lines=( ${(f)out} )
check "sourcing twice adds one fpath entry" "DUPES=1" "${lines[(r)DUPES=*]}"

(( failed )) && exit 1
exit 0
