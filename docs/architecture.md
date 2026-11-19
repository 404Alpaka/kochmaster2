# Kochmaster: Struktur und Ausbau

Stand: 18.11.2026. Flutter-App mit Schwerpunkt Web und Supabase für Rezeptkatalog,
Authentifizierung und kontobezogene Daten. Android- und iOS-Projekte sind vorhanden;
deren Sitzungen werden über geschützten Gerätespeicher dauerhaft gespeichert.
Die Implementierung ist mit simuliertem Speicher getestet; Gerätetests stehen aus.

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

- Pagination für den öffentlichen Katalog ergänzen; aktuell höchstens 100 Rezepte.
- Versionsvergleich für Katalogrezepte ergänzen.
- Android-/iOS-Gerätetests und native Rückleitungen für Auth-Links ergänzen.
- Echtzeit-Synchronisierung und gemeinsame Transaktionen für zusammengehörige
  Plan- und Vorratsänderungen prüfen.
- Einheitenumrechnung, Nährwertquellen und nachvollziehbare Kalorien-, Protein-
  und Budgetoptimierung ausbauen. Die vorhandene Allergenauswahl umfasst nur
  die angebotenen Planungsausschlüsse.
- Händlerprodukte, zeitgestempelte Preise und bestellbare Packungen anbinden.
  Echte Händlerzugänge sind Voraussetzung für Bestellungen und aktuelle Preise.

## Aktueller Umfang

Öffentlicher Supabase-Katalog mit Suche, Rezeptdetails und Portionsskalierung;
eine separate Demo-Datenquelle lässt sich ausdrücklich aktivieren. Datierte
Kalenderwochen unterstützen ein Gericht pro Tag, Planungsvorschläge und eine
abhakbare Einkaufsliste. Mengen werden anhand von Zutaten-ID und Einheit summiert;
unterschiedliche Einheiten werden nicht automatisch umgerechnet.

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
