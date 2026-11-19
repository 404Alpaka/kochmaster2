# Regelbasierter Wochenplaner

Zunächst werden Allergien, Ernährungsregeln, persönliche Ausschlüsse,
Ein-Stern-Bewertungen, Tageszeitlimits und eine Pause von 30 Kalendertagen
geprüft. Erst danach vergleicht eine Beam Search mit Breite 50 mögliche Wochen.
Ein hoher Geschmackspunktwert kann einen Ausschluss nicht aufheben.

## Verlauf und Auswahl

Gekochte Gerichte und bestätigte Planpositionen vor und nach dem Zieldatum
sperren. „Nicht gekocht“ hebt nur die jeweilige Planposition auf. Reale
Kochprotokolle bleiben gültig, auch nach Entfernen eines geplanten Gerichts.
Ein unbestätigter, ersetzbarer Entwurf sperrt nicht gegen sich selbst.
Benachbarte Cloudwochen werden vor der Erzeugung geladen; Ladefehler brechen ab.

„Passt“ fixiert Gerichte und Portionen beim Erzeugen einer neuen Kombination.
Ein gespeicherter Startwert entscheidet reproduzierbare Gleichstände. Eigene
Einplanungen können Wiederholungs- und Abwechslungsregeln umgehen; erkannte
Ernährungskonflikte oder unbekannte Eignung werden vorher angezeigt.
Eine ausdrückliche Wiederholungsfreigabe gilt nur für den aktuellen Entwurf.

## Bewertung und Lernen

Die Ausgangsgewichte sind Geschmack 50 %, Tagespassung 20 %, Vorräte 15 %,
Budget 10 % und Entdecken 5 %. Ohne nutzbare Vorratsdaten oder Budgetvorgabe
werden die verbleibenden Gewichte normalisiert. Die Wochenbewertung ergänzt
Abzüge für wiederholte Hauptbeilagen, Gerichtsarten und Hauptzutaten sowie
einen begrenzten Bonus für gemeinsame Zutaten. Fehlende Planungsmerkmale
bleiben unbekannt und werden im Vorschlag kenntlich gemacht.

Sterne und private Notizen stehen in den Rezeptdetails. Ein Stern sperrt,
zwei werten ab, drei sind neutral, vier und fünf bevorzugen. Favoriten erhalten
einen kleinen Bonus. Merkmalslernen erfordert mindestens drei unabhängige
bewertete oder ausdrücklich abgelehnte Rezepte und bleibt auf zehn
Geschmackspunkte begrenzt. Automatische Übernahme und Notizen liefern kein
Geschmackssignal. Eigene Auswahlen liefern einen kleinen zusätzlichen Bonus.

Austauschgründe unterscheiden Zurückstellen nur für diesen Entwurf, Aufwand
und Rezeptabneigung. Sie wirken erst beim Übernehmen des Austauschs. Zeitlimits
lassen sich für jeden Tag ausdrücklich ändern. Der Zielwert für Entdeckungen
beträgt zwei bisher nicht als gekocht erfasste Rezepte; Abweichungen werden
angezeigt. Ein neues Rezept kann trotzdem zu vertrauten Geschmacksmerkmalen passen.

## Vorräte und Budget

Unter „Vorräte & Budgetpassung“ kann die Vorratsnutzung aktiviert und eine grobe
Kostenklasse gewählt werden. Vorräte benötigen entweder eine ausdrücklich
zugeordnete Zutaten-ID oder einen eindeutigen exakten Namen aus dem Katalog.
Die Zuordnung lässt sich beim Bearbeiten eines Vorrats ergänzen. Es gibt keine
ungefähre Namens- oder Produktidentifikation.

Der Planer skaliert Rezeptmengen mit den tatsächlich geplanten Portionen und
verteilt Bestände chronologisch. Ein Vorrat wird innerhalb eines Vorschlags
höchstens einmal verbraucht. Früh ablaufende Chargen werden zuerst zugeordnet;
Chargen mit Datum vor dem Essenstag tragen nicht zum Vorratsbonus bei.
Umgerechnet werden kg/g, l/ml und Stück. Unbekannte Mengen und Einheiten
wie „Dose“ erzeugen keine erfundene Deckung. Die Planung verändert keine Bestände.

