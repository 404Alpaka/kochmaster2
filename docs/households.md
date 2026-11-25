# Kontodaten und echte Haushalte

## Aktivierung

Die Migration `supabase/migrations/202611170003_account_data_and_households.sql`
im Supabase SQL Editor ausführen. Sie ist unabhängig von den optionalen
Rezeptbild-Feldern, setzt aber Supabase Auth voraus. Die Migration ist lokal
unter PostgreSQL/PGlite geprüft. Am 18.11.2026 hat der Nutzer die erfolgreiche
Ausführung im verwendeten Supabase-Projekt gemeldet; eine erneute unabhängige
Prüfung des dortigen Schemas und der Rechte fand nicht statt. Bei einem neuen
Projekt die Reihenfolge in [database.md](database.md) beachten.
Danach die App neu starten. Bei fehlender Migration zeigt die Kontoseite den
konkreten Dateinamen und schreibt keine Ersatzdaten in die Cloud.

## Persönliche Daten

`user_preferences` speichert Favoriten, gemerkte und ausgeblendete Rezepte,
eigene Rezepte, persönliche Ausschlüsse und Abneigungen sowie die privaten
Planungseinstellungen, Vorräte, vorbereitete Mahlzeiten und Rückblicke.
Der erste Start übernimmt vorhandene Browserdaten ausschließlich aus dem
Speicherschlüssel des angemeldeten Kontos. Ein vorhandener Cloudstand hat
Vorrang. Gastdaten werden nicht automatisch in ein Konto übernommen.
Browser-Speicher bleibt als lokale Kopie; andere Geräte laden den Cloudstand.
Private Wochenpläne bleiben in `user_week_plans`.

## Haushalte

Unter Haushalt zwischen Privat und einem eigenen Haushalt wechseln.
Ein neuer Haushalt startet mit leerem Vorrat und leerem Wochenplan. Die privaten
Daten werden nicht automatisch als gemeinsame Daten übernommen.

Gemeinsam: Wochenplan, abgehakte Einkaufspositionen, Vorrat, vorbereitete
Mahlzeiten, Planregeln, Budget, Kochhistorie und Wochenrückblicke.
Privat: persönliche Ausschlüsse/Abneigungen, Favoriten, ausgeblendete Rezepte und
die eigene Rezeptsammlung. Wer ein eigenes Rezept ausdrücklich in den gemeinsamen
Plan aufnimmt, teilt dessen Snapshot mit den Haushaltsmitgliedern.
Persönliche Regeln anderer Mitglieder werden nicht erraten oder ausgelesen;
für alle geltende Einschränkungen müssen in den gemeinsamen Planregeln stehen.

| Rolle | Gemeinsame Daten | Einladen/Rollen | Persönliche Daten |
| --- | --- | --- | --- |
| Verwaltung | Lesen und bearbeiten | Ja | Nur eigene |
| Mitglied | Lesen und bearbeiten | Nein | Nur eigene |
| Nur ansehen | Lesen | Nein | Nur eigene |

Die letzte Verwaltung muss vor Austritt oder Herabstufung eine weitere
Verwaltung ernennen. Nach Austritt endet der serverseitige Zugriff auf gemeinsame
Daten. Der Haushalt und private Kontodaten bleiben erhalten.

## Einladungen

Eine Verwaltung erstellt eine Einladung für eine E-Mail-Adresse als Mitglied
oder Nur ansehen. Link bzw. Code selbst mit der Person teilen; die App verschickt
keine Einladungsmail. Der Link wird einmal angezeigt, in der Datenbank liegt nur
ein Hash des zufälligen Codes. Eine neue Einladung an dieselbe Adresse widerruft
die frühere. Einladungen sind sieben Tage gültig, widerrufbar und nur einmal mit
dem bestätigten, adressierten Supabase-Konto einlösbar.

Zum Annehmen anmelden und unter Haushalt den Link/Code einfügen. Eine beim
Appstart erkannte Einladung bleibt für den Anmeldevorgang im Browser erhalten.
Bei lokaler Vorschau ist ein localhost-Link auf einem anderen Gerät nicht
aufrufbar; stattdessen den Code in einer dort erreichbaren App eingeben.

## Synchronisierung und Grenzen

Jeder Start lädt den Cloudstand. Die Aktualisieren-Schaltfläche unter Haushalt
beim Planungsbereich lädt ihn
auch während der Nutzung; es gibt noch kein Echtzeit-Abonnement.
Änderungen werden nacheinander gespeichert und als laufend, gespeichert oder
fehlgeschlagen angezeigt. Kontodokument, Haushaltsdokument und gemeinsamer
Wochenplan besitzen Versionsnummern. Veraltete Schreibzugriffe werden mit
`40001` abgewiesen. Bei Fehlern bleiben Änderungen sichtbar und weitere
Bearbeitung wird gesperrt. Erneut speichern versucht die aktuellen Änderungen;
Cloudstand laden verlangt vor dem Verwerfen ungespeicherter Änderungen eine
Bestätigung. Ein Haushaltswechsel wartet auf ausstehende Speicherungen und
setzt Entwürfe und Kochmodus zurück.

Plan und Vorrats-/Reservierungsdaten liegen weiterhin in getrennten Dokumenten;
sie werden nicht gemeinsam in einer einzigen Transaktion gespeichert. Ein
Teilfehler wird angezeigt und muss erneut gespeichert bzw. abgeglichen werden.
Private Wochenpläne besitzen mit Migration `202611180001_private_week_plan_revisions.sql`
ebenfalls einen Versionsvergleich; siehe [accounts.md](accounts.md).
Bei einer endgültigen Kontolöschung werden Einpersonenhaushalte ebenfalls
entfernt. Haushalte mit weiteren Mitgliedern bleiben erhalten; eine alleinige
Verwaltung muss zuerst eine andere Verwaltung ernennen. Details und erforderliche
Migration: [Datenverwaltung](data-management.md). Die App verschickt keine
Haushaltseinladungen per E-Mail. Bestätigungs- und Passwort-Reset-Mails werden
über Supabase Auth angefordert.

## Prüfungen

`flutter test test/account_household_test.dart test/planning_page_test.dart`
prüft Kontodokumente, Versionskonflikte, private/geteilte Trennung, echte
Mitgliedsanzeige, Bereichswechsel, Leserechte und fehlende Migrationen.

`supabase/tests/account_households.sql` prüft mit zurückgerollten Testnutzern:
private Isolation, geschützte Mitgliedschaften, falsche Einladungsadresse,
Einmaligkeit, Widerruf, Editor-/Viewer-Rechte, Konflikte und Austritt.

Isoliert mit PostgreSQL/PGlite ausführbar:

```powershell
npm install --prefix build/sql-validation --no-package-lock @electric-sql/pglite
node tool/test_account_households.mjs
```

Die lokale Testlaufzeit verwendet eine minimale Auth-Nachbildung. Der SQL-Test
soll zusätzlich im Supabase-Entwicklungsprojekt ausgeführt werden; dort nutzt er
die echten Auth-Funktionen und hinterlässt durch ROLLBACK keine Testdaten.
