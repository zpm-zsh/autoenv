#!/usr/bin/env zsh
#
# An envfile is sourced in the current shell, so a `cd` inside it fires chpwd
# and calls autoenv back into itself. This used to be handled by unregistering
# the chpwd hook for the duration of the source, which worked but re-appended
# the hook afterwards and so silently reordered the user's chpwd functions.
# It is now a re-entry flag, which these tests pin down.

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
    (( failed++ ))
  fi
}

local root=$(mktemp -d)
mkdir -p $root/start $root/env/sub $root/elsewhere
local marker=$root/marker; : > $marker
# the envfile records each time it runs, and wanders off on its own
print -r -- 'print run >> '"$marker"'
print -r -- "sourced_from=$PWD" >> '"$marker"'
cd '"$root/elsewhere" > $root/env/.in

local out=$(
  export XDG_STATE_HOME=$(mktemp -d)
  export AUTOENV_AUTH_FILE=$XDG_STATE_HOME/auth
  export AUTOENV_IN_FILE=.in AUTOENV_OUT_FILE=.out
  if (( $+commands[shasum] )); then
    print -r -- "$root/env/.in:$(shasum $root/env/.in | cut -d' ' -f1)" > $AUTOENV_AUTH_FILE
  else
    print -r -- "$root/env/.in:$(sha1sum $root/env/.in | cut -d' ' -f1)" > $AUTOENV_AUTH_FILE
  fi

  # autoenv is registered first and the user's hook second, so that a naive
  # unregister/re-register of autoenv_chdir shows up as a reordering here.
  autoload -Uz add-zsh-hook
  fpath+=( $plugin/functions )
  autoload -Uz autoenv_chdir autoenv_check_and_run autoenv_check_and_exec
  add-zsh-hook chpwd autoenv_chdir

  later_hook() { : }
  add-zsh-hook chpwd later_hook

  builtin cd $root/start
  builtin cd $root/env/sub

  print "PWD=$PWD"
  print "HOOKS=${(j: :)chpwd_functions}"
) 2>&1

check "envfile ran exactly once (no re-entry loop)" 1 $(grep -c '^run$' $marker)
check "envfile sourced from its own directory"      "sourced_from=$root/env" "$(grep '^sourced_from=' $marker | head -1)"
local -a lines=( ${(f)out} )
check "user ends up where they asked to go"         "PWD=$root/env/sub" "${lines[(r)PWD=*]}"
check "user's chpwd order is not rewritten"         "HOOKS=autoenv_chdir later_hook" "${lines[(r)HOOKS=*]}"

(( failed )) && exit 1
exit 0
