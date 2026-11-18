# Supabase einrichten

Veröffentlichte Rezepte und Zutaten kommen aus Supabase. Private Wochenpläne
und Einkaufsstatus liegen in `user_week_plans`. Kontodaten und echte Haushalte
benötigen die zusätzliche Migration aus [households.md](households.md).

1. Unter https://supabase.com/dashboard ein Entwicklungsprojekt erstellen.
   Datenbankpasswort sicher speichern; eine passende EU-Region wählen.
2. SQL Editor öffnen. Zuerst den vollständigen Inhalt von
   `supabase/migrations/202611160001_recipe_catalog.sql` ausführen (einmalig).
   Anschließend `supabase/seed.sql` für die beiden Beispielrezepte ausführen.
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
größeren Katalog. Veröffentlichung und Bearbeitung erfolgen vorläufig im Dashboard.

## Prüfung im Entwicklungsprojekt

- Beide veröffentlichten Beispielrezepte müssen in der App erscheinen.
- `is_published` eines Rezepts deaktivieren: Nach App-Neustart darf es samt seinen
  ausschließlich dort verwendeten Zutaten nicht mehr öffentlich sichtbar sein.
- Mit öffentlichem Key dürfen Insert, Update und Delete nicht möglich sein.
- Mit falscher Projekt-URL muss die App einen Fehler und einen Wiederholen-Knopf zeigen.

Die SQL-Dateien sind lokal vorbereitet, nicht automatisch auf einer Datenbank
ausgeführt. RLS und Grants müssen am echten Entwicklungsprojekt geprüft werden.
Öffentliche Keys sind aus der App auslesbar; Zugriffsschutz erfolgt durch RLS.

Referenz: https://supabase.com/docs/guides/getting-started/quickstarts/flutter


