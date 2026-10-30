# Boot.dev CLI

Built from commit `442fbee0e53eb0da7beea200cf6b92d6ef2f2b8c`, version
`1.32.6`. The only flake entry point is the NixOS-Config repository root;
there is no separate package flake or lock file.

```bash
# From NixOS-Config:
nix build .#bootdev-cli -o result-bootdev -L
./result-bootdev/bin/bootdev --version
nix run .#bootdev-cli -- --help

# Make the CLI available while working on lessons:
nix shell .#bootdev-cli
bootdev login
```

The wrapper supplies Go as a fallback on PATH because upstream runs `go list`
to check the latest CLI version. A Go toolchain already on PATH keeps priority.
Compilers/interpreters and tools required by individual lessons still belong
in the lesson's development shell. Browser login also needs a working desktop
browser opener (such as xdg-open on Linux).

Upstream embeds its version from `version.txt`; the build verifies it matches
the package version, runs `go test ./...`, then checks the installed CLI's
`--version` and `--help`. Only generated shell test fixtures are adjusted for
Nix store paths; the application logic is unchanged.

## Updates

Update `version`, the exact source `rev`, source `hash` and `vendorHash` in
`bootdev-cli.nix`, then rebuild and run the checks above. `nix flake update`
alone does not change those values. For new hashes, use `lib.fakeHash` for one
hash at a time, build, and replace it with the actual hash Nix reports.
Do not commit placeholder hashes.

Do not use `bootdev upgrade` / `bootdev update` for this package. Upstream
runs `go install ...@latest`, which can install a second CLI into GOBIN or
`~/go/bin`; it does not update the Nix package. Update the derivation instead.
Boot.dev can require a newer major/minor CLI version before login/submission.
