#!/usr/bin/env zsh
#
# An envfile is sourced in the current shell, so a `cd` inside it fires chpwd
# and calls autoenv back into itself. That is handled by a re-entry flag rather
# than by unregistering the chpwd hook, which would silently reorder the user's
# chpwd functions.
#
# These also pin down what an envfile can see of its surroundings: it runs in
# whatever directory the user moved to, and finds its own directory through
# $0 and $1.

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

local root=$(mktemp -d)
mkdir -p $root/start $root/env/sub $root/elsewhere
local marker=$root/marker; : > $marker

# Records what it can see, then wanders off on its own.
cat > $root/env/.in <<ENVFILE
print run >> $marker
print -r -- "pwd=\$PWD" >> $marker
print -r -- "dirname_argzero=\$(dirname \$0)" >> $marker
print -r -- "arg1=\$1" >> $marker
cd $root/elsewhere
ENVFILE

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

local -a lines=( ${(f)out} )
local -a recorded=( ${(f)"$(<$marker)"} )

check "envfile ran exactly once (no re-entry loop)" \
      1 $(grep -c '^run$' $marker)
check "envfile runs in the directory the user moved to" \
      "pwd=$root/env/sub" "${recorded[(r)pwd=*]}"
check "envfile finds its own directory through \$0" \
      "dirname_argzero=$root/env" "${recorded[(r)dirname_argzero=*]}"
check "envfile is passed its own directory as \$1" \
      "arg1=$root/env" "${recorded[(r)arg1=*]}"
check "an envfile that cds does not move the user" \
      "PWD=$root/env/sub" "${lines[(r)PWD=*]}"
check "user's chpwd order is not rewritten" \
      "HOOKS=autoenv_chdir later_hook" "${lines[(r)HOOKS=*]}"

(( failed )) && exit 1
exit 0