In den Rezeptdetails lassen sich eigene Kosten pro Portion hinterlegen.
Diese werden mit den geplanten Portionen skaliert und gegen das Planbudget
bewertet. Grobe Kostenklassen beeinflussen die Auswahl, wenn eine entsprechende
Vorgabe besteht. Fehlende Kosten bleiben neutral; ein unvollständig prüfbares
Budget und eine bereits erkennbare Überschreitung werden ausdrücklich angezeigt.
Die Beträge sind eigene Schätzungen, keine Live-Preise, Packungskosten oder
Ausgabenprognosen. Vorräte werden nicht rechnerisch vom geschätzten Preis abgezogen.

## Haushalte und Datenschutz

Unter „Mitessende & feste Regeln“ werden aktive Mitglieder und zusätzliche
Personen mit ihren ausdrücklich bestätigten Ernährungsregeln erfasst.
Nicht mitessende Personen lassen sich abwählen. Bei aktiven Personen mit
unbestätigten Angaben entstehen keine automatischen Freigaben. Alle festen
Regeln der aktiven Personen gelten gemeinsam; Geschmack, Sterne, Favoriten
und private Notizen bleiben beim persönlichen Profil des Planenden.

Vor einem neuen Haushaltsvorschlag werden die aktuelle Mitgliederliste und der
geteilte Regelstand geladen. Private Profile anderer Konten werden nicht gelesen
oder automatisch geteilt. Gemeinsame Deklarationen, Vorräte, Kostenangaben und
Budgetwünsche sind ausdrücklich geteilte Haushaltsdaten. Zuschauer können diese
Angaben ansehen, aber nicht bearbeiten. Die Speicherung verwendet die vorhandene
Versionsprüfung. Alte Clients können die neuen Deklarationen nicht versehentlich
beim Speichern eines älteren Dokuments entfernen.

## Datenbank und Betrieb

Diese Migrationen müssen in der Reihenfolge ihrer Namen angewandt werden:

- `supabase/migrations/202611190005_weekly_planner.sql`: Rezeptmerkmale und Admin-Speicherfunktion.
- `supabase/migrations/202611190006_planner_household_resources.sql`: gemeinsame Deklarationen und Ressourcenoptionen samt Validierung und Schutz vor dem Überschreiben durch ältere Clients.

Bestehende Rezepte erhalten keine ungeprüften Merkmale automatisch. Die Angaben
können im Rezepteditor gepflegt werden. Ohne Migration 006 nennt die Anwendung
beim Speichern gemeinsamer Planerregeln die fehlende Migration.

Der Nutzer hat beide Migrationen im Supabase SQL Editor angewandt. Die öffentliche
API-Prüfung bestätigt die neuen Rezeptspalten sowie die anonymen Zugriffssperren.
Die Haushalts-Speicherfunktion ist anonym gesperrt; ihr authentifiziertes Verhalten
wurde lokal mit PGlite geprüft, nicht über das persönliche Live-Konto verändert.

Die bereits vorhandene PGlite-Testumgebung unter `build/sql-validation` wurde für
`tool/test_weekly_planner_schema.mjs` verwendet. Dabei bestehen die neuen SQL-Tests
und die bisherigen Haushaltsprüfungen einschließlich Versionskonflikten,
Eingabevalidierung, privaten Datengrenzen und Kompatibilität älterer Clients.

## Prüfungen und Grenzen

Dart-Tests prüfen Kalendergrenzen, zukünftige Sperren, übersprungene Termine,
harte Ausschlüsse, Teilpläne, Abwechslung, Reproduzierbarkeit, Fixierungen,
Merkmalslernen, Mengenverbrauch, Einheiten, Haltbarkeit, Kostenschätzungen,
Mitgliederregeln, Datenschutz und die zugehörigen Oberflächen und Speicherwege.
`supabase/tests/planner_household_resources.sql` ergänzt eine SQL-Prüfung für
Deklarationen, ungültige Eingaben, alte Clients und Versionskonflikte.

