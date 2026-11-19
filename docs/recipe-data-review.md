# Rezeptdatenpflege vom 19.11.2026

Die Ergänzung `202611190007_curate_planning_metadata.sql` wurde direkt über den
angemeldeten Supabase SQL Editor angewandt. Die anschließende öffentliche
API-Prüfung bestätigt 23 veröffentlichte Rezepte, davon 20 mit Hauptbeilage und
Gerichtsart sowie 18 mit einer einzelnen dominanten Hauptzutat. Auch die
Zubereitungsart wurde für die 20 nachvollziehbaren Rezepte ergänzt. Einige
Geschmacksmerkmale sind unmittelbar durch Zutaten belegt, etwa Zimt, Curry,
Zitrone oder Sahne. Es wurden keine aktiven Minuten, Kostenklassen oder
Allergen-/Ernährungsfreigaben geschätzt.

## Noch inhaltlich zu korrigieren

| Rezept-ID | Eintrag | Befund |
|---|---|---|
| 614d1ae0-abf3-4c47-8845-9167a9e7d1b1 | Thunfischsalat | Zubereitung und Zutaten unvollständig; keine verlässliche Einordnung. |
| 6838b094-b540-47d7-bc8d-dff8539fc7cd | jannic wirs gefeuert | Zubereitung und Zutaten unvollständig; keine verlässliche Einordnung. |
| 7ec943e4-f288-422a-b98d-b05aa0415771 | Hähnchen mit Nudeln | Hähnchen fehlt in der Zutatenliste; Zubereitung unvollständig. |

Diese drei Einträge wurden nicht geändert oder unveröffentlicht. Vor einer
weiteren fachlichen Einordnung müssen vollständige, zueinander passende Zutaten
und Zubereitung vorliegen. Mengen und Zubereitung wurden auch bei den übrigen
Rezepten nicht verändert.

Gemüse-Bulgur und herzhafte Gemüsepfannkuchen haben mehrere gleichwertige
Gemüsekomponenten. Ihre dominante Hauptzutat bleibt deshalb unbekannt.

Frühstücksrezepte behalten ihre Daten für spätere Mahlzeitenbereiche, bleiben
aber durch den bestehenden Abendessen-Filter aus der aktuellen Auswahl und
automatischen Planung ausgeblendet.

## Nachweis und Wiederholbarkeit

- Datenbasis und redaktionelle Zuordnung: `supabase/data/planning_metadata_curation_20261119.json`.
- Angewandte Ergänzung: `supabase/migrations/202611190007_curate_planning_metadata.sql`.
- Lokaler SQL-Test: `tool/test_planning_metadata_curation.mjs`.
- Live-Zählung: `tool/audit_weekly_planner.ps1`.

Der SQL-Test besteht: Ergänzung, Wiederholung ohne erneute Änderungen,
Erhalt bestehender Werte und unveränderter Zertifizierungen sowie Überspringen
von Rezepten mit geänderten Namen, Zutaten, Mengen, Portionen, Schritten oder
Veröffentlichungsstatus. Die Ergänzung setzt voraus, dass die aktuelle Rezeptbasis
noch dem geprüften Schnappschuss entspricht. Der Editor unterstützt zusätzlich
Couscous, Bulgur und Haferflocken als getrennte primäre Hauptbeilagen.
