# Offline-Nutzung und Gerätespeicher

Stand: 25.11.2026. Für diese Erweiterung ist keine Datenbankmigration nötig.

## Verfügbare Daten

- Theme, Einstellungen, Gastvorrat, Gastpläne und Einkaufshäkchen werden auch
  unter Android und iOS dauerhaft über `SharedPreferencesAsync` gespeichert.
  Bestehende Web-Einstellungen bleiben mit dem bisherigen Browserformat kompatibel.
- Der öffentliche Rezeptkatalog wird je Supabase-Projekt lokal gespeichert und
  beim Start im Hintergrund aktualisiert. Zutaten und Kochschritte sind offline
  verfügbar; externe Rezeptbilder können fehlen. Beliebtheitsstatistiken sind
  optional und blockieren den Katalog bei einem Fehler nicht.
- Nach erfolgreichem Laden werden Kontodaten und besuchte Kalenderwochen lokal
  gespeichert. Die Kopien sind nach Projekt, Konto und privatem oder gemeinsamem
  Haushalt getrennt. Ein Verbindungsfehler aktiviert den gekennzeichneten
  Offline-Stand. Nicht besuchte Wochen stehen offline nicht zur Verfügung.
  Berechtigungs-, Datenbank- und Anmeldefehler lösen diesen Ersatz nicht aus.
- Im Offline-Stand lassen sich Plan und Vorrat lesen sowie Rezepte und der
  Kochmodus öffnen. Planänderungen, Vorratsbuchungen, der Kochabschluss und
  Cloud-Kontoaktionen benötigen eine Verbindung. Gastdaten bleiben lokal bearbeitbar.

## Einkaufshäkchen abgleichen

Einkaufshäkchen lassen sich im bereits geladenen privaten oder gemeinsamen Plan
offline ändern; Haushaltsmitglieder mit Leserechten bleiben beim Lesezugriff.
Die Oberfläche bestätigt eine Offline-Änderung erst nach erfolgreicher lokaler
Speicherung. Ein Speicherfehler wird angezeigt.

„Cloudstand aktualisieren“ lädt Konto, Mitgliedschaften und den aktuellen
Wochenplan neu. Nur tatsächlich lokal geänderte Häkchen werden übernommen, wenn
Zutat, Einheit und benötigte Menge weiterhin übereinstimmen. Andere Cloud-Häkchen
und alle Cloud-Gerichte bleiben erhalten. Ein Mengenwechsel erzeugt einen Hinweis
zur erneuten Prüfung. Die normalen Rollen- und Versionsprüfungen gelten weiter.
Bei einem Konflikt bleiben lokale Häkchen bis zum nächsten Abgleich gespeichert.
Synchronisierung erfolgt bewusst über diesen Knopf oder beim erneuten Online-Laden,
ohne automatische Änderungen an Plan oder Vorrat.

## Daten und Anmeldung

Die neue Ablage enthält keine zusätzlichen Anmeldetokens. Native Tokens bleiben
im bestehenden geschützten Auth-Speicher. Eine bereits gespeicherte Identität
kann bei fehlgeschlagener Token-Erneuerung wegen Verbindungsproblemen zum Lesen
der Offline-Kopie erhalten bleiben; Serverzugriffe benötigen eine gültige Sitzung.
Lokale App-Daten sind kein verschlüsseltes Backup. „Lokale Kopien entfernen“
löscht auch die Offline-Kopien und noch nicht synchronisierte Häkchen dieses Kontos.
Abmelden allein entfernt diese Kopien nicht. Browser können Website-Daten löschen;
nach gelöschten App-Daten oder vor dem ersten Online-Laden gibt es keine Offline-Kopie.

## Web-Version bauen

Die App-Dateien brauchen neben den Daten einen eigenen Service Worker:

```powershell
flutter build web --no-wasm-dry-run --no-web-resources-cdn
node tool/prepare_offline_web.mjs
```

Das Vorbereitungsskript erzeugt aus dem vollständigen Build ein versioniertes
Manifest und aktiviert die Registrierung im Bootstrap. HTTPS oder localhost
und ein erster vollständiger Online-Aufruf sind nötig. Ohne diesen Buildschritt
ist nur der Daten-Cache vorhanden. `flutter run` installiert keinen Offline-Worker.

Der Worker speichert nur mitgelieferte App-Dateien einschließlich CanvasKit,
Schriften und lokalen Bildern. API-, Supabase- und Auth-Antworten werden nicht im
Service-Worker-Cache gespeichert. Externe Bildserver und Online-Suche bleiben
netzabhängig. Ein unvollständiger Download wird verworfen; neue Versionen werden
erst aktiv, wenn bisherige Tabs geschlossen wurden. Nach einem Update die App-Tabs
schließen und erneut öffnen. Beim Hosting vorhandene Cache-Regeln beachten:
`offline_worker.js`, `index.html` und `flutter_bootstrap.js` müssen aktualisierbar sein.

Flutter empfiehlt inzwischen eine eigene Offline-Lösung statt seines bisherigen
generierten Workers: [Flutter Web FAQ](https://docs.flutter.dev/platform-integration/web/faq),
[Bootstrap-Konfiguration](https://docs.flutter.dev/platform-integration/web/initialization).

## Prüfung

`test/offline_storage_test.dart` prüft Neustarts, Schreib- und Lesefehler,
Katalogkopien, Mengenkonflikte und getrennte Speicherbereiche.
`test/offline_page_test.dart` prüft Gast-Neustarts sowie private und gemeinsame
Offline-Häkchen mit anschließend verändertem Cloudplan.
`tool/test_offline_web.mjs` prüft den gebauten Demo-Webclient einschließlich
Service-Worker-Installation und Offline-Neustart in Chrome.
Echte Android-/iOS-Gerätetests stehen weiterhin aus.
