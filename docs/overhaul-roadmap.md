# Überarbeitung der App

Priorisierung aus der Analyse vom 25.11.2026:

1. Datenverwaltung: lokale Bereinigung, persönliche Cloud-Daten und Kontolöschung
   trennen; persönliche Daten einschließlich aller privaten Wochenpläne als Datei
   exportieren. Umsetzung und Aktivierung: [Datenverwaltung](data-management.md).
2. Restportionen und Haushaltsplanung: beim Reservieren für andere Kalenderwochen
   den aktiven privaten oder gemeinsamen Planspeicher verwenden. Im Code
   umgesetzt; Details und Tests: [Restportionenplanung](weekly-planner.md#restportionen-über-kalenderwochen-hinweg).
3. Mengenberechnung und Einkaufshäkchen vereinheitlichen. Im Code umgesetzt;
   Details und Tests: [Einheitliche Mengen](weekly-planner.md#einheitliche-mengen-und-einkaufshäkchen).
4. Offline-Nutzung und dauerhafte mobile Speicherung ausbauen. Im Code umgesetzt;
   Umfang, Abgleich und Web-Build: [Offline-Nutzung](offline.md).
5. Rezeptqualität und Veröffentlichungsprüfung verbessern.
6. Synchronisierung und zusammengehörige Haushaltsänderungen absichern.
7. Alltagstauglichen Einkauf mit Kategorien, Packungsgrößen und bestätigter
   Übernahme gekaufter Mengen in den Vorrat ausbauen.
8. Planung, Vorrat, Einkauf und Kochmodus technisch entflechten. Erster Schritt:
   Der Kochmodus besitzt seinen eigenen Sitzungszustand in
   `lib/features/meal_planning/presentation/cooking_session.dart`; Planung,
   Vorrat und Einkauf werden schrittweise weiter entkoppelt.
9. **Wiederkehrende wöchentliche Einkäufe:** eine bearbeitbare Standardliste für
   Lebensmittel und Haushaltsartikel, die unabhängig vom Rezeptplan jede Woche
   gebraucht werden, beispielsweise sechs Bananen, ein Liter Milch oder Brot.
   Name, Menge und Einheit je Eintrag speichern; Einträge pausieren oder für eine
   einzelne Woche auslassen können. Die aktive Liste einmal je Kalenderwoche in
   den Einkauf übernehmen, ohne beim erneuten Öffnen Duplikate zu erzeugen.
   Mengen mit gleichem Rezeptbedarf zusammenführen und den Einkaufsstatus je
   Woche getrennt führen. Private und gemeinsame Haushaltslisten unterscheiden.

Weitere Produktthemen: echter Webseiten-Rezeptimport, eigene Mahlzeitenbereiche
für Frühstück und Mittagessen sowie situationsabhängige Aktionen auf der Startseite.
