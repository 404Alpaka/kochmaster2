# Supabase einrichten

Veröffentlichte Rezepte und Zutaten kommen aus Supabase. Private Wochenpläne
und Einkaufsstatus liegen in `user_week_plans`. Kontodaten und echte Haushalte
benötigen die zusätzliche Migration aus [households.md](households.md).

1. Unter https://supabase.com/dashboard ein Entwicklungsprojekt erstellen.
   Datenbankpasswort sicher speichern; eine passende EU-Region wählen.
2. SQL Editor öffnen. Zuerst den vollständigen Inhalt von
   `supabase/migrations/202611160001_recipe_catalog.sql` ausführen (einmalig).
   Danach alle weiteren Migrationen in der unten genannten Reihenfolge ausführen.
   Optional `supabase/seed.sql` für die beiden Beispielrezepte ausführen.
   Bei bestehenden gleichnamigen Tabellen zuerst das vorhandene Schema prüfen.
3. Über Connect / API Keys die Project URL und den öffentlichen Publishable-Key
   kopieren. `config/supabase.example.json` nach `config/supabase.local.json`
   kopieren und beide Werte dort ersetzen. Keine Secret-/service_role-Keys verwenden.
4. App im Projektordner starten:

```powershell
flutter run -d chrome --dart-define-from-file=config/supabase.local.json
```

Ohne zusätzliche Konfiguration lädt die App das hinterlegte Kochmaster-Projekt. Der Demo-Modus wird mit --dart-define=USE_DEMO=true aktiviert. Bei konfigurierter Datenbank werden
Verbindungsfehler angezeigt, ohne still auf Beispieldaten zurückzufallen.
Die Oberfläche lädt aktuell maximal 100 Rezepte; Pagination folgt vor einem
größeren Katalog. Freigeschaltete Rezept-Admins bearbeiten und veröffentlichen
Rezepte in der App; siehe [Rezeptverwaltung](admin.md).

## Migrationen

Für eine neue Datenbank alle Dateien in `supabase/migrations/` vollständig
in dieser Reihenfolge ausführen:

| Datei | Inhalt |
| --- | --- |
| `202611160001_recipe_catalog.sql` | Rezeptkatalog, Zutaten und öffentliche Leserechte |
| `202611160002_user_week_plans.sql` | Private Wochenpläne und Einkaufsstatus |
| `202611160003_recipe_admin.sql` | Adminrechte, Rezeptverwaltung, Papierkorb und Plan-Snapshots |
| `202611170001_recipe_planning_metadata.sql` | Geprüfte Allergene und Ernährungsweisen |
| `202611170002_recipe_images_and_step_links.sql` | Bildadressen und Zutatenreferenzen in Schritten |
| `202611170003_account_data_and_households.sql` | Kontodaten, Haushalte, Rollen und Versionsvergleich |
| `202611180001_private_week_plan_revisions.sql` | Versionsvergleich für private Wochenpläne und geschützter Speicherweg |
| `202611180002_customer_profiles.sql` | Vor-/Nachname und automatisch erzeugte Kundennummer pro Konto |
| `202611180003_recipe_categories.sql` | Rezeptkategorien, Admin-Speicherung und aggregierte Favoritenzahlen |
| `202611190001_repair_recipe_images.sql` | Bildschema und Zutatenverknüpfungen auch nach vorgezogener Kategorienmigration nachziehen |
| `202611190002_curate_recipe_catalog.sql` | Geprüfte Kategorien für die 21 bestehenden öffentlichen Rezepte und zwei passende Bildzuordnungen |
| `202611190003_recipe_photo_uploads.sql` | Öffentlicher Rezeptbildspeicher mit Größen-/Formatgrenzen und Uploadrecht für Rezept-Admins |
| `202611190004_more_recipe_categories.sql` | Zehn weitere Rezeptkategorien; vorhandene Zuordnungen und Schutz vor widersprüchlichen Ernährungskategorien bleiben erhalten |

Bei bestehenden Projekten zuerst prüfen, welche Migrationen bereits angewendet
wurden. Die Dateien sind keine beliebig wiederholbaren Setup-Skripte.
Der App-Start führt keine Migrationen aus. Der optionale Seed ersetzt keine Migration.

