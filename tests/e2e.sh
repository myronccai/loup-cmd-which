#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), standard error and exit status with the expected ones.
# The search directories are built under $TMP, and the binary runs with
# PATH set to $WPATH (only the binary: the harness keeps the real PATH).
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with PATH=$WPATH (default: the real PATH) and compares
# standard output with EXPECTED_FILE.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    PATH="${WPATH-$PATH}" "$BIN" "$@" < /dev/null > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_err NAME STATUS EXPECTED_STDERR [ARGS...]
# Runs BINARY ARGS... and compares standard error (without its final
# newline) and the exit status.
check_err() {
    local name=$1 want_status=$2 want_err=$3
    shift 3
    PATH="${WPATH-$PATH}" "$BIN" "$@" < /dev/null > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && [ "$(cat "$TMP/err")" = "$want_err" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        echo "    expected stderr: $want_err"
        sed 's/^/    actual stderr:   /' "$TMP/err" | head -5
    fi
}

# bin1: tool, both, subdir/ (a directory)
# bin2: both, other, link -> ../bin1/tool, dead -> nowhere,
#       notes (a regular file without the execute bit)
mkdir -p "$TMP/bin1/subdir" "$TMP/bin2"
for f in bin1/tool bin1/both bin2/both bin2/other; do
    printf '#!/bin/sh\n' > "$TMP/$f"
    chmod 755 "$TMP/$f"
done
printf 'not a program\n' > "$TMP/bin2/notes"
ln -s ../bin1/tool "$TMP/bin2/link"
ln -s nowhere "$TMP/bin2/dead"
B1=$TMP/bin1
B2=$TMP/bin2
cd "$TMP" || exit 1

WPATH="$B1:$B2" check "first match"        0 "$B1/tool"$'\n' tool
WPATH="$B1:$B2" check "first of two"       0 "$B1/both"$'\n' both
WPATH="$B1:$B2" check "-a"                 0 "$B1/both"$'\n'"$B2/both"$'\n' -a both
WPATH="$B2:$B1" check "PATH order"         0 "$B2/both"$'\n'"$B1/both"$'\n' -a both
WPATH="$B1:$B2" check "several names"      0 "$B2/other"$'\n'"$B1/tool"$'\n' other tool
WPATH="$B1:$B2" check "one missing"        1 "$B1/tool"$'\n' tool nope
WPATH="$B1:$B2" check "none found"         1 '' nope
WPATH="$B1:$B2" check "no names"           1 ''
WPATH="$B1:$B2" check "directory skipped"  1 '' subdir
WPATH="$B1:$B2" check "link to a file"     0 "$B2/link"$'\n' link
WPATH="$B1:$B2" check "dangling link"      1 '' dead
WPATH="$B1:$B2" check "not executable (T1)" 0 "$B2/notes"$'\n' notes
WPATH="$B1:$B2" check "empty name"         1 '' ''

# Names with a slash are checked as they are
WPATH="/nonexistent" check "relative path"  0 $'bin1/tool\n' bin1/tool
WPATH="/nonexistent" check "absolute path"  0 "$B1/tool"$'\n' "$B1/tool"
WPATH="/nonexistent" check "directory path" 1 '' bin1/subdir
WPATH="/nonexistent" check "trailing slash" 1 '' bin1/

# PATH forms
cd "$B1" || exit 1
WPATH=":$B2"  check "leading colon"  0 $'./tool\n' tool
WPATH="$B2:"  check "trailing colon" 0 "$B2/both"$'\n'$'./both\n' -a both
WPATH="$B2::/nonexistent" check "doubled colon" 0 $'./tool\n' tool
cd "$TMP" || exit 1
WPATH="$B1/"  check "trailing slash entry" 0 "$B1/tool"$'\n' tool
WPATH=""      check "empty PATH"     1 '' tool
env -u PATH "$BIN" sh > "$TMP/out" 2>&1
if [ $? -eq 0 ] && grep -qx '/.*/sh' "$TMP/out"; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL: unset PATH uses the default search path: $(cat "$TMP/out")"
fi

# Options
WPATH="$B1:$B2" check "-s found"         0 '' -s tool
WPATH="$B1:$B2" check "-s missing"       1 '' -s nope
WPATH="$B1:$B2" check "-sa"              0 '' -sa both
WPATH="$B1:$B2" check "options stop at a name" 1 "$B1/tool"$'\n' tool -a
WPATH="$B1:$B2" check "-- ends options"  1 '' -- -a
WPATH="$B1:$B2" check_err "invalid option" 2 $'which: invalid option -- \'x\'\nTry \'which --help\' for more information.' -x tool
WPATH="$B1:$B2" check_err "long option"    2 $'which: unrecognized option \'--all\'\nTry \'which --help\' for more information.' --all tool
check "version" 0 $'which (loup-cmd-which) 0.1.0\n' --version
"$BIN" --help | head -1 > "$TMP/help"
if [ "$(cat "$TMP/help")" = "Usage: which [-as] [--] NAME..." ]; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL: --help first line: $(cat "$TMP/help")"
fi

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
