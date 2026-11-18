# Wochenplan-Umfrage

Der Plan-Tab übernimmt den Einstieg aus Figma 03 und die vier Fragen 03.1–03.4:
feste Ausschlüsse, Ernährungsweise, Personen/Tage und maximale Kochzeit.
Die Antworten werden im vorhandenen benutzerbezogenen Browser-Speicher abgelegt.
Über „Planungsantworten ändern“ bzw. „Antworten ändern“ sind sie erneut erreichbar.

Ein Vorschlag ist ein separater Entwurf. Austauschen, „Passt“ und freie Tage
ändern weder den gespeicherten Plan noch die Einkaufsliste. Erst das erfolgreiche
Bestätigen ersetzt den Wochenplan über das bestehende Repository. Speicherfehler
erhalten den Entwurf und den bisherigen Plan.

Der Generator verwendet unterschiedliche Rezepte aus dem aktuellen Katalog,
beachtet Kochzeit und Portionszahl und lässt fehlende Vorschläge frei.
Favoritengewichtung ist noch nicht angeschlossen.

## Grenzen der Rezeptdaten

Die Migration `202611170001_recipe_planning_metadata.sql` erweitert Rezepte um
`verified_allergens` und `verified_diets`. Vor dem Start der aktualisierten App
muss sie nach den bisherigen Migrationen im Supabase-Projekt angewendet werden.
Sie ist lokal vorbereitet und hier noch nicht auf einer Datenbank ausgeführt.

Rezept-Admins bestätigen die Prüfung im Rezepteditor und wählen enthaltene
Allergene sowie zutreffende Ernährungsweisen. NULL bedeutet ungeprüft; eine
leere Liste bedeutet geprüft ohne Treffer. Bestehende Rezepte bleiben ungeprüft.
Die Allergenauswahl umfasst die sechs Ausschlüsse der Planung, keine vollständige
Allergenkennzeichnung. Vegan wird zusätzlich als vegetarisch gespeichert.

Öffentlicher Katalog und Adminansicht laden diese Angaben. Wochenplan-Snapshots
bewahren ihren bisherigen Stand. Ungeprüfte Rezepte bleiben bei entsprechenden
Einschränkungen ausgeschlossen. Freitext-Ausschlüsse sperren Vorschläge weiterhin;
aus Rezept- oder Zutatennamen wird keine Freigabe abgeleitet.
