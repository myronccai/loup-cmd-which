# Requirements: which

## Introduction

`which` prints the path of the file a shell would run for a command name, by
searching the directories in `PATH`. This repository recreates the `which`
that Debian and Ubuntu ship (from debianutils), a small POSIX shell script:
options `-a` and `-s`, any number of names, and exit status 1 when a name is
not found. Loup 1.26.0's `io.fs` cannot read file permissions, so a regular
file matches whether or not it is executable.

## Requirements

### Requirement 1: Searching PATH

**User Story:** As a shell user, I want to know which file a command name
runs so that I can tell versions apart.

#### Acceptance Criteria

1. WHEN a name has no `/`, THE program SHALL try `DIR/NAME` for each
   directory of `PATH` in order and print the first one that is a regular
   file (following symbolic links).
2. WHEN -a is given, THE program SHALL print every match, in `PATH` order.
3. THE program SHALL treat an empty `PATH` entry (leading, trailing or
   doubled `:`) as the current directory, printing `./NAME`.
4. WHEN `PATH` is empty, THE program SHALL find nothing; WHEN `PATH` is not
   set, THE program SHALL search the default path of `dash`
   (`/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`).
5. Directories, dangling symbolic links and the empty name SHALL never
   match.

### Requirement 2: Names with a slash

**User Story:** As a script author, I want to check a path directly.

#### Acceptance Criteria

1. WHEN a name contains `/`, THE program SHALL print it unchanged if it is a
   regular file, without searching `PATH`.

### Requirement 3: Several names and the exit status

**User Story:** As a script author, I want one exit status for a list of
names.

#### Acceptance Criteria

1. THE program SHALL handle the names in order, printing each match on its
   own line.
2. THE program SHALL exit with 0 when every name was found, and with 1 when
   any name was not found or no name was given.
3. WHEN -s is given, THE program SHALL print nothing and report only through
   the exit status.

### Requirement 4: Options

**User Story:** As a shell user, I want the option syntax of the original.

#### Acceptance Criteria

1. THE program SHALL accept `-a` and `-s`, combined (`-as`), before the first
   name; an argument after the first name, and every argument after `--`,
   SHALL be a name.
2. WHEN an option is unknown, THE program SHALL print `which: invalid option
   -- 'X'` and `Try 'which --help' for more information.` on standard error
   and exit with status 2.
3. WHEN `--help` or `--version` is given before the first name, THE program
   SHALL print the help text or the version line and exit with status 0.
