# Windows (Git Bash)

Read when Claude Code runs on native Windows. zat.env makes Bash (Git Bash) the
only shell tool there, so commands are POSIX shell, but many of the programs
they start (git, jq, curl, python, node) are native Windows builds.

## Paths

- Git Bash spells `C:\Users\me` as `/c/Users/me`; `~` is the Windows profile
  directory and `/tmp` is the Windows temp directory.
- MSYS rewrites POSIX-looking arguments to `C:/...` on their way into a native
  program, so a path that is stored and compared later (git config, a file
  another program reads) should be converted explicitly: `cygpath -m` for
  `C:/x`, `cygpath -w` for `C:\x`, `cygpath -u` for `/c/x`.
- Process substitution (`<(...)`) hands over a `/proc/<pid>/fd/N` path that
  native programs cannot open. Pipe on stdin instead (`curl -H @-`,
  `--data @-`).

## Line endings

- The native jq (WinGet) and other native tools write CRLF. `$(...)` drops only
  the final CR, so pipe multi-line output through `tr -d '\r'` before comparing
  or splitting it.
- Git for Windows defaults to `core.autocrlf=true`. A repo whose scripts run
  under bash should carry a `.gitattributes` with `* text=auto eol=lf`, as
  zat.env does.

## Python

- `python3` is a Microsoft Store alias: unless the Store build is installed it
  prints an install prompt and exits non-zero. Use the launcher (`py -3`, and
  `py -0p` to list interpreters) or `python`.
- Create venvs with `py -3 -m venv .venv`. Their tools live in `.venv/Scripts/`
  (`.venv/Scripts/python.exe`, `.venv/Scripts/pytest.exe`), not `.venv/bin/`.

## Windows-native work

- Run PowerShell from bash when a task needs it:
  `powershell.exe -NoProfile -Command '...'`, or `pwsh` for PowerShell 7 when
  it is installed. Its output is CRLF.
- `chmod` changes nothing on NTFS; ACLs decide access (`icacls`). The user
  profile is private to its owner by default.
- `ln -s` makes a real symlink only with `MSYS=winsymlinks:nativestrict` and
  Developer Mode on; otherwise it silently copies.

## Not available

`tmux`, `bc`, and `shellcheck` are not part of Git Bash. `nvidia-smi`,
`ml-gpu.md`, and `networking.md` describe the Linux GPU box.
