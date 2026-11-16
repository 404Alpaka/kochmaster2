# Kochmaster: Struktur und Ausbau

Grundlage: bisherige Planung in „Startupidee entwickeln“. Flutter für Android,
iOS und die interaktive Web-App; Supabase als vorgesehene zentrale Datenplattform.
Backend- und Produktvorschläge sind noch keine produktiven Integrationen.

## Jetzt angelegt

```text
lib/
  main.dart
  app/                          App-Start, Theme und Navigation
  features/
    recipes/
      domain/                   Rezept, Zutatenmengen, Repository-Vertrag
      data/                     Austauschbare Demo-Datenquelle
    meal_planning/domain/       Geplantes Gericht mit Portionenzahl
    shopping/domain/            Skalierung und Zusammenfassung der Zutaten
test/                           Fachlogik und durchgängiger UI-Ablauf
docs/                           Architektur und Ausbauplanung
```

Jeder Funktionsbereich erhält bei Bedarf `presentation/`, `application/`,
`domain/` und `data/`. Fachlogik bleibt unabhängig von Flutter und Supabase.
Die erste Oberfläche liegt noch gemeinsam in `app/kochmaster_app.dart`;
bei Ausbau werden die Seiten in die jeweiligen Features verschoben.
Keine leeren Modulgerüste und keine zusätzlichen Pakete für den ersten Prototyp.

## Geplanter Ausbau

1. `recipes/presentation`, `meal_planning/presentation`, `shopping/presentation`:
   Oberflächen aufteilen; echte Datumswochen, mehrere Mahlzeiten, lokale Speicherung.
2. `supabase/migrations`, `supabase/seed.sql`, `supabase/functions`:
   versioniertes Schema, geprüfte Rezepte, Zutaten-IDs, Auth und RLS.
   Zunächst getrennte Entwicklungsumgebung; keine geheimen Schlüssel in Flutter.
3. Features `auth`, `profiles`, `households`: Nutzer, Mitgliedschaften,
   Präferenzen, Haushaltsbudget und gemeinsame Listen.
4. `nutrition` und `planning`: Nährwertquellen, Allergene, Einheitenumrechnung,
   nachvollziehbare Kalorien-, Protein- und Budgetoptimierung.
5. `retailers`, `catalog`, `cart`, `orders`: Rezeptzutaten, Händlerprodukte,
   zeitgestempelte Preise und bestellbare Packungen getrennt modellieren.
   Echte Händlerzugänge sind Voraussetzung für Bestellungen und aktuelle Preise.
6. Separates Admin-Werkzeug für redaktionelle Freigabe; bei Bedarf öffentliche
   Rezeptwebsite und eigener Optimierungsdienst. Erst dann gemeinsame Pakete
   oder ein `apps/`-Monorepo einführen.

## Aktueller Umfang

Zwei Beispieldatensätze, Rezeptdetails, Suche, sieben Planplätze,
Portionenskalierung und abhakbare Einkaufsliste. Zusammenfassung erfolgt anhand
Zutaten-ID und Einheit; unterschiedliche Einheiten werden nicht blind addiert.
Alle Änderungen liegen ausschließlich im Arbeitsspeicher. Keine Anmeldung,
Cloudspeicherung, echten Preise oder berechneten Nährwerte vorhanden.
