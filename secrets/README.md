# Secrets

Die verschlüsselten Entwicklungs-Secrets liegen in diesem Verzeichnis und
werden zusammen mit der öffentlichen `NixOS-Config` versioniert. Absichtlich
trackbar sind nur `*.sops.env`, diese README und die `.gitignore`. Dadurch wird
eine versehentlich hier abgelegte Klartextdatei standardmäßig von Git
ignoriert.

Eine DevShell fordert nur die Secret-Sets an, die sie tatsächlich benötigt:

```nix
secretSets = [ "openai" ];
```

Damit lädt `nix develop` automatisch `secrets/openai.sops.env` aus genau der
`NixOS-Config`-Revision, die im jeweiligen Projekt gepinnt ist. Die
entschlüsselten Werte werden erst beim Eintritt in die DevShell als
Umgebungsvariablen gesetzt. Klartext-Secrets werden nicht in den Nix-Store
geschrieben.

Für eigene DevShells, die keinen der gemeinsamen Helper verwenden, ist der
Hook zusätzlich öffentlich verfügbar:

```nix
nixos-config.lib.mkSecretShellHook {
  inherit pkgs;
  secretSets = [ "openai" ];
}
```

## Einmalige Einrichtung

Nach dem Einspielen dieser `NixOS-Config` stehen `age` und `sops` auf `kitty`
und `tracy` zur Verfügung.

### kitty

Home Manager verwaltet `~/.config/sops/age/keys.txt` als Symlink auf
`/secrets/sops/age/keys.txt`. Der private age-Key liegt damit im vorhandenen
LUKS-Vault.

Verzeichnis und Schlüssel einmalig anlegen:

```bash
sudo install -d -o bernd -g users -m 0700 /secrets/sops/age
age-keygen -o /secrets/sops/age/keys.txt
chmod 0600 /secrets/sops/age/keys.txt
age-keygen -y /secrets/sops/age/keys.txt
```

Die letzte Zeile gibt den öffentlichen `age1...`-Recipient aus. Diesen Wert
für `.sops.yaml` aufheben. Der private `AGE-SECRET-KEY-...` gehört niemals ins
Git-Repository.

### tracy

Vorläufig liegt der private age-Key direkt am Standardpfad von SOPS:

```bash
install -d -m 0700 ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
chmod 0600 ~/.config/sops/age/keys.txt
age-keygen -y ~/.config/sops/age/keys.txt
```

Auch hier den ausgegebenen öffentlichen `age1...`-Recipient für `.sops.yaml`
aufheben.

### `.sops.yaml` anlegen

Die Vorlage kopieren und beide öffentlichen Recipients einsetzen:

```bash
cp .sops.yaml.example .sops.yaml
$EDITOR .sops.yaml
git add .sops.yaml
```

`.sops.yaml` ist nicht geheim und soll committed werden.

## Erstes Secret anlegen

Für die erstmalige Erzeugung einer dotenv-Datei wird der Wert direkt über
stdin an SOPS gegeben. Dadurch entsteht zu keinem Zeitpunkt eine
Klartextdatei:

```bash
read -rsp 'OPENAI_API_KEY: ' OPENAI_API_KEY; echo
printf 'OPENAI_API_KEY=%s\n' "$OPENAI_API_KEY" | \
  sops encrypt \
    --filename-override secrets/openai.sops.env \
    --input-type dotenv \
    --output-type dotenv \
  > secrets/openai.sops.env
unset OPENAI_API_KEY
```

Danach liegt in `secrets/openai.sops.env` nur der von SOPS verschlüsselte
Wert. Vor dem ersten Commit zur Kontrolle:

```bash
cat secrets/openai.sops.env
git diff -- secrets/openai.sops.env
git add secrets/openai.sops.env
git commit
```

Danach `NixOS-Config` pushen und in den Projekten, die das neue Secret
verwenden sollen, den bestehenden `nixos-config`-Pin aktualisieren.

## Alltäglicher Workflow

Secrets benutzen:

```bash
nix develop
```

Ein Secret ändern:

```bash
sops secrets/openai.sops.env
```

Versionierung und Synchronisation bleiben normales Git:

```bash
git status
git diff
git pull
git push
```

## Weiteres Secret-Set anlegen

Zum Beispiel:

```bash
sops secrets/forgejo.sops.env
```

Ein Projekt kann beliebig viele Sets anfordern:

```nix
secretSets = [
  "openai"
  "forgejo"
];
```

Werden dieselben Variablennamen in mehreren Sets definiert, gewinnt das später
in `secretSets` aufgeführte Set.

## Rechner hinzufügen oder entfernen

Die Recipient-Liste in `.sops.yaml` ändern und anschließend die betroffenen
Dateien aktualisieren, zum Beispiel:

```bash
sops updatekeys secrets/openai.sops.env
```

Das für die übrigen `*.sops.env` wiederholen.

Wird ein Rechner entfernt, weil sein privater age-Key möglicherweise
kompromittiert wurde, müssen zusätzlich die eigentlichen API-Tokens rotiert
werden. Eine reine Neuverschlüsselung schützt keine historischen Ciphertexte,
die bereits mit dem alten age-Key entschlüsselt werden konnten.
