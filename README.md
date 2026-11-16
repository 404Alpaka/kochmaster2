# Kochmaster

Flutter-Web-App mit Rezepten aus dem Supabase-Katalog.

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

Konten: Registrierung mit E-Mail-Bestätigung, Anmeldung und Abmeldung.
Die Web-Sitzung wird beim Neustart wiederhergestellt.
Details und Testumfang: [docs/accounts.md](docs/accounts.md).

