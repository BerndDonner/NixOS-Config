{ pkgs, ... }:

let
  # Preserve all key bindings from the packaged Konsole version, changing
  # only Shift+Return from the legacy keypad-Enter sequence to CSI-u.
  withShiftReturn = name:
    pkgs.runCommand "konsole-${name}-shift-return.keytab" { } ''
      src="${pkgs.kdePackages.konsole}/share/konsole/${name}.keytab"

      ${pkgs.gnused}/bin/sed -E \
        's@^key[[:space:]]+Return[[:space:]]*\+Shift[[:space:]]*:[[:space:]]*"\\EOM"@key Return+Shift : "\\E[13;2u"@' \
        "$src" > "$out"

      # Fail explicitly if a future Konsole release changes this binding.
      ${pkgs.gnugrep}/bin/grep -Fq 'key Return+Shift : "\E[13;2u"' "$out" || {
        echo "Could not patch Shift+Return in ${name}.keytab" >&2
        exit 1
      }
    '';
in
{
  # Override the two stock layouts that map Shift+Return to ESC O M.
  # This keeps existing Konsole profiles and their other settings intact.
  xdg.dataFile = {
    "konsole/default.keytab".source = withShiftReturn "default";
    "konsole/macos.keytab".source = withShiftReturn "macos";
  };
}
