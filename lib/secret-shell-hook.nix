{ pkgs
, secretSets ? [ ]
, secretDir ? ../secrets
}:

let
  lib = pkgs.lib;

  validSecretSet = name:
    builtins.match "^[A-Za-z0-9._-]+$" name != null;

  invalidSecretSets = builtins.filter (name: !(validSecretSet name)) secretSets;

  checkedSecretSets =
    if invalidSecretSets != [ ] then
      throw "Invalid secret set name(s): ${builtins.concatStringsSep ", " invalidSecretSets}"
    else
      secretSets;

  loadSecretSet = name:
    let
      secretFile = "${toString secretDir}/${name}.sops.env";
    in
    ''
      _secret_name=${lib.escapeShellArg name}
      _secret_file=${lib.escapeShellArg secretFile}

      if [ ! -r "$_secret_file" ]; then
        printf '%s\n' "🔐 Required secret set '$_secret_name' is missing:" >&2
        printf '   %s\n' "$_secret_file" >&2
        printf '%s\n' "   Update the pinned NixOS-Config after adding the encrypted secret." >&2
        exit 1
      fi

      if ! _secret_env="$(${pkgs.sops}/bin/sops decrypt --output-type dotenv "$_secret_file")"; then
        printf '%s\n' "🔐 Failed to decrypt required secret set '$_secret_name'." >&2
        exit 1
      fi

      # The decrypted dotenv content comes from our trusted SOPS repository.
      # Keep it in memory only; no plaintext file is written.
      set -a
      eval "$_secret_env"
      _secret_eval_status=$?
      set +a
      unset _secret_env

      if [ "$_secret_eval_status" -ne 0 ]; then
        printf '%s\n' "🔐 Failed to load required secret set '$_secret_name'." >&2
        unset _secret_eval_status
        exit 1
      fi
      unset _secret_eval_status

      printf '%s\n' "🔐 Loaded secret set: $_secret_name"
      unset _secret_name _secret_file
    '';
in
if checkedSecretSets == [ ] then
  ""
else
  ''
    # Secrets are decrypted only when entering the dev shell. The encrypted
    # files may live in the Nix store; plaintext values never do.
    ${builtins.concatStringsSep "\n" (map loadSecretSet checkedSecretSets)}
  ''
