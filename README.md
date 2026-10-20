# loup-cmd-which

`which` recreated in [Loup](https://code-craft.ai/references/loup): print
the path a command name runs, searching `PATH`, with `-a`, `-s` and any
number of names. It follows the `which` that Debian and Ubuntu ship
(debianutils).

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary.

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. The full release is at
<https://code-craft.ai/loup/download>, and commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                 # native binary: build/which
make ci                    # check, unit tests, build, end-to-end tests
make run ARGS="-a sh ls"   # run from source with loup run
```

With `PATH=/usr/local/bin:/usr/bin:/bin`:

```text
$ build/which ls; echo $?
/usr/bin/ls
0
$ build/which -a sh; echo $?
/usr/bin/sh
/bin/sh
0
$ build/which ls nosuchcommand; echo $?
/usr/bin/ls
1
$ build/which -s nosuchcommand; echo $?
1
$ build/which tests/fixtures/bin1/tool; echo $?
tests/fixtures/bin1/tool
0
$ PATH=tests/fixtures/bin1:tests/fixtures/bin2 build/which -a both
tests/fixtures/bin1/both
tests/fixtures/bin2/both
```

Options: `-a` (print every match, not just the first), `-s` (print nothing;
only the exit status), `--help`, `--version`. Options combine (`-as`) and
must come before the first name; `--` ends them.

- A name containing `/` is checked as it is, without searching `PATH`.
- An empty `PATH` entry (`:/bin`, `/bin:`, `/a::/b`) means the current
  directory and prints `./NAME`.
- An empty `PATH` finds nothing; an unset `PATH` searches dash's default,
  `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`, as the
  original (a dash script) does.

Exit status: `0` if every name was found, `1` if any name was not found or
no name was given, `2` for an invalid option.

## Differences from debianutils which

- **Any regular file matches, executable or not.** Loup 1.26.0's `io.fs` has
  no `stat()`, so the execute bit cannot be read. Directories and dangling
  links still never match.
- A `PATH` entry ending in `/` prints `DIR/NAME` (`io.path.join`) where the
  script prints `DIR//NAME`.
- After `::` at the end of `PATH`, both empty entries are searched (the
  script's word splitting drops the last one); this only shows with `-a`.
- An unknown option prints `which: invalid option -- 'x'` and `Try 'which
  --help' ...` on standard error; the script prints `Illegal option -x` and
  its usage line on standard output. Both exit 2.
- `--help` and `--version` are added.

## Layout

```text
source/main.loup              # entry point
source/appinfo.loup           # name, version, exit statuses
source/cli/args.loup          # getopts-style option parsing
source/cli/usage.loup         # --help and --version text
source/cli/app.loup           # run(): parse, dispatch, exit status
source/commands/which.loup    # PATH splitting, search, output
tests/*_test.loup             # unit tests (make test)
tests/fixtures/bin1, bin2/    # search directories for the unit tests
tests/e2e.sh                  # end-to-end tests of build/which (make e2e)
specs/which/                  # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
