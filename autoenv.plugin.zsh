#!/usr/bin/env zsh

# Standarized $0 handling, following:
# https://github.com/zdharma/Zsh-100-Commits-Club/blob/master/Zsh-Plugin-Standard.adoc
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"

if [[ $PMSPEC != *f* ]] {
  fpath+=( "${0:h}/functions" )
}

autoload -Uz autoenv_chdir autoenv_check_and_run autoenv_check_and_exec

: ${AUTOENV_AUTH_FILE:="$HOME/.autoenv_authorized"}
: ${AUTOENV_IN_FILE:='.in'}
: ${AUTOENV_OUT_FILE:='.out'}

# Normalize file path
AUTOENV_AUTH_FILE=${AUTOENV_AUTH_FILE:A}

# Create file it if it doesn't exist
if [[ ! -f $AUTOENV_AUTH_FILE ]]; then
  echo -n > $AUTOENV_AUTH_FILE
fi

autoload -Uz add-zsh-hook
add-zsh-hook chpwd autoenv_chdir

typeset -g AUTOENV_OLDPWD=''
autoenv_chdir
