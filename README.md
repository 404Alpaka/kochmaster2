# Kochmaster

Flutter-Web-App mit Rezepten aus dem Supabase-Katalog.

Die App öffnet mit einer Startseite: persönliche Begrüßung, Schnellzugriffe auf
Wochenplan und Kochmodus des heutigen Gerichts, täglicher Rezeptvorschlag und Hinweise zu Plan und
Vorrat. Der runde Profilknopf führt zum Haushalt. Die untere Navigation enthält
Start, Rezepte, Plan, Vorrat und Korb.

```powershell
flutter pub get
flutter run -d chrome
```

Der normale Start lädt veröffentlichte Rezepte einschließlich Zutaten und
Zubereitung aus dem konfigurierten Supabase-Projekt. Suche, Rezeptdetails,
Portionswahl, Wochenplan und Einkaufsliste verwenden diese Daten.
Mit Konto werden Wochenplan und abgehakte Einkaufspositionen je Kalenderwoche in Supabase gespeichert. Rezepte sind ohne Anmeldung sichtbar.

Der öffentliche Publishable-Key in `lib/core/config/app_config.dart` erlaubt
ausschließlich die durch die Datenbankrichtlinien freigegebenen Zugriffe.
Ein anderes Projekt lässt sich mit `--dart-define-from-file=config/supabase.local.json`
konfigurieren. Secret- oder service_role-Keys gehören niemals in die App.

Offline-Demo ausdrücklich starten:

```powershell
flutter run -d chrome --dart-define=USE_DEMO=true
```

Prüfung und Web-Build:

```powershell
flutter analyze
flutter test
flutter test test/supabase_live_test.dart --dart-define=RUN_LIVE_TESTS=true
flutter build web
```

Der Live-Test benötigt Netzwerk und liest nur den öffentlichen Katalog.
Die Standardtests greifen nicht auf die Datenbank zu.
Weitere Planung: [Architektur](docs/architecture.md), [Datenbank](docs/database.md).

Konten: Registrierung mit E-Mail-Bestätigung, Anmeldung, Abmeldung und Passwort-Reset.
Die Registrierung erfasst Vor- und Nachnamen; eine Kundennummer wird serverseitig
erzeugt. Dafür zusätzlich `202611180002_customer_profiles.sql` anwenden.
Die Web-Sitzung wird beim Neustart wiederhergestellt.
Android und iOS speichern Sitzungen im geschützten Gerätespeicher; Gerätetests
stehen noch aus. Android benötigt mindestens API 24.
Details und Testumfang: [docs/accounts.md](docs/accounts.md).


Kontoweite persönliche Daten und echte Haushalte: [docs/households.md](docs/households.md).
Bei neuer Einrichtung alle Migrationen gemäß [Datenbankeinrichtung](docs/database.md)
anwenden. Die App führt Migrationen nicht automatisch aus.
Haushalte teilen Plan, Einkauf und Vorrat; persönliche Favoriten und Regeln bleiben privat.
