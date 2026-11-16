# Rezeptverwaltung und Rechte

## Verwendung

Ein freigeschalteter Rezept-Admin sieht nach dem Anmelden oben das Symbol
„Rezepte verwalten“. Dort lassen sich Rezepte erstellen, bearbeiten,
als Entwurf speichern oder veröffentlichen. Ein Rezept hat Namen,
Basisportionen, Zubereitungsdauer, Schritte und Zutaten mit Mengen und Einheiten.
Vorhandene Zutaten können ausgewählt oder neue Zutaten angelegt werden.

„Löschen“ verschiebt ein Rezept nach einer Bestätigung in den Papierkorb.
Im Papierkorb kann es wiederhergestellt werden. Eine endgültige Löschung gibt
es in der App nicht. Entwürfe und Papierkorbeinträge sind nicht öffentlich.

## Serverseitige Absicherung

- `recipe_admins`: Mitgliedschaften sind für App-Nutzer weder lesbar noch änderbar.
- `is_recipe_admin`: prüft die Mitgliedschaft anhand von `auth.uid()`.
- `admin_save_recipe`: prüft die Rolle und schreibt Rezept, Zutaten und
  Zutatenmengen in einer Transaktion. Fehler rollen sämtliche Änderungen zurück.
- `admin_set_recipe_deleted`: verschiebt in den Papierkorb oder stellt wieder her.
- RLS erlaubt Admins das Lesen von Entwürfen und Papierkorb. Normale Nutzer haben
  weiterhin nur Lesezugriff auf veröffentlichte, nicht gelöschte Rezepte.
- Rezept-Admins erhalten keinen Zugriff auf fremde private Wochenpläne.
- Keine Service-Keys oder fest codierten Admin-Passwörter im Flutter-Code.

Die erste Mitgliedschaft wird nach Prüfung des Kontos ausschließlich im
Supabase SQL Editor vergeben; die App bietet keine Selbsternennung.

```sql
insert into public.recipe_admins(user_id)
select id from auth.users
where lower(email)=lower('DEINE_BESTAETIGTE_EMAIL')
  and email_confirmed_at is not null
on conflict(user_id) do nothing;
```

## Bestehende Wochenpläne

Geplante Gerichte enthalten einen Snapshot von Namen, Zutaten, Schritten und
Basisportionen. Die Migration ergänzt solche Snapshots für bestehende Pläne.
Bearbeiten oder Löschen eines Katalogrezepts verändert daher keine bereits
gespeicherten Einkaufslisten oder geplanten Gerichte. Für die neue Rezeptfassung
das Gericht entfernen und erneut aus dem Katalog einplanen.

## Prüfung

Die SQL-Prüfung `supabase/tests/recipe_admin.sql` testet Admin-Erstellen,
Bearbeiten, Veröffentlichen, Papierkorb und Wiederherstellen sowie Rollback bei
ungültigen Mengen. Sie prüft, dass normale und anonyme Nutzer weder Rezepte
schreiben noch sich selbst zum Admin ernennen können. Auch der Zugriff von
Rezept-Admins auf fremde Wochenpläne wird gegengeprüft.
Alle dabei angelegten Testkonten und Daten werden zurückgerollt.

Flutter-Tests prüfen Formularwerte und Mengen mit Dezimalkomma, Bearbeitung,
fehlgeschlagenes Speichern, Wiederholen nach Ladefehlern, Löschbestätigung,
Papierkorb und lesbare Wochenplan-Snapshots.

Bei gleichzeitiger Bearbeitung desselben Rezepts gewinnt vorläufig die letzte
Speicherung. Rezeptbilder und endgültige Löschung sind nicht Teil dieser Version.
