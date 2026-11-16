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

Das bestehende Supabase-Schema liefert noch keine geprüften Allergene oder
Ernährungsweisen. Das Rezeptmodell unterstützt dafür optional
`verifiedAllergens` und `verifiedDiets`; null bedeutet unbekannt. Solange die
Katalogpflege diese Werte nicht liefert, sind solche Rezepte bei entsprechenden
Einschränkungen ausgeschlossen. Freitext-Ausschlüsse sperren automatische
Vorschläge bis eine überprüfte Zuordnung verfügbar ist. Es gibt keine aus Namen
abgeleitete Allergie-Freigabe. Die UI weist auf fehlende geprüfte Daten hin.

Die Umfrage kann bereits vollständig verwendet werden. Für produktive Vorschläge
mit Allergien/Ernährungsweisen müssen Datenbank, Rezeptpflege und Katalogabfrage
um diese geprüften Metadaten erweitert werden.
