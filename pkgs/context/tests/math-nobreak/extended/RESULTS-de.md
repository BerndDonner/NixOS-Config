# Erweiterte Regressionstests zu Math/Glue (2026-10-27)

## Was ich tatsächlich ausgeführt habe

- 74 konkrete TeX-Testfälle in **ConTeXt LMTX 2026.10.25 / LuaMetaTeX 2.11.10** kompiliert, 74-seitiges PDF erstellt.
- Dieselben 74 Fälle in einer isolierten ConTeXt-Kopie mit dem *alten* `usepenalties=true`-Verhalten erneut kompiliert.
- PDF-Textextraktion, Vergleich der Zeilenumbrüche und stichprobenartige Sichtprüfung der gerenderten Seiten.
- 17 geänderte Umbruchentscheidungen: 14 geschützte Fälle und 3 Konfliktfälle mit negativen Math-Penalties.
- Unverändert: 24 normale/unmarkierte Glue-Kontrollen sowie 12 weitere Kontrollfälle (Kerns, explizite Penalties, Boxen etc.).
- Der negative Regressionstest war erfolgreich: Ein Checker gegen die nur mit `usepenalties=true` geänderte Version schlägt absichtlich bei **13** mit Lua erzeugten `noautobreak`-Fällen fehl. Diese benötigen den echten C-Patch.

## Kategorisierung

| Klasse | Fälle | Prüfregel |
| --- | ---: | --- |
| protected | 33 | Nach dem C-Patch darf kein Umbruch direkt nach der Formel auftreten. |
| normal | 24 | Exakt derselbe extrahierte Absatz in beiden Engines. |
| other | 12 | Unverändert, insbesondere explizite Penalties oder zusätzliche Nodes. |
| conflict | 5 | Forcierter negativer Math-Penalty kombiniert mit geschütztem Glue; manuell bewerten. |

Die Tests `X01` bis `X20` kombinieren vier Werte von `\postinlinepenalty` (`-10000`, `0`, `50`, `10000`), beide Zustände des Glue-Optionsflags und Einstellungen von `\mathsurround` bzw. `\mathsurroundmode`. `L01` bis `L16` erzeugen Glue-Nodes über `\directlua` und testen Optionskombinationen mit `noautobreak`, `isspace`, `nondiscardable`, `setdiscardable` und `limit` sowie Glue-Breite 0 und dehnbaren Glue.

## Wichtige semantische Frage

`\postinlinepenalty=-10000` und das unmittelbar folgende `noautobreak`-Glue stellen gegensätzliche Anforderungen. Der vorgeschlagene C-Patch unterdrückt in diesem Fall den durch `end_inline_math` ausgelösten Umbruch. Wir sollten **nicht** voreilig behaupten, dass diese Priorität in allen Fällen richtig ist; ein explizit erzwungener Umbruch könnte Vorrang haben sollen.

## Einschränkung

Die tatsächliche gepatchte C-Engine liegt hier nicht vor; es wäre falsch, die 74 Fälle als erfolgreich *gegen den Patch* zu bezeichnen. Der mitgelieferte Checker muss auf dem Rechner des Nutzers gegen `result-context-unpatched` und `result-context-patched` ausgeführt werden. Die hier mitgelieferten PDFs sind Referenzausgaben, **keine** Ausgaben der neuen C-Engine.