Die Migration `202611180001_private_week_plan_revisions.sql` ist lokal und im
verwendeten Supabase-Projekt geprüft. Bestehende Wochenpläne bleiben
erhalten und erhalten Revision 0. Nach Anwendung die aktuelle App verwenden:
Ältere Clients dürfen nicht mehr direkt per Upsert in `user_week_plans` schreiben.
Speichern erfolgt über `save_user_week_plan` mit geladener Versionsnummer.

Die Haushaltsmigration wurde am 18.11.2026 laut Nutzer erfolgreich im verwendeten
Projekt ausgeführt. Der vollständige Schema- und Rechtezustand wurde dabei nicht
erneut unabhängig geprüft. Für weitere Projekte gilt die Einrichtung oben.

Die Kundendatenmigration `202611180002_customer_profiles.sql` wurde am 19.11.2026
vom Nutzer ausgeführt und ihre Tabellen anschließend über die Live-API geprüft.
Sie muss bei neuen Projekten für die erweiterte Registrierung
angewendet werden. Neue Auth-Konten benötigen danach `first_name` und `last_name`
in ihren Registrierungsmetadaten, auch bei administrativer Kontoanlage.
Ältere App-Versionen ohne Namensfelder können dann keine Konten mehr anlegen.

## Geprüfter Stand vom 19.11.2026

Die Live-Prüfung hat die privaten Wochenplanversionen bestätigt. Kundenprofile
und Rezeptkategorien fehlten zunächst; beide Migrationen wurden vom Nutzer im
SQL Editor ausgeführt und danach über die API nachgeprüft. Dabei wurde zusätzlich
die fehlende ältere Bildmigration entdeckt. Die Nachmigration
`202611190001_repair_recipe_images.sql` ergänzt `image_url` und `step_key`, ohne
den bereits eingerichteten Kategorien-Speicherweg zu ersetzen. Sie wurde lokal
auch bei bereits vorhandenen Bildfeldern und bei wiederholter Ausführung geprüft.
Nach Ausführung durch den Nutzer waren alle geprüften Felder und Funktionen live
vorhanden. Private Tabellen und die Planspeicherfunktion verweigerten anonymen
Zugriff mit `42501`; öffentliche Katalogfelder und Favoritenzahlen antworteten erfolgreich.

Der Nutzer führte außerdem `supabase/tests/private_week_plan_revisions.sql`
im echten SQL Editor aus und meldete das Ergebnis
„PASS: Speichern, Neuladen, Versionskonflikte und private Zugriffsrechte“.
Die Prüfung rollt sämtliche Testkonten und Plandaten zurück.

Schema erneut prüfen (PowerShell 7, öffentlicher App-Key, keine privaten Daten):

```powershell
pwsh -File tool/check_supabase_schema.ps1
```

Für ein anderes Projekt `-ProjectUrl` und `-PublishableKey` übergeben.
Der öffentliche Test prüft Schema und anonyme Zugriffssperren. Er ersetzt nicht
den authentifizierten SQL-Schreibtest oder einen Gerätetest mit persönlichem Konto.

## Prüfung im Entwicklungsprojekt

- Beide veröffentlichten Beispielrezepte müssen in der App erscheinen.
- `is_published` eines Rezepts deaktivieren: Nach App-Neustart darf es samt seinen
  ausschließlich dort verwendeten Zutaten nicht mehr öffentlich sichtbar sein.
- Ohne Anmeldung dürfen mit öffentlichem Key keine Schreibzugriffe möglich sein.
  Angemeldete Nutzer schreiben nur ihre freigegebenen Daten; Rezeptänderungen
  erfolgen über die rollenprüfenden Adminfunktionen.
- Mit falscher Projekt-URL muss die App einen Fehler und einen Wiederholen-Knopf zeigen.

Die SQL-Prüfungen in `supabase/tests/` prüfen Wochenplanrechte, Rezeptverwaltung
und Haushaltsrechte. Ihre Testdaten werden zurückgerollt. Lokale Prüfungen ersetzen
keine Prüfung von RLS und Grants im Zielprojekt.
Öffentliche Keys sind aus der App auslesbar; Zugriffsschutz erfolgt durch RLS.

Referenz: https://supabase.com/docs/guides/getting-started/quickstarts/flutter


