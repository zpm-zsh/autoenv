#!/usr/bin/env zsh

# Standarized $0 handling, following:
# https://z-shell.github.io/zsh-plugin-assessor/Zsh-Plugin-Standard
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"

if [[ $PMSPEC != *f* ]] {
  fpath+=( "${0:h}/functions" )
}

autoload -Uz autoenv_chdir autoenv_check_and_run autoenv_check_and_exec

: ${AUTOENV_AUTH_FILE:="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/autoenv_authorized"}

: ${AUTOENV_IN_FILE:='.in'}
: ${AUTOENV_OUT_FILE:='.out'}

# Normalize file path
AUTOENV_AUTH_FILE=${AUTOENV_AUTH_FILE:A}

mkdir -p ${AUTOENV_AUTH_FILE:h}

# Create file it if it doesn't exist
if [[ ! -f $AUTOENV_AUTH_FILE ]]; then
  echo -n > $AUTOENV_AUTH_FILE
fi

autoload -Uz add-zsh-hook
add-zsh-hook chpwd autoenv_chdir

OLDPWD=''
autoenv_chdir
