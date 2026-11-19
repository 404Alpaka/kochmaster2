# Rezeptverwaltung und Rechte

## Rezeptkategorien

Migration `202611180003_recipe_categories.sql` ergänzt `recipes.categories`.
Sie setzt die bisherigen Rezeptmigrationen und `user_preferences` aus der
Haushaltsmigration voraus. Die Migration ist lokal geprüft. Am 19.11.2026 führte
der Nutzer sie im Supabase-Zielprojekt aus;
Kategorien und Favoritenfunktion wurden anschließend live nachgewiesen. Die
Nachmigration `202611190001_repair_recipe_images.sql` ergänzt die zuvor fehlenden
Bildfelder und Zutatenverknüpfungen, ohne den Kategorien-Speicherweg zu überschreiben.

Im Editor lassen sich Fleisch, Fisch, Vegetarisch, Vegan, Vorspeisen, Hauptgerichte,
Suppen, Salate, Desserts, Frühstück und Snacks mehrfach auswählen. Beim Bearbeiten
werden vorhandene Kategorien geladen. Fleisch/Fisch lassen sich nicht mit
Vegetarisch/Vegan kombinieren. Die Datenbank validiert erlaubte Werte und speichert
die Auswahl atomar mit dem Rezept; ungültige Angaben rollen die gesamte Änderung
zurück. Ältere Clients ohne Kategorienfeld behalten bestehende Kategorien bei.

Kategorien sind redaktionelle Suchmerkmale und ersetzen keine geprüften
Allergen- oder Ernährungsangaben für die Planung. Neue oder bisher nicht
eingeordnete Katalogrezepte erhalten ihre Kategorien im Editor. Eigene Rezepte
speichern ihre Kategorien im privaten Rezept-Snapshot und damit in den Kontodaten.

Die Rezeptseite zeigt Kategorien mit Icons, einen täglich wechselnden Vorschlag
und beliebte Rezepte nach der Anzahl gespeicherter Favoriten. `recipe_popularity`
liefert nur aggregierte Zahlen veröffentlichter, nicht gelöschter Katalogrezepte;
Benutzer-IDs und private Favoritenlisten werden nicht veröffentlicht. Neue Zahlen
werden beim Laden des Katalogs abgerufen. Ohne Zahlen wird keine Beliebtheit erfunden.
Titel, Herz zur Sammlung und Suche bleiben beim Scrollen in einem transparenten,
leicht unscharfen Kopf sichtbar.

Prüfung: `node tool/test_recipe_categories.mjs` sowie
`flutter test test/recipe_categories_test.dart test/admin_recipes_test.dart`.

## Katalogpflege vom 19.11.2026

Der öffentliche Katalog enthielt 21 Rezepte ohne Kategorien und ohne Bildadresse.
`202611190002_curate_recipe_catalog.sql` ergänzt die anhand von Namen und
Zutaten redaktionell eingeordneten Kategorien. Die Migration prüft vor jeder
Änderung Rezept-ID, Namen und die vollständige Zutaten-Namensliste. Bestehende
Kategorien und Bildadressen werden erhalten; geänderte Rezepte werden übersprungen.
Die vorbereitete Zuordnung liegt zusätzlich in
`supabase/data/catalog_curation_20261119.json` zur Prüfung vor.

Der Nutzer hat die Migration ausgeführt. Die anschließende Live-API-Prüfung
bestätigte 21 kategorisierte Rezepte, 2 Rezepte mit Bild und 19 ohne Bild.
Die Fotos sind ausdrücklich nur Tomaten-Spinat-Pasta und Brokkoli-Reis-Pfanne
zugeordnet. Die bisherige automatische Zuordnung eines Pasta-/Reisfotos anhand
des Namens wurde entfernt. Fehlende Bilder erscheinen als neutraler Platzhalter;
fehlerhafte Bildadressen als nicht verfügbares Bild. Die Beschriftung unterscheidet
fehlende Bilder, Stockfotos und ausdrücklich hinterlegte Rezeptbilder.

Im Editor kann ein unpassendes Bild über „Bild ändern“ → „Kein Bild“ entfernt
werden. Der optionale Seed liefert bei seinen beiden Rezepten passende Kategorien
und Bildadressen und wird erst nach den Schema-Migrationen ausgeführt.

