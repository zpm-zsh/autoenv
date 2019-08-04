#!/usr/bin/env zsh

DEPENDENCES_ZSH+=( zpm-zsh/colors )

if command -v zpm >/dev/null; then
  zpm zpm-zsh/colors
fi

: ${AUTOENV_AUTH_FILE:="$HOME/.autoenv_authorized"}
: ${AUTOENV_IN_FILE:=".in"}
: ${AUTOENV_OUT_FILE:=".out"}

autoload -Uz add-zsh-hook

# Check if $AUTOENV_AUTH_FILE is a symlink.
if [[ -L $AUTOENV_AUTH_FILE ]]; then
  AUTOENV_AUTH_FILE=$(readlink $AUTOENV_AUTH_FILE)
fi

if [[ ! -e "$AUTOENV_AUTH_FILE" ]]; then
  touch "$AUTOENV_AUTH_FILE"
fi

check_and_run(){
  if [[ "$CLICOLOR" != 0 ]]; then
    echo -e "${c[green]}> ${c[red]}WARNING${c_reset}"
    echo -ne "${c[green]}> ${c[blue]}This is the first time you are about to source "
    echo -e "${c[yellow]}\"${c[red]}$c_bold$1${c[yellow]}\"${c_reset}"
    echo
    echo -e "${c[green]}----------------${c_reset}"
    if hash bat 2>/dev/null; then
      echo
      bat --style="plain" -l bash "$1"
    else
      echo -e "${c[green]}"
      cat "$1"
    fi
    echo -e "${c[green]}----------------${c_reset}"
    echo
    echo -ne "${c[blue]}Are you sure you want to allow this? "
    echo -ne "${c[cyan]}(${c[green]}y${c[cyan]}/${c[red]}N${c[cyan]}) ${c_reset}"
  else
    echo "> WARNING"
    echo "> This is the first time you are about to source \"$1\""
    echo
    echo "----------------"
    cat "$1"
    echo
    echo "----------------"
    echo
    echo -n "Are you sure you want to allow this? (y/N)"
  fi
  read -r answer
  if [[ "$answer" == "y" || "$answer" == "Y" || "$answer" == "yes" ]]; then
    echo "$1:$2" >> "$AUTOENV_AUTH_FILE"
    envfile=$1
    shift
    PWD="$(dirname $envfile)" source "$envfile"
  fi
}

pwd(){
  echo "$PWD"
}

check_and_exec(){
  local IFS=$' \t\n'
  if command -v shasum &> /dev/null; then
    hash=$(shasum "$1" | cut -d' ' -f 1)
  else
    hash=$(sha1sum "$1" | cut -d' ' -f 1)
  fi
  if grep -q "$1:$hash" "$AUTOENV_AUTH_FILE"; then
    envfile="$1"
    shift
    PWD="$(dirname $envfile)" source "$envfile"
  else
  echo 
    check_and_run "$1" "$hash"
  fi
}

autoenv_chdir(){
  local IFS=/
  local old=( $(echo "$OLDPWD") )
  local new=( $(echo "$(pwd)") )
  old=( ${old[@]} ) # drop empty elements
  new=( ${new[@]} )

  local concat=( $old $(echo "${new#$old}") ) # this may introduce empty elements
  concat=( ${concat[@]} ) # so we remove them

  while [[ ! "$concat" == "$new" ]]; do
    if [[ -f "/$old/$AUTOENV_OUT_FILE" ]]; then
      check_and_exec "/$old/$AUTOENV_OUT_FILE" "/$old"
    fi
    old=( ${old[0,-2]} )
    concat=( ${old} $(echo "${new#$old}") )
    concat=( ${concat[@]} )
  done

  while [[ ! "$old" == "$new" ]]; do
    old+=(${new[((1 + $#old))]}) # append next element
    if [[ -f "/$old/$AUTOENV_IN_FILE" ]]; then
      check_and_exec "/$old/$AUTOENV_IN_FILE"
    fi
  done
}

_autoenv_first_run(){
  local OLDPWD=''
  autoenv_chdir
  add-zsh-hook -d precmd _autoenv_first_run
}

add-zsh-hook precmd _autoenv_first_run
add-zsh-hook chpwd autoenv_chdir
