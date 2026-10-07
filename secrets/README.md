# Secrets

Dieses Verzeichnis enthält die verschlüsselten Secrets für Entwicklungsumgebungen.

Die Dateien werden zusammen mit der öffentlichen `NixOS-Config` versioniert. Die eigentlichen Secret-Werte sind mit **SOPS + age** verschlüsselt.

Ein Projekt gibt lediglich an, welche Secret-Sets es benötigt:

```nix
secretSets = [ "openai" ];
```

Beim

```bash
nix develop
```

werden die benötigten Secrets automatisch aus genau der `NixOS-Config`-Revision geladen, die das Projekt in seinem `flake.lock` gepinnt hat.

Die entschlüsselten Werte existieren nur als Umgebungsvariablen der DevShell und ihrer Kindprozesse. Klartext-Secrets werden nicht in den Nix-Store geschrieben.

---

## Begriffe

Für jedes Secret werden zwei Namen verwendet:

- **Umgebungsvariable** – der Name, unter dem ein Programm das Secret später findet, z. B. `OPENAI_API_KEY` oder `HCLOUD_TOKEN`
- **Secret-Set** – der Name der verschlüsselten Datei ohne `.sops.env`, z. B. `openai` oder `hetzner`

Beispiel:

```text
Umgebungsvariable:  HCLOUD_TOKEN
Secret-Set:         hetzner
Datei:              secrets/hetzner.sops.env
```

Ein Projekt fordert dieses Secret dann mit

```nix
secretSets = [ "hetzner" ];
```

an.

---

# Einmalige Einrichtung

## age-Key auf kitty

Der private age-Key liegt auf `kitty` im vorhandenen LUKS-Vault.

Home Manager stellt

```text
~/.config/sops/age/keys.txt
```

als Symlink auf

```text
/secrets/sops/age/keys.txt
```

bereit.

Key einmalig erzeugen:

```bash
sudo install -d -o bernd -g users -m 0700 /secrets/sops/age

age-keygen -o /secrets/sops/age/keys.txt
chmod 0600 /secrets/sops/age/keys.txt
```

Den zugehörigen öffentlichen Recipient anzeigen:

```bash
age-keygen -y /secrets/sops/age/keys.txt
```

Die Ausgabe sieht ungefähr so aus:

```text
age1...
```

Dieser **öffentliche** Wert kommt später in `.sops.yaml`.

Der private Key beginnt mit

```text
AGE-SECRET-KEY-...
```

und darf niemals ins Git-Repository gelangen.

---

## age-Key auf tracy

Auf `tracy` liegt der private Key zunächst direkt am SOPS-Standardpfad:

```bash
install -d -m 0700 ~/.config/sops/age

age-keygen -o ~/.config/sops/age/keys.txt
chmod 0600 ~/.config/sops/age/keys.txt
```

Öffentlichen Recipient anzeigen:

```bash
age-keygen -y ~/.config/sops/age/keys.txt
```

Auch hier wird nur der ausgegebene `age1...`-Wert in `.sops.yaml` eingetragen.

`kitty` und `tracy` besitzen unterschiedliche private Keys.

---

## `.sops.yaml`

Die Datei `.sops.yaml` enthält die öffentlichen Recipients aller Rechner, die Secrets entschlüsseln dürfen.

Beispiel:

```yaml
keys:
  - &kitty age1...
  - &tracy age1...

creation_rules:
  - path_regex: ^secrets/.*\.sops\.env$
    age:
      - *kitty
      - *tracy
```

`.sops.yaml` enthält keine geheimen Daten und wird committed.

Falls zunächst nur ein Rechner eingerichtet ist, kann die Liste auch nur diesen einen Recipient enthalten. Weitere Rechner können später hinzugefügt werden.

---

# Neues Secret anlegen

Angenommen, der Klartext-Token liegt in einer Datei namens

```text
token
```

## 1. Namen festlegen

Zuerst zwei Namen auswählen.

Beispiel:

```text
Umgebungsvariable: HCLOUD_TOKEN
Secret-Set:        hetzner
```

## 2. Klartextdatei in dotenv-Format bringen

Die Datei `token` mit einem Editor so ändern, dass sie

```text
XXX=...
```

enthält.

Für das Beispiel also:

```text
HCLOUD_TOKEN=mein-geheimer-token
```

## 3. Verschlüsseln

```bash
out=secrets/hetzner.sops.env

sops encrypt \
  --filename-override "$out" \
  --output "$out" \
  token
```

Danach kann die Klartextdatei gelöscht werden:

```bash
rm token
```

Die Datei

```text
secrets/hetzner.sops.env
```

enthält jetzt nur noch den verschlüsselten Wert.

### Warum kommt der Zielname zweimal vor?

Die beiden Optionen haben unterschiedliche Aufgaben:

```text
--filename-override "$out"
```

sagt SOPS:

> Verwende diesen Dateinamen zur Auswahl der passenden Regel aus `.sops.yaml` und zur Erkennung des Dateiformats.

```text
--output "$out"
```

sagt SOPS:

> Schreibe das verschlüsselte Ergebnis tatsächlich in diese Datei.

Mit

```bash
out=secrets/hetzner.sops.env
```

