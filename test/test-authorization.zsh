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
    (( failed++ ))
  fi
}

hash_of() {
  if (( $+commands[shasum] )); then
    shasum "$1" | cut -d' ' -f1
  else
    sha1sum "$1" | cut -d' ' -f1
  fi
}

# Runs a cd in a fresh shell, answering "n" to any authorization prompt, and
# reports whether the prompt appeared and whether the envfile ran.
attempt() {
  local root=$1 target=$2 authfile=$3
  local out
  out=$(
    export XDG_STATE_HOME=$(mktemp -d)
    export AUTOENV_AUTH_FILE=$authfile
    export AUTOENV_IN_FILE=.in AUTOENV_OUT_FILE=.out
    zmodload zsh/parameter
    fpath+=( $plugin/functions )
    autoload -Uz add-zsh-hook autoenv_chdir autoenv_check_and_run autoenv_check_and_exec
    add-zsh-hook chpwd autoenv_chdir
    builtin cd $root/start
    builtin cd $target
    # the prompt ends without a newline, so start a fresh line before reporting
    print ""
    print "RAN=${MARK:-no}"
    local -a leaks=( ${(k)parameters[(I)hash|envfile|answer]} )
    print "LEAKED=${(j:,:)${(o)leaks}}"
  ) <<< 'n' 2>&1
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

# Now authorize the deep path and check the shorter one is not covered by it.
print -r -- "$root/nested/abc/.in:$(hash_of $root/nested/abc/.in)" > $authfile
check "path that is a suffix of an authorized path is not auto-authorized" \
      "prompted=yes RAN=no LEAKED=" \
      "$(attempt $root $root/abc $authfile)"

# Editing an approved envfile must invalidate its entry.
print -r -- "$root/abc/.in:$(hash_of $root/abc/.in)" > $authfile
print -r -- 'export MARK=yes; export EVIL=1' > $root/abc/.in
check "edited envfile is re-authorized, not trusted by path" \
      "prompted=yes RAN=no LEAKED=" \
      "$(attempt $root $root/abc $authfile)"

(( failed )) && exit 1
exit 0
