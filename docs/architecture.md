# Kochmaster: Struktur und Ausbau

Stand: 25.11.2026. Flutter-App mit Schwerpunkt Web und Supabase für Rezeptkatalog,
Authentifizierung und kontobezogene Daten. Android- und iOS-Projekte sind vorhanden;
deren Sitzungen werden über geschützten Gerätespeicher dauerhaft gespeichert.
Die Implementierung ist mit simuliertem Speicher getestet; Gerätetests stehen aus.
Einstellungen und Gastdaten nutzen auch nativ dauerhaften lokalen Speicher.
Katalog und geladene Kontodaten besitzen getrennte Offline-Kopien; Offline-Häkchen
werden gezielt gegen den aktuellen Cloudplan abgeglichen. Details und Web-Build:
[Offline-Nutzung](offline.md).

## Jetzt angelegt

```text
lib/
  main.dart
  app/                          App-Start, Theme und Navigation
  features/
    recipes/
      domain/                   Rezept, Zutatenmengen, Repository-Vertrag
      data/                     Supabase-Katalog, Adminzugriff und Demo-Datenquelle
      presentation/             Rezeptansicht und Rezeptverwaltung
    auth/                       Registrierung, Anmeldung, Passwort-Reset und Sitzung
    account_data/               Persönliche Kontodaten und Versionsvergleich
    households/                 Haushalte, Mitgliedschaften und Einladungen
    meal_planning/domain/       Geplantes Gericht mit Portionenzahl
    meal_planning/data/         Private und gemeinsame Wochenpläne
    meal_planning/presentation/ Planung, Vorrat, Kochmodus und Rückblick
    shopping/domain/            Skalierung und Zusammenfassung der Zutaten
test/                           Fachlogik und durchgängiger UI-Ablauf
docs/                           Architektur und Ausbauplanung
supabase/migrations/            Schema, RLS und Datenbankfunktionen
supabase/tests/                 SQL-Prüfungen
```

Jeder Funktionsbereich erhält bei Bedarf `presentation/`, `application/`,
`domain/` und `data/`. Fachlogik bleibt unabhängig von Flutter und Supabase.
Der App-Rahmen liegt in `app/kochmaster_app.dart`. Die Planungsoberfläche ist auf
`planning_page.dart` und zugehörige `part`-Dateien im Planungsfeature aufgeteilt.

## Geplanter Ausbau

- Frühstücks- und Mittagsplanung als eigene Mahlzeitenbereiche ergänzen. Aktuell
  sind Entdecken, Empfehlungen und automatische Planung auf Abendessen ausgerichtet;
  Frühstücksrezepte wie Porridge werden dort ausgeblendet.

- Pagination für den öffentlichen Katalog ergänzen; aktuell höchstens 100 Rezepte.
- Versionsvergleich für Katalogrezepte ergänzen.
- Android-/iOS-Gerätetests und native Rückleitungen für Auth-Links ergänzen.
- Echtzeit-Synchronisierung und gemeinsame Transaktionen für zusammengehörige
  Plan- und Vorratsänderungen prüfen.
- Packungsgrößen, Nährwertquellen und nachvollziehbare Kalorien-, Protein-
  und Budgetoptimierung ausbauen. Die vorhandene Allergenauswahl umfasst nur
  die angebotenen Planungsausschlüsse.
- Händlerprodukte, zeitgestempelte Preise und bestellbare Packungen anbinden.
  Echte Händlerzugänge sind Voraussetzung für Bestellungen und aktuelle Preise.

## Aktueller Umfang

Öffentlicher Supabase-Katalog mit Suche, Rezeptdetails und Portionsskalierung;
eine separate Demo-Datenquelle lässt sich ausdrücklich aktivieren. Datierte
Kalenderwochen unterstützen ein Gericht pro Tag, Planungsvorschläge und eine
abhakbare Einkaufsliste. Vergleichbare Mengen werden anhand der Zutaten-ID in
Gramm, Milliliter und Stück zusammengefasst. Planung, Vorratsabgleich, Einkauf und
Kochverbrauch nutzen dieselbe Umrechnung. Unbekannte Packungsinhalte und
unterschiedliche Dimensionen werden nicht ineinander umgerechnet.

Registrierung, E-Mail-Bestätigung, Anmeldung, Abmeldung und Passwort-Reset sind
implementiert. Web-Sitzungen werden im Browser, Android-/iOS-Sitzungen im
geschützten Gerätespeicher gespeichert. Private Wochenpläne,
Einkaufsstatus und persönliche Kontodaten liegen in Supabase. Haushalte teilen
Plan, Einkauf, Vorrat und weitere Planungsdaten mit rollenabhängigen Rechten.
Kontodokumente, gemeinsame Haushaltsdaten und private Wochenpläne besitzen
Versionsnummern. Private Pläne benötigen dafür die Migration `202611180001`.

Rezept-Admins bearbeiten Entwürfe, veröffentlichen Rezepte und nutzen einen
Papierkorb. Bildadressen, verknüpfte Zutaten und geprüfte Planungsangaben werden
unterstützt. Gespeicherte Pläne erhalten Rezept-Snapshots. Vorschläge beachten
geprüfte Einschränkungen, Kochzeit, Abneigungen, Favoriten und gemerkte Rezepte.
Produktpreise, Bestellungen und eine echte Nährwertoptimierung fehlen noch.

Einrichtung und Grenzen: [Datenbank](database.md), [Konten](accounts.md),
[Haushalte](households.md), [Rezeptverwaltung](admin.md),
[Planungsumfrage](planning-survey.md).
## Essenspräferenzen auf der Startseite

Bis die Präferenzen übernommen wurden, öffnet die grüne Karte „So isst du“ zwischen den Startkacheln und dem Tagesrezept
eine eigene Einstellungsseite für Ernährungsweise, Allergenausschlüsse, Portionen,
Planungstage, maximale Kochzeit und Wochenbudget. Änderungen werden erst beim
Übernehmen auf die vorhandenen Planungsparameter angewendet. Gespeicherte Pläne
werden nicht automatisch geändert. Die Speicherung nutzt den bestehenden
Kontodatenspeicher bzw. im Web ohne Konto den lokalen Präferenzspeicher.
Budgetangaben sind ein Planungsziel; Live-Produktpreise werden noch nicht geprüft.
Nach dem Übernehmen verschwindet die Startkarte. Über das Profilsymbol bleibt
„Essenspräferenzen“ erreichbar. Auch die erste Planerstellung öffnet dieselbe
Einstellungsseite. Anschließend erzeugt der Planer direkt einen Vorschlag;
eine zusätzliche Budgetbestätigung und die bisherigen Budget-Hinweiskarten entfallen.
