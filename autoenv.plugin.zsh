#!/usr/bin/env zsh


if [[ -z $AUTOENV_AUTH_FILE ]]; then
    AUTOENV_AUTH_FILE=~/.autoenv_authorized
fi

if [[ -z $AUTOENV_COLORED ]]; then
    AUTOENV_COLORED=true
fi

add_auth_file(){
    if which shasum &> /dev/null
    then hash=$(shasum "$1" | cut -d' ' -f 1)
    else hash=$(sha1sum "$1" | cut -d' ' -f 1)
    fi
    echo "$1:$hash" >> $AUTOENV_AUTH_FILE
}

check_and_run(){
    if [[ $COLORS == true ]]
    then
        echo -e "$fg_no_bold[green]> $fg_no_bold[red]WARNING$reset_color"
        echo -e "$fg_no_bold[green]> $fg_no_bold[blue]This is the first time you are about to source $fg_no_bold[yellow]\"$fg_bold[red]$1$fg_no_bold[yellow]\"$reset_color"
        echo
        echo -e "$fg_no_bold[green]----------------$reset_color"
        if hash pygmentize 2>/dev/null
        then
            echo
            cp $1 /tmp/.autoenv.sh
            pygmentize -f 256 -g /tmp/.autoenv.sh
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
    if [[ "$answer" == "y" ]] || [[ "$answer" == "Y" ]]
    then
        add_auth_file $1
        source $1
    fi
}

check_and_exec(){
    if which shasum &> /dev/null
    then hash=$(shasum "$1" | cut -d' ' -f 1)
    else hash=$(sha1sum "$1" | cut -d' ' -f 1)
    fi
    if grep "$1:$hash" "$AUTOENV_AUTH_FILE" >/dev/null 2>/dev/null
    then
        source $1
    else
        check_and_run $1
    fi
}

autoenv_init(){
    _OP=$OLDPWD
    _P=`pwd`
    
    if [[ -f $_OP/.out ]]
    then
        check_and_exec $_OP/.out
    fi
    
    while [[ ! $_P == $_OP/* ]]
    do
        _OP=`dirname $_OP`
        if [[ -f $_OP/.out ]]
        then
            check_and_exec $_OP/.out
        fi
    done
    
    
    while [[ ! $_OP == $_P  ]]
    do
        _P=`dirname $_P`
        if [[ -f $_P/.env ]]
        then
            check_and_exec $_P/.env
        fi
    done
    
    if [[ -f $_P/.env ]]
    then
        check_and_exec $_P/.env
    fi
    
}



chpwd_functions+=( autoenv_init )
