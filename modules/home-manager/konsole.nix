{ pkgs, ... }:

let
  konsole = pkgs.kdePackages.konsole;

  # Use the keytabs from the exact Konsole source version packaged by Nix.
  # The installed package is not guaranteed to expose them in share/konsole.
  keytabs = pkgs.stdenvNoCC.mkDerivation {
    pname = "konsole-shift-return-keytabs";
    inherit (konsole) version src;

    phases = [ "unpackPhase" "installPhase" ];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"

      for name in default macos; do
        source="data/keyboard-layouts/$name.keytab"
        if [ ! -f "$source" ]; then
          echo "Missing Konsole keytab: $source" >&2
          exit 1
        fi

        # Require exactly one legacy binding; fail if upstream changes it.
        count=$(${pkgs.gnugrep}/bin/grep -Ec \
          '^key[[:space:]]+Return[[:space:]]*\+Shift[[:space:]]*:[[:space:]]*"\\EOM"' \
          "$source" || true)
        if [ "$count" -ne 1 ]; then
          echo "Expected one Shift+Return binding in $source, found $count" >&2
          exit 1
        fi

        ${pkgs.gnused}/bin/sed -E \
          's@^key[[:space:]]+Return[[:space:]]*\+Shift[[:space:]]*:[[:space:]]*"\\EOM"@key Return+Shift : "\\E[13;2u"@' \
          "$source" > "$out/$name.keytab"

        ${pkgs.gnugrep}/bin/grep -Fq \
          'key Return+Shift : "\E[13;2u"' "$out/$name.keytab" || exit 1
      done

      runHook postInstall
    '';
  };
in
{
  # Keep the existing Konsole profiles and all other key bindings unchanged.
  xdg.dataFile = {
    "konsole/default.keytab".source = "${keytabs}/default.keytab";
    "konsole/macos.keytab".source = "${keytabs}/macos.keytab";
  };
}
