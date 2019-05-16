#!/usr/bin/env zsh
# vim: ts=2 sw=2

if [[ -z "$AUTOENV_AUTH_FILE" ]]; then
  AUTOENV_AUTH_FILE=~/.autoenv_authorized
fi

if [[ ! -e "$AUTOENV_AUTH_FILE" ]]; then
  touch "$AUTOENV_AUTH_FILE"
fi

if [[ -z "$CLICOLOR" ]]; then
  CLICOLOR=1
fi

if [[ -z "$AUTOENV_IN_FILE" ]]; then
  AUTOENV_IN_FILE=".in"
fi

if [[ -z "$AUTOENV_OUT_FILE" ]]; then
  AUTOENV_OUT_FILE=".out"
fi

check_and_run(){
  if [[ "$CLICOLOR" = 1 ]]; then
    echo -e "$fg_no_bold[green]> $fg_no_bold[red]WARNING$reset_color"
    echo -e "$fg_no_bold[green]> $fg_no_bold[blue]This is the first time you are about to source $fg_no_bold[yellow]\"$fg_bold[red]$1$fg_no_bold[yellow]\"$reset_color"
    echo
    echo -e "$fg_no_bold[green]----------------$reset_color"
    if hash pygmentize 2>/dev/null; then
      echo
      `whence pygmentize` -f console16m -l shell "$1"
    else
      echo -e "$fg_no_bold[green]"
      cat $1
    fi
    echo
    echo -e "$fg_no_bold[green]----------------$reset_color"
    echo
    echo -ne "$fg_no_bold[blue]Are you sure you want to allow this? $fg[cyan]($fg_no_bold[green]y$fg[cyan]/$fg_no_bold[red]N$fg[cyan]) $reset_color"
  else
    echo "> WARNING"
    echo "> This is the first time you are about to source \"$1\""
    echo
    echo "----------------"
    echo
    cat $1
    echo
    echo "----------------"
    echo
    echo -n "Are you sure you want to allow this? (y/N)"
  fi
  read answer
  if [[ "$answer" == "y" ]] || [[ "$answer" == "Y" ]]; then
    echo "$1:$2" >> $AUTOENV_AUTH_FILE
    envfile=$1
    shift
    source $envfile
  fi
}

check_and_exec(){
  local IFS=$' \t\n'
  if which shasum &> /dev/null; then
    hash=$(shasum "$1" | cut -d' ' -f 1)
  else
    hash=$(sha1sum "$1" | cut -d' ' -f 1)
  fi
  if grep --quiet "$1:$hash" "$AUTOENV_AUTH_FILE"; then
    envfile=$1
    shift
    source $envfile
  else
    check_and_run $1 $hash
  fi
}

autoenv_chdir(){
  local IFS=/
  local old=( $(echo "$OLDPWD") )
  local new=( $(echo "$(pwd)") )
  old=( $old[@] ) # drop empty elements
  new=( $new[@] )

  local concat=( $old $(echo "${new#$old}") ) # this may introduce empty elements
  concat=( $concat[@] ) # so we remove them

  while [[ ! "$concat" == "$new" ]] do
    if [[ -f "/$old/$AUTOENV_OUT_FILE" ]]; then
      check_and_exec "/$old/$AUTOENV_OUT_FILE"
    fi
    old=( $old[0,-2] )
    concat=( $old $(echo "${new#$old}") )
    concat=( $concat[@] )
  done

  while [[ ! "$old" == "$new" ]]; do
    old+=($new[((1 + $#old))]) # append next element
    if [[ -f "/$old/$AUTOENV_IN_FILE" ]]; then
      check_and_exec "/$old/$AUTOENV_IN_FILE"
    fi
  done
}

_autoenv_first_run(){
  local OLDPWD=''
  autoenv_chdir
  precmd_functions=(${precmd_functions#_autoenv_first_run})
}
precmd_functions+=(_autoenv_first_run)
chpwd_functions+=(autoenv_chdir)
