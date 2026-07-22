#!/usr/bin/env zsh
#
# Runs one navigation scenario in a fresh shell and dumps the resulting
# directory state. Called twice per scenario -- once with autoenv loaded and
# once without -- so the caller can diff the two. autoenv is supposed to be
# invisible: sourcing an envfile requires a cd, and every trace of that cd has
# to be gone by the time the user's prompt returns.
#
# usage: harness.zsh <with|without> <scenario-file> <tree-root>

emulate -L zsh
setopt no_unset

local mode=$1 scenario=$2 root=$3
local plugin=${AUTOENV_TEST_PLUGIN:-${0:A:h:h:h}}

export XDG_STATE_HOME=$(mktemp -d)
export AUTOENV_AUTH_FILE=$XDG_STATE_HOME/auth
export AUTOENV_IN_FILE=.in AUTOENV_OUT_FILE=.out
: > $AUTOENV_AUTH_FILE

# Pre-authorize every envfile in the tree so nothing blocks on the interactive
# prompt. `***` follows symlinks, which `**` does not -- authorization is keyed
# by logical path, so a dir reached through a symlink needs its own entry.
local f hash
typeset -aU envfiles=( ${root}/**/.(in|out)(ND) ${root}/***/.(in|out)(ND) )
for f in $envfiles; do
  if (( $+commands[shasum] )); then
    hash=$(shasum "$f" | cut -d' ' -f1)
  else
    hash=$(sha1sum "$f" | cut -d' ' -f1)
  fi
  print -r -- "$f:$hash" >> $AUTOENV_AUTH_FILE
done

# Registered before autoenv so the dump can show whether autoenv reordered it.
userhook() { : }
autoload -Uz add-zsh-hook
add-zsh-hook chpwd userhook

if [[ $mode == with ]]; then
  fpath+=( $plugin/functions )
  autoload -Uz autoenv_chdir autoenv_check_and_run autoenv_check_and_exec
  add-zsh-hook chpwd autoenv_chdir
fi

setopt auto_pushd
builtin cd $root/start
dirstack=()

source $scenario

# Which envfiles ran. Printed before the `cd -` probe below, because that probe
# leaves a directory and would fire .out files of its own.
print "EFFECTS=${FOO_IN:-0}${FOO_OUT:-0}${BAR_IN:-0}${BAZ_IN:-0}${SP_IN:-0}${LINK_IN:-0}${FAIL_IN:-0}"

print "PWD=${PWD#$root}"
print "OLDPWD=${OLDPWD#$root}"
print "DIRSTACK=${(j: :)${dirstack[@]#$root}}"
local -a hooks=( ${chpwd_functions[@]:#autoenv_chdir} )
print "HOOKS=${(j: :)hooks}"

# zsh keeps its own record of the previous directory for `cd -`; it is not read
# back from $OLDPWD, so this has to be probed rather than inferred.
builtin cd - >/dev/null 2>&1
print "CD_MINUS=${PWD#$root}"