Die Kategorien sind Suchmerkmale, keine geprüften Ernährungs- oder Allergenangaben.
`verified_diets` und `verified_allergens` sowie vorhandene Plan-Snapshots werden
durch die Katalogpflege nicht verändert. Weitere echte Rezeptfotos müssen jeweils
passend ergänzt werden; die 19 fehlenden Bilder werden nicht durch fremde Gerichte ersetzt.

Prüfungen: `node tool/test_catalog_curation.mjs` sowie
`flutter test test/recipe_image_test.dart test/recipe_categories_test.dart`.
Die SQL-Prüfung umfasst wiederholte Ausführung, eigene Kategorien/Bildadressen
und seit der Prüfung veränderte Rezepte.

## Verwendung

Der Editor bietet 21 Kategorien, darunter Eintöpfe, Aufläufe, Backen, Pasta,
Reisgerichte, Kartoffelgerichte, Brot & Brötchen, Kuchen & Gebäck, Grillen sowie
Soßen & Dips. Salate bleiben als vorhandene Kategorie erhalten. Für die neuen
Werte ist `202611190004_more_recipe_categories.sql` erforderlich.
Ein Tippen außerhalb eines Eingabefelds oder Scrollen schließt die Tastatur;
bei geöffneter Tastatur gibt es zusätzlich oben „Tastatur schließen“.

Im Rezepteditor bietet „Bild ändern“ Kamera und Galerie an. Die Kamera ist auf
Android/iOS und in unterstützten mobilen Browsern verfügbar; am Desktop wird
die Dateiauswahl angeboten. Auswahl und Vorschau sind lokal. Erst „Rezept speichern“
lädt das Foto in Supabase Storage hoch und speichert die öffentliche Bildadresse.
JPG, PNG und WebP bis 8 MB werden akzeptiert. Der Picker verkleinert nach Möglichkeit
auf 1600 Pixel und reduziert die JPEG-Qualität auf 85 Prozent.

Dafür `supabase/migrations/202611190003_recipe_photo_uploads.sql` ausführen.
Der öffentliche Bucket `recipe-images` erlaubt Uploads nur freigeschalteten
Rezept-Admins in deren eigenem Nutzerordner. Bestehende Bilder werden nicht
überschrieben. Auch Bilder von Entwürfen sind über ihre Bildadresse öffentlich;
keine privaten Fotos verwenden. Wird nach erfolgreichem Upload die Rezeptspeicherung
abgebrochen, kann ein unreferenziertes Bild bestehen bleiben. Ein erneuter
Speicherversuch im selben Editor verwendet die bereits hochgeladene Adresse.

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
Speicherung. Bildadressen werden unterstützt (siehe unten); eine endgültige
Löschung bietet die App nicht an.

## Geprüfte Planungsangaben

Vor Verwendung der aktualisierten App die Migration
`202611170001_recipe_planning_metadata.sql` nach den bisherigen Migrationen
anwenden. Die vollständige Reihenfolge steht in [database.md](database.md).
Die zugehörigen Spalten wurden am 19.11.2026 über die Live-API nachgewiesen.

Im Rezepteditor lassen sich Allergene und Ernährungsweisen unabhängig als
geprüft markieren. Nur nach Prüfung der Zutaten und Zubereitung bestätigen.
Ohne Bestätigung bleibt die jeweilige Angabe unbekannt. Eine bestätigte leere
Allergenliste bedeutet: keines der sechs in der Planung angebotenen Allergene.
Das ist keine vollständige Allergenkennzeichnung. Vegan schließt vegetarisch ein.
Die Datenbank weist unbekannte Werte und widersprüchliche Ernährungsangaben
zurück; Speicherung erfolgt zusammen mit dem Rezept in einer Transaktion.

## Bilder und verknüpfte Zutaten

Zusätzlich `202611170002_recipe_images_and_step_links.sql` nach der Metadaten-
Migration ausführen. Im verwendeten Projekt wurde die ältere Lücke am 19.11.2026
durch `202611190001_repair_recipe_images.sql` nachgezogen und live geprüft.
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
