# Wochenplan-Umfrage

## Einstieg und Tagesgericht

Ohne Plan öffnet das grüne Feld „Wochenplan erstellen“ direkt die vorhandene
Umfrage bzw. bei bereits beantworteter Umfrage die Budgetbestätigung. Nach der
Planbestätigung erscheint die normale Wochenübersicht mit dem Tagesgericht.
Der ausgewählte Tag bestimmt die Karte; beim Einstieg ist dies der heutige
Wochentag. „Heute“ wird nur beim tatsächlichen heutigen Datum angezeigt.

„Jetzt kochen“ startet den Kochmodus mit den geplanten Portionen und dem Datum
des ausgewählten Tages. Abgeschlossene Gerichte erscheinen als erledigt; die
Karte öffnet dann das Rezept. Freie Tage bieten einen Weg zur Rezeptauswahl.
Vorbereitete Mahlzeiten werden als gegessen markiert statt erneut gekocht.
Wochenplan bearbeiten, Planungsantworten, Wochenwechsel und Budget bleiben
separat erreichbar. Die grüne Budgetkarte wurde durch die Tagesgericht-Karte ersetzt.

## Umfrage und Vorschlag

Der Plan-Tab übernimmt den Einstieg aus Figma 03 und die vier Fragen 03.1–03.4:
feste Ausschlüsse, Ernährungsweise, Personen/Tage und maximale Kochzeit.
Die Antworten werden im benutzerbezogenen Browser-Speicher abgelegt und bei
verbundenem Konto über die Kontodaten synchronisiert. Im Haushalt liegen die
gemeinsamen Planungsregeln im Haushaltsdokument; persönliche Regeln bleiben privat.
Über „Planungsantworten ändern“ bzw. „Antworten ändern“ sind sie erneut erreichbar.

Ein Vorschlag ist ein separater Entwurf. Austauschen, „Passt“ und freie Tage
ändern weder den gespeicherten Plan noch die Einkaufsliste. Erst das erfolgreiche
Bestätigen ersetzt den Wochenplan über das bestehende Repository. Speicherfehler
erhalten den Entwurf und den bisherigen Plan.

Der Generator verwendet unterschiedliche Rezepte aus dem aktuellen Katalog,
beachtet Kochzeit und Portionszahl und lässt fehlende Vorschläge frei.
Unter den passenden Rezepten werden geringere Abneigungen bevorzugt, danach
Favoriten und gemerkte Rezepte. Bei Gleichstand bleibt die Katalogreihenfolge erhalten.
Das Planbudget wird erfasst; eine echte Preisprüfung ist noch nicht angebunden.

## Grenzen der Rezeptdaten

Die Migration `202611170001_recipe_planning_metadata.sql` erweitert Rezepte um
`verified_allergens` und `verified_diets`. Vor dem Start der aktualisierten App
muss sie nach den bisherigen Migrationen im Supabase-Projekt angewendet werden.
Die Reihenfolge steht in [database.md](database.md). Die Ausführung dieser
Migration im Zielprojekt wurde hier nicht unabhängig geprüft.

Rezept-Admins bestätigen die Prüfung im Rezepteditor und wählen enthaltene
Allergene sowie zutreffende Ernährungsweisen. NULL bedeutet ungeprüft; eine
leere Liste bedeutet geprüft ohne Treffer. Bestehende Rezepte bleiben ungeprüft.
Die Allergenauswahl umfasst die sechs Ausschlüsse der Planung, keine vollständige
Allergenkennzeichnung. Vegan wird zusätzlich als vegetarisch gespeichert.

Öffentlicher Katalog und Adminansicht laden diese Angaben. Wochenplan-Snapshots
bewahren ihren bisherigen Stand. Ungeprüfte Rezepte bleiben bei entsprechenden
Einschränkungen ausgeschlossen. Freitext-Ausschlüsse sperren Vorschläge weiterhin;
aus Rezept- oder Zutatennamen wird keine Freigabe abgeleitet.
