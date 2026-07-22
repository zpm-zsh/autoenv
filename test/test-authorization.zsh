#!/usr/bin/env zsh
#
# The authorization file holds one "path:hash" line per envfile the user has
# approved. Matching it loosely is a security bug: the check decides whether
# arbitrary shell code runs on cd.

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

hash_of() {
  if (( $+commands[shasum] )); then
    shasum "$1" | cut -d' ' -f1
  else
    sha1sum "$1" | cut -d' ' -f1
  fi
}

# Enters a directory in a fresh shell, answering "n" to any prompt, and reports
# whether the prompt appeared, whether the envfile ran, and whether the plugin
# left parameters behind. `zsh -i` is needed because the prompt is only offered
# to interactive shells, and that option cannot be set from inside a script.
attempt() {
  local root=$1 target=$2 authfile=$3 mode=${4:-interactive}
  local probe=$(mktemp)
  cat > $probe <<PROBE
export XDG_STATE_HOME=\$(mktemp -d)
export AUTOENV_AUTH_FILE=$authfile
export AUTOENV_IN_FILE=.in AUTOENV_OUT_FILE=.out
zmodload zsh/parameter
fpath+=( $plugin/functions )
autoload -Uz add-zsh-hook autoenv_chdir autoenv_check_and_run autoenv_check_and_exec
add-zsh-hook chpwd autoenv_chdir
builtin cd $root/start
builtin cd $target
print ""
print "RAN=\${MARK:-no}"
typeset -a leaks=( \${(k)parameters[(I)hash|envfile|answer]} )
print "LEAKED=\${(j:,:)\${(o)leaks}}"
PROBE

  local -a flags=( -f )
  [[ $mode == interactive ]] && flags+=( -i )

  local out
  out=$(zsh $flags -c "source $probe" <<< 'n' 2>&1)

  local prompted=no
  [[ $out == *"first time you are about to source"* ]] && prompted=yes
  local -a lines=( ${(f)out} )
  print "prompted=$prompted ${lines[(r)RAN=*]} ${lines[(r)LEAKED=*]}"
}

local root=$(mktemp -d)
mkdir -p $root/start $root/abc $root/a.c $root/nested/abc
local authfile=$(mktemp)

# A body common enough to be shared verbatim between projects. It resolves
# relative to its own directory, which is what makes the path matter.
local body='export MARK=yes; export PATH="$(dirname $0)/bin:$PATH"'
print -r -- $body > $root/abc/.in
print -r -- $body > $root/a.c/.in            # regex-matching sibling, same content
print -r -- $body > $root/nested/abc/.in     # authorized path is a suffix of this one

print -r -- "$root/abc/.in:$(hash_of $root/abc/.in)" > $authfile

check "authorized path runs without prompting" \
      "prompted=no RAN=yes LEAKED=" \
      "$(attempt $root $root/abc $authfile)"

check "regex-matching sibling is not auto-authorized" \
      "prompted=yes RAN=no LEAKED=" \
      "$(attempt $root $root/a.c $authfile)"

print -r -- "$root/nested/abc/.in:$(hash_of $root/nested/abc/.in)" > $authfile
check "path that is a suffix of an authorized path is not auto-authorized" \
      "prompted=yes RAN=no LEAKED=" \
      "$(attempt $root $root/abc $authfile)"

print -r -- "$root/abc/.in:$(hash_of $root/abc/.in)" > $authfile
print -r -- 'export MARK=yes; export EVIL=1' > $root/abc/.in
check "edited envfile is re-authorized, not trusted by path" \
      "prompted=yes RAN=no LEAKED=" \
      "$(attempt $root $root/abc $authfile)"

# An unauthorized envfile in a script must not ask, because nobody can answer.
print -r -- $body > $root/abc/.in
print -r -- "$root/nested/abc/.in:$(hash_of $root/nested/abc/.in)" > $authfile
check "non-interactive shell does not prompt and does not run it" \
      "prompted=no RAN=no LEAKED=" \
      "$(attempt $root $root/abc $authfile non-interactive)"

# ...and it must not eat a line of the script's own input while not asking.
local probe=$(mktemp)
cat > $probe <<PROBE
export XDG_STATE_HOME=\$(mktemp -d)
export AUTOENV_AUTH_FILE=$authfile
export AUTOENV_IN_FILE=.in AUTOENV_OUT_FILE=.out
fpath+=( $plugin/functions )
autoload -Uz add-zsh-hook autoenv_chdir autoenv_check_and_run autoenv_check_and_exec
add-zsh-hook chpwd autoenv_chdir
builtin cd $root/start
builtin cd $root/abc
read -r line
print "STDIN=\$line"
PROBE
local out=$(zsh -f -c "source $probe" <<< 'sentinel' 2>/dev/null)
local -a lines=( ${(f)out} )
check "non-interactive shell leaves the caller's stdin alone" \
      "STDIN=sentinel" "${lines[(r)STDIN=*]}"

(( failed )) && exit 1
exit 0
