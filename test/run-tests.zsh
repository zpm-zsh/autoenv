#!/usr/bin/env zsh
#
# autoenv has to source envfiles from their own directory, which means it cds
# behind the user's back. A cd mutates four independent things: $PWD, the
# $OLDPWD parameter, zsh's internal previous-directory record used by `cd -`,
# and the directory stack. Restoring some of them and not the others is how
# issue #31 happened, so these tests assert the whole thing at once: run a
# navigation scenario with and without autoenv loaded and require the resulting
# directory state to be byte-identical.
#
# The comparison is only meaningful if the envfiles actually ran, so every
# scenario also asserts exactly which ones fired.
#
# usage: run-tests.zsh [name-filter]
#        AUTOENV_TEST_PLUGIN=/path/to/checkout run-tests.zsh   # test another revision

emulate -L zsh
setopt err_return

local here=${0:A:h}
local filter=${1:-}

build_tree() {
  local root=$1
  mkdir -p $root/start $root/other $root/fail
  mkdir -p $root/foo/bar/baz
  mkdir -p "$root/sp ace/sub"
  mkdir -p $root/real/sub
  ln -sfn $root/real $root/link

  print 'export FOO_IN=1'   > $root/foo/.in
  print 'export FOO_OUT=1'  > $root/foo/.out
  print 'export BAR_IN=1'   > $root/foo/bar/.in
  print 'export BAZ_IN=1'   > $root/foo/bar/baz/.in
  print 'export SP_IN=1'    > "$root/sp ace/.in"
  print 'export LINK_IN=1'  > $root/real/.in
  # sets its variable and then fails, to prove the restore still runs
  print 'export FAIL_IN=1; false' > $root/fail/.in
}

# scenario => expected envfiles fired, in the order
# FOO_IN FOO_OUT BAR_IN BAZ_IN SP_IN LINK_IN FAIL_IN
typeset -A SCENARIO EXPECT

SCENARIO[enter_nested]='cd $ROOT/foo/bar'
EXPECT[enter_nested]=1010000

SCENARIO[enter_then_leave]='cd $ROOT/foo/bar; cd $ROOT/start'
EXPECT[enter_then_leave]=1110000

SCENARIO[stepwise_descent]='cd $ROOT/foo; cd $ROOT/foo/bar; cd $ROOT/foo/bar/baz'
EXPECT[stepwise_descent]=1011000

SCENARIO[deep_jump_out]='cd $ROOT/foo/bar/baz; cd $ROOT/other'
EXPECT[deep_jump_out]=1111000

SCENARIO[sibling_hop]='cd $ROOT/foo/bar; cd $ROOT/other; cd $ROOT/foo'
EXPECT[sibling_hop]=1110000

SCENARIO[up_then_out]='cd $ROOT/foo/bar; cd $ROOT/foo; cd $ROOT/start'
EXPECT[up_then_out]=1110000

SCENARIO[pushd_popd]='cd $ROOT/foo/bar; pushd $ROOT/start >/dev/null; popd >/dev/null'
EXPECT[pushd_popd]=1110000

SCENARIO[cd_dash_n]='cd $ROOT/foo; cd $ROOT/other; cd $ROOT/foo/bar; cd -2 >/dev/null'
EXPECT[cd_dash_n]=1110000

SCENARIO[spaces_in_path]='cd "$ROOT/sp ace/sub"'
EXPECT[spaces_in_path]=0000100

SCENARIO[through_symlink]='cd $ROOT/link/sub'
EXPECT[through_symlink]=0000010

SCENARIO[failing_envfile]='cd $ROOT/fail; cd $ROOT/foo'
EXPECT[failing_envfile]=1000001

SCENARIO[pushd_ignore_dups]='setopt pushdignoredups; cd $ROOT/foo; cd $ROOT/foo/bar; cd $ROOT/foo'
EXPECT[pushd_ignore_dups]=1010000

SCENARIO[with_cdpath]='export CDPATH=$ROOT; cd $ROOT/foo/bar/baz'
EXPECT[with_cdpath]=1011000

SCENARIO[out_to_root]='cd $ROOT/foo/bar/baz; cd /'
EXPECT[out_to_root]=1111000

local root=$(mktemp -d)
build_tree $root

local scenario_file=$(mktemp)
local name a b state_a state_b effects
local -i failed=0 ran=0

for name in ${(ko)SCENARIO}; do
  [[ -n $filter && $name != *$filter* ]] && continue
  (( ++ran ))

  { print -r -- "ROOT=$root"; print -r -- "${SCENARIO[$name]}" } > $scenario_file

  a=$(timeout 30 zsh $here/lib/harness.zsh without $scenario_file $root </dev/null 2>&1) || true
  b=$(timeout 30 zsh $here/lib/harness.zsh with    $scenario_file $root </dev/null 2>&1) || true

  state_a=${(F)${${(f)a}:#EFFECTS=*}}
  state_b=${(F)${${(f)b}:#EFFECTS=*}}
  effects=${${(M)${(f)b}:#EFFECTS=*}#EFFECTS=}

  local -i ok=1
  if [[ $state_a != $state_b ]]; then
    ok=0
    print "FAIL  $name -- autoenv changed the directory state"
    diff <(print -r -- "$state_a") <(print -r -- "$state_b") | sed 's/^/          /'
  fi
  if [[ $effects != ${EXPECT[$name]} ]]; then
    ok=0
    print "FAIL  $name -- wrong envfiles ran: got $effects want ${EXPECT[$name]}"
  fi
  (( ok )) && print "PASS  $name"
  (( ok )) || (( ++failed ))
done

if (( ran )); then
  print
fi

if [[ -z $filter ]]; then
  local suite out; local -i rc
  for suite in re-entry:test-reentry.zsh authorization:test-authorization.zsh loading:test-loading.zsh; do
    print "${suite%%:*}:"
    out=$(zsh $here/${suite##*:} 2>&1) && rc=0 || rc=$?
    print -r -- "$out" | sed 's/^/  /'
    (( rc )) && (( ++failed ))
    print
  done
fi

if (( failed )); then
  print "FAILED ($failed)"
  exit 1
fi
print "all tests passed"
