# TODO – Kochmaster

Zentrale Liste für offene Aufgaben und Optimierungen. Neue Punkte als `- [ ]`
ergänzen und erledigte Aufgaben mit `- [x]` markieren.

## Prüfung und Qualität

- [ ] Registrierung, E-Mail-Bestätigung und Passwort-Zurücksetzen mit echten E-Mails und der verwendeten App-Adresse durchgängig prüfen.
  - Vorprüfung am 18.11.2026: Fünf automatisierte Prüfungen für Registrierung, Formularvalidierung und Auth-/Planspeicherung bestanden. Der Recovery-Test bleibt hängen und muss separat untersucht werden.
  - Noch benötigt: vollständige lokale App-URL inklusive Port sowie Prüfung der Bestätigungs- und Reset-Mails im selben Browser. Der echte E-Mail-Test ist noch offen.
- [ ] Status des automatisierten Recovery-Tests prüfen und das Ergebnis in `docs/accounts.md` dokumentieren.
- [ ] Veraltete Angaben in der Dokumentation aktualisieren, insbesondere Funktionsumfang und Ausbauplanung in `docs/architecture.md` sowie den Hinweis auf noch fehlendes Passwort-Zurücksetzen in `docs/accounts.md`.

## Funktionen und Optimierungen

- [ ] Pagination für den Rezeptkatalog ergänzen; laut `docs/database.md` werden aktuell maximal 100 Rezepte geladen.
- [ ] Versionsvergleich für private Wochenpläne ergänzen, damit gleichzeitige Änderungen in mehreren Tabs erkannt werden.
- [ ] Dauerhafte Sitzungsspeicherung für native Plattformen ergänzen, sobald Android/iOS eingesetzt werden.
- [ ] Produktpreise als Grundlage für eine nachvollziehbare Budgetprüfung der Planung anbinden.

## Neue Aufgaben und Ideen

<!-- Hier weitere Aufgaben, Fehler und Verbesserungsideen eintragen. -->

## Erledigt

<!-- Abgeschlossene Aufgaben bei Bedarf hierher verschieben. -->