muss der Pfad trotzdem nur einmal ausgeschrieben werden.

---

## 4. Verschlüsselung prüfen

Verschlüsselte Datei ansehen:

```bash
cat secrets/hetzner.sops.env
```

Der Klartext-Token darf dort nicht mehr sichtbar sein.

Zum Testen einmal entschlüsseln:

```bash
sops decrypt secrets/hetzner.sops.env
```

Die Ausgabe sollte beispielsweise

```text
HCLOUD_TOKEN=...
```

enthalten.

---

## 5. Secret committen

```bash
git add secrets/hetzner.sops.env
git commit
git push
```

Nur `*.sops.env`, die README und die `.gitignore` sind in diesem Verzeichnis absichtlich trackbar. Eine versehentlich dort abgelegte Klartextdatei wird daher standardmäßig von Git ignoriert.

---

# Secret in einer DevShell verwenden

Das Projekt fordert das Secret-Set an:

```nix
secretSets = [ "hetzner" ];
```

Danach genügt wie gewohnt:

```bash
nix develop
```

Innerhalb der DevShell steht die zuvor gewählte Umgebungsvariable zur Verfügung:

```bash
echo "$HCLOUD_TOKEN"
```

Zum Testen besser ohne Ausgabe des eigentlichen Secrets:

```bash
test -n "$HCLOUD_TOKEN" && echo "HCLOUD_TOKEN ist gesetzt"
```

Mehrere Secret-Sets können gemeinsam geladen werden:

```nix
secretSets = [
  "openai"
  "hetzner"
  "forgejo"
];
```

Werden in mehreren Sets dieselben Umgebungsvariablen definiert, gewinnt das später aufgeführte Set.

---

# Vorhandenes Secret ändern

Die verschlüsselte Datei direkt mit SOPS öffnen:

```bash
sops secrets/hetzner.sops.env
```

SOPS öffnet die entschlüsselte Version im Editor und verschlüsselt sie beim Speichern wieder.

Danach wie üblich:

```bash
git status
git diff
git add secrets/hetzner.sops.env
git commit
git push
```

Da DevShells eine bestimmte `NixOS-Config`-Revision pinnen, muss anschließend in betroffenen Projekten der `nixos-config`-Pin aktualisiert werden.

Der vorhandene Update-Hinweis der DevShell meldet, wenn das gepinnte `NixOS-Config` veraltet ist.

---

# Rechner hinzufügen

Neuen age-Key auf dem Rechner erzeugen und dessen öffentlichen `age1...`-Recipient zu `.sops.yaml` hinzufügen.

Neue Secrets verwenden diese Recipient-Liste anschließend automatisch.

Bereits vorhandene Dateien müssen einmal aktualisiert werden:

```bash
sops updatekeys secrets/openai.sops.env
sops updatekeys secrets/hetzner.sops.env
```

`updatekeys` muss dabei auf einem Rechner ausgeführt werden, der die bisherige Version des Secrets bereits entschlüsseln kann.

Beispiel:

```text
bisher:     kitty
neu:        kitty + tracy
```

Die erste Aktualisierung muss auf `kitty` erfolgen. Danach können beide Rechner die Datei entschlüsseln.

---

# Rechner entfernen

Recipient aus `.sops.yaml` entfernen und anschließend die betroffenen Dateien aktualisieren:

```bash
sops updatekeys secrets/openai.sops.env
```

Wurde ein privater age-Key möglicherweise kompromittiert, reicht eine Neuverschlüsselung allein nicht aus.

Dann müssen zusätzlich die eigentlichen API-Tokens bzw. Passwörter rotiert werden, da ein Angreifer mit dem alten privaten Key auch historische Git-Versionen der früher für diesen Key verschlüsselten Dateien entschlüsseln könnte.

---

# Git

Die verschlüsselten Dateien werden ganz normal mit Git verwaltet:

```bash
git status
git diff
git pull
git push
```

Es gibt absichtlich kein zusätzliches Verwaltungswerkzeug.

---

# Eigene DevShells

Die gemeinsamen DevShell-Helper unterstützen direkt:

```nix
secretSets = [ "openai" ];
```

Für eine eigene DevShell, die keinen dieser Helper verwendet, kann der gemeinsame Hook direkt eingebunden werden:

```nix
nixos-config.lib.mkSecretShellHook {
  inherit pkgs;
  secretSets = [ "openai" ];
}
```

---

# Sicherheitsmodell

Das Repository `NixOS-Config` ist öffentlich.

Damit sind auch die verschlüsselten `*.sops.env`-Dateien und deren Metadaten öffentlich sichtbar. Die eigentlichen Secret-Werte bleiben verschlüsselt.

Insbesondere gilt:

- private `AGE-SECRET-KEY-...` niemals committen
- nur öffentliche `age1...`-Recipients gehören in `.sops.yaml`
- keine Klartext-Secrets in Nix-Ausdrücke schreiben
- keine Klartext-Secrets in den Nix-Store kopieren
- bei kompromittiertem age-Key die eigentlichen Tokens rotieren
- `git diff` vor einem Commit kontrollieren

Die Dateinamen und Namen der Umgebungsvariablen sind nicht als geheim zu betrachten.