Nicht angeschlossen sind Live-Produktpreise, Packungsoptimierung und automatische
Allergendatenprüfung. Diese Daten werden nicht geschätzt. Für Gerichte mit festen
Ausschlüssen bleiben verlässlich geprüfte Rezeptangaben notwendig.

Abschließende lokale Validierung: 122 Flutter-Tests bestanden, ein optionaler Live-Test übersprungen. Gezielte Analyse der erweiterten Planer-, Haushalts- und Editor-Dateien ohne Befund. Web-Build mit --no-pub --no-wasm-dry-run erfolgreich. SQL-Prüfungen wurden anschließend mit der vorhandenen lokalen PGlite-Umgebung erfolgreich nachgeholt.


## Lokaler Test nach Anwendung der Migrationen

Die aktuelle App läuft für den Nutzertest unter `http://localhost:62926`.
Im Browser wurden der vorhandene Wochenplan, dessen Bearbeitungsansicht und der
neue Vorrats-/Budgetdialog geprüft. Dialog und Bearbeitung wurden abgebrochen;
der gespeicherte Plan wurde nicht verändert. Ein persönlicher Live-Schreibtest
für gemeinsame Regeln steht noch aus.

Die öffentliche Katalogprüfung ergab 23 veröffentlichte Rezepte. Bei allen fehlen
noch Hauptbeilage, Gerichtsart, Hauptzutat, aktive Arbeitszeit, Kostenklasse und
geprüfte Allergen- und Ernährungsangaben. Migrationen ergänzen das Schema, keine
inhaltlichen Freigaben. Für abwechslungsreiche und eingeschränkte Vorschläge
müssen die Rezeptdaten im Admin-Editor gepflegt werden. Allergene und Ernährungs-
freigaben dürfen dabei nur nach tatsächlicher Prüfung gesetzt werden.

Wiederholbare Prüfungen:

```powershell
./tool/check_supabase_schema.ps1
./tool/audit_weekly_planner.ps1
& 'C:/Users/klaeh/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe' tool/test_weekly_planner_schema.mjs
```

`check_supabase_schema.ps1` bestätigt die veröffentlichten Felder und anonymen
Zugriffssperren. `audit_weekly_planner.ps1` liest nur öffentliche Rezeptmetadaten
und zeigt die Anzahl gepflegter Angaben. Die SQL-Prüfung arbeitet ausschließlich
in einer eigenen lokalen Testdatenbank und schreibt keine Produktionsdaten.

Der explizite Flutter-Live-Test gegen den öffentlichen Katalog bestand ebenfalls: flutter test test/supabase_live_test.dart --no-pub --dart-define=RUN_LIVE_TESTS=true. Er prüfte 23 geladene Rezepte mit Zutaten und Zubereitung.


## Mahlzeitenumfang

Aktuell werden Abendessen entdeckt und geplant. Rezepte mit der Kategorie
`breakfast` sowie eindeutig benannte Frühstücksgerichte wie Porridge,
Overnight Oats und Müsli erscheinen nicht in Entdecken, Sammlung, Tagesempfehlungen
oder der automatischen Planung. Der Namensabgleich erfasst nur Rezeptnamen,
keine Zutaten: Ein herzhaftes Gericht mit Haferflocken bleibt verfügbar.
Admin-Katalog und gespeicherte Planpositionen bleiben als Daten erhalten.
Frühstück und Mittag sind als spätere eigenständige Planungsbereiche in der
Architektur-To-do-Liste aufgenommen.


## Nachgepflegte Rezeptmerkmale

Die anschließende Datenpflege wurde direkt in Supabase angewandt: 20 Rezepte
mit Hauptbeilage, Gerichtsart und Zubereitungsart, 18 mit dominanter Hauptzutat.
Drei unvollständige bzw. widersprüchliche Einträge bleiben unverändert offen.
Allergen- und Ernährungsfreigaben, aktive Arbeitszeiten und Kostenangaben wurden
nicht geraten. Einzelheiten und Prüfnachweise: [Rezeptdatenpflege](recipe-data-review.md).
Die frühere Zählung ohne Planungsmerkmale beschreibt den Stand vor dieser Pflege.
