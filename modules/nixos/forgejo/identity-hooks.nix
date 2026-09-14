{ config, lib, pkgs, ... }:

let
  repositoryOwner = "bleau";
  ownerRepositoryRoot = "${config.services.forgejo.repositoryRoot}/${repositoryOwner}";

  allowedName = "bleau";
  allowedEmail = "bleau@noreply.git.the-darkroom.org";

  hookEtcPath = "/etc/forgejo/hooks/check-commit-identity";

  identityHook = pkgs.writeShellScript "forgejo-check-commit-identity" ''
    set -euo pipefail

    readonly allowed_name=${lib.escapeShellArg allowedName}
    readonly allowed_email=${lib.escapeShellArg allowedEmail}

    failed=0
    declare -A checked=()

    while read -r _oldrev newrev _refname; do
      # Ref deletion.
      [[ "$newrev" =~ ^0+$ ]] && continue

      # Tags and other refs that do not ultimately point to a commit do not
      # introduce commit identities that need checking.
      ${pkgs.git}/bin/git cat-file -e "$newrev^{commit}" 2>/dev/null || continue

      # Check every commit that becomes newly reachable in this repository.
      while read -r commit; do
        [[ -n "''${checked[$commit]:-}" ]] && continue
        checked["$commit"]=1

        mapfile -t ident < <(
          ${pkgs.git}/bin/git show -s \
            --format='%an%n%ae%n%cn%n%ce' \
            "$commit"
        )

        author_name="''${ident[0]-}"
        author_email="''${ident[1]-}"
        committer_name="''${ident[2]-}"
        committer_email="''${ident[3]-}"

        if [[ "$author_name" != "$allowed_name" ||
              "$author_email" != "$allowed_email" ||
              "$committer_name" != "$allowed_name" ||
              "$committer_email" != "$allowed_email" ]]; then

          short="$(${pkgs.git}/bin/git rev-parse --short "$commit")"

          echo >&2
          echo "ERROR: commit $short has an invalid Git identity:" >&2
          echo "  Author:    $author_name <$author_email>" >&2
          echo "  Committer: $committer_name <$committer_email>" >&2
          echo >&2
          echo "Required identity:" >&2
          echo "  $allowed_name <$allowed_email>" >&2
          echo >&2

          failed=1
        fi
      done < <(
        ${pkgs.git}/bin/git rev-list "$newrev" --not --all
      )
    done

    exit "$failed"
  '';
in
{
  # Stable path for every repository hook. Nix may replace the store object
  # when this script changes, but the per-repository symlink never has to
  # change because it points here.
  environment.etc."forgejo/hooks/check-commit-identity".source = identityHook;

  systemd.services.forgejo-identity-hooks = {
    description = "Install Forgejo commit identity hooks";

    after = [ "forgejo.service" ];
    requires = [ "forgejo.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig.Type = "oneshot";

    script = ''
      set -euo pipefail

      repoRoot=${lib.escapeShellArg ownerRepositoryRoot}

      # The account may not have repositories yet. The path unit below will
      # run this service again as soon as the directory changes.
      [[ -d "$repoRoot" ]] || exit 0

      shopt -s nullglob

      for repo in "$repoRoot"/*.git; do
        hookDir="$repo/hooks/pre-receive.d"

        ${pkgs.coreutils}/bin/install \
          -d \
          -o ${lib.escapeShellArg config.services.forgejo.user} \
          -g ${lib.escapeShellArg config.services.forgejo.group} \
          -m 0750 \
          "$hookDir"

        ${pkgs.coreutils}/bin/ln \
          -sfn \
          ${lib.escapeShellArg hookEtcPath} \
          "$hookDir/10-identity"
      done
    '';
  };

  # Forgejo 15 uses per-repository hooks. Watch the owner's repository
  # directory so newly created repositories get the identity hook without a
  # manual step. PathChanged also copes with the directory being created after
  # the path unit starts.
  systemd.paths.forgejo-identity-hooks = {
    description = "Watch for new Forgejo repositories";
    wantedBy = [ "multi-user.target" ];

    pathConfig.PathChanged = ownerRepositoryRoot;
  };
}
