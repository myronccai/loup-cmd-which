# Design: which

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses the
arguments into `Options`, handles `--help` and `--version`, and calls
`commands.which.run_which`. `run_which` reads `PATH` with the prelude
`env("PATH")`, asks `search` for a `Report` (the lines to print and the exit
status) and prints the lines unless -s is given.

## Modules

| Module | Contents |
|---|---|
| `source/cli/args.loup` | `Options`, `parse_args` (getopts rules: `-a`, `-s`, stop at the first name, `--`) |
| `source/cli/usage.loup` | `usage()`, `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, run, map exceptions to status 1 |
| `source/commands/which.loup` | `DEFAULT_PATH`, `split_path`, `candidates`, `find_command`, `search`, `run_which` |

`split_path` and `candidates` are pure string functions (`candidates` builds
paths with `io.path.join`). `find_command` tests each candidate with
`io.fs.isFile`, which follows symbolic links like the shell's `test -f`, and
stops at the first match unless -a is given.

`system.env.get` is a host builtin that the native build cannot link, so the
environment is read with the prelude `env("PATH")`, an `Option[string]`;
`None` (unset) selects `DEFAULT_PATH`.

## Differences from debianutils which

- A regular file matches even if it is not executable: `io.fs` has no
  `stat()` to read the execute bit (T1).
- A `PATH` entry ending in `/` gives `DIR/NAME` (`io.path.join`), where the
  script prints `DIR//NAME`.
- `PATH=::` style entries are each the current directory; the script's word
  splitting drops a final empty entry after `::`.
- An unknown option prints GNU-style messages on standard error (the script
  prints `Illegal option -x` and its usage line on standard output); the exit
  status is 2 in both.
- `--help` and `--version` are added.

## Error handling

Nothing here throws in the native build (`isFile` only answers yes or no).
An unexpected exception is reported by `run()` with status 1.

## Testing

- `tests/args_test.loup`: options, combinations, stopping at the first name,
  `--`, invalid options.
- `tests/which_test.loup`: `split_path`, `candidates`, first and all matches
  in `tests/fixtures/bin1` and `bin2`, directories, names with a slash, exit
  statuses.
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/e2e.sh`: builds directories under `$TMP` (links, a dangling link, a
  non-executable file) and runs the native binary with `PATH` set to them,
  covering every `PATH` form, -a, -s and the error messages.
