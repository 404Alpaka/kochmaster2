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

## Geprüfte Planungsangaben

Vor Verwendung der aktualisierten App die Migration
`202611170001_recipe_planning_metadata.sql` nach den bisherigen Migrationen
anwenden. Die Migration und die erweiterten SQL-Prüfungen sind lokal vorbereitet;
eine Ausführung auf Supabase ist hier noch nicht erfolgt.

Im Rezepteditor lassen sich Allergene und Ernährungsweisen unabhängig als
geprüft markieren. Nur nach Prüfung der Zutaten und Zubereitung bestätigen.
Ohne Bestätigung bleibt die jeweilige Angabe unbekannt. Eine bestätigte leere
Allergenliste bedeutet: keines der sechs in der Planung angebotenen Allergene.
Das ist keine vollständige Allergenkennzeichnung. Vegan schließt vegetarisch ein.
Die Datenbank weist unbekannte Werte und widersprüchliche Ernährungsangaben
zurück; Speicherung erfolgt zusammen mit dem Rezept in einer Transaktion.

## Bilder und verknüpfte Zutaten

Zusätzlich `202611170002_recipe_images_and_step_links.sql` nach der Metadaten-
Migration ausführen. Lokal vorbereitet, noch nicht im Supabase-Projekt ausgeführt.
Die Migration ergänzt `recipes.image_url` und `recipe_ingredients.step_key` und
aktualisiert das atomare Speichern. Die SQL-Tests setzen beide Migrationen voraus.

„Bild ändern“ bietet die vorhandenen Bilder sowie eine öffentliche HTTPS-
Bildadresse. Die Adresse wird gespeichert, kein Bild hochgeladen. Externe Bilder
müssen im Browser öffentlich ladbar sein; Fehler erscheinen als Bildhinweis.

„Zutat einfügen“ erzeugt einen sichtbaren Baustein in der Form `⟦200 g Reis⟧`.
Menge, Einheit und Zutatenname aktualisieren sich beim Bearbeiten der Zutaten.
Änderungen der Basisportionen skalieren die Zutatenmengen. Weitere Zutaten können
jederzeit als Baustein eingefügt werden. Beim Entfernen einer verwendeten Zutat
erscheint ein Hinweis im Text; dieser muss vor dem Speichern bereinigt werden.

Gespeichert werden dauerhafte Zutatenreferenzen. Rezeptansicht und Kochmodus
berechnen deren Mengen für die gewählte Portionenzahl; Snapshots erhalten Bild
und Verknüpfungen. Freier Text (einschließlich Zeiten und Temperaturen) bleibt
unverändert. Bereits früher als normaler Text eingefügte Mengen müssen einmal
über „Zutat einfügen“ neu verknüpft werden.
