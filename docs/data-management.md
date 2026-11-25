# Datenverwaltung

## Aktionen im Profil

- **Meine Daten exportieren:** erstellt eine JSON-Datei zum Speichern oder Teilen.
  Mit Konto werden das Kontoprofil, die persönlichen Einstellungen, sämtliche
  privaten Wochenpläne einschließlich Rezept-Snapshots und Einkaufsstatus sowie
  die eigenen Haushaltsmitgliedschaften exportiert. Gemeinsame Haushaltsinhalte,
  Passwörter, Sitzungen und Tokens sind nicht enthalten. Der Export liest einen
  konsistenten Datenbankstand ohne Begrenzung auf die geöffnete Woche. Als Gast
  umfasst die Datei die verfügbaren lokalen Einstellungen und Wochenpläne.
- **Lokale App-Daten entfernen:** entfernt die lokale Präferenzkopie des aktuellen
  Kontos/Gasts und sämtliche zugehörigen lokalen Kochfortschritte. Mit Konto wird
  dieses Gerät abgemeldet. Es erfolgt kein Zurücksetzen oder Speichern von
  Cloud-Dokumenten. Beim erneuten Anmelden wird der Cloudstand wieder geladen.
  Die Daten anderer auf dem Gerät verwendeter Konten bleiben erhalten.
- **Meine Cloud-Daten zurücksetzen:** erfordert die Eingabe von `ZURÜCKSETZEN`.
  Persönliche Einstellungen, Vorräte, Favoriten, eigene Rezepte, Historie und
  alle privaten Wochenpläne werden atomar geleert. Das Konto, Kontoprofil,
  Mitgliedschaften und gemeinsame Haushaltsinhalte bleiben erhalten. Die App
  wechselt danach in den privaten Planungsbereich. Revisionen werden erhöht;
  veraltete Speicherungen anderer Geräte dürfen die gelöschten Daten nicht
  wiederherstellen.
- **Konto endgültig löschen:** erfordert `LÖSCHEN` und eine erneute Anmeldung mit
  dem aktuellen Passwort. Die serverseitige Funktion akzeptiert keine Ziel-ID,
  sondern löscht ausschließlich das authentifizierte Konto samt privater Daten
  und Mitgliedschaften. Einpersonenhaushalte werden mit ihren Daten entfernt.
  Gemeinsame Haushalte bleiben erhalten. Die letzte Verwaltung eines Haushalts
  mit weiteren Mitgliedern muss zuerst eine andere Verwaltung ernennen.

Fehlgeschlagene Aktionen melden keinen Erfolg. Bei einem Verbindungsabbruch kann
der Server die Aktion bereits abgeschlossen haben; vor einem erneuten Versuch
den Cloudstand laden beziehungsweise den Anmeldestatus prüfen.

## Datenbank aktivieren

Nach den vorhandenen Migrationen
`supabase/migrations/202611250001_account_data_management.sql` anwenden. Der
Appstart führt sie nicht automatisch aus. Ohne diese Migration bleiben lokale
Bereinigung und Gastexport verfügbar; Cloud-Aktionen zeigen einen Einrichtungshinweis.

Die neue Migration ist lokal vorbereitet. Eine Anwendung im produktiven
Supabase-Projekt wurde im Rahmen dieser Änderung nicht durchgeführt.

Konten mit eigenen Supabase-Storage-Objekten werden bis zu deren Übertragung
oder Entfernung nicht gelöscht. Das betrifft insbesondere Rezept-Admins mit
hochgeladenen Bildern. Die App löscht dafür keine gemeinsamen Rezeptbilder und
keine Storage-Metadaten per SQL. Die Verwaltung muss die Dateien über Supabase
Storage bereinigen beziehungsweise deren Eigentum übertragen.

Der Export verwendet `share_plus`: im Web wird eine Datei geteilt beziehungsweise
als Download angeboten, auf Mobilgeräten der Systemdialog zum Teilen/Speichern.
Ein iOS-/Android-Neubuild ist wegen des neuen Plugins erforderlich.

## Prüfung

- `flutter test test/data_management_test.dart test/profile_layout_test.dart`
- `node tool/test_account_data_management.mjs`
- `supabase/tests/account_data_management.sql` kann zusätzlich im Supabase
  SQL Editor ausgeführt werden; die Testdaten werden zurückgerollt.

Grundlagen: [Supabase-Kontolöschung](https://supabase.com/docs/guides/auth/managing-user-data),
[Storage-Dateien löschen](https://supabase.com/docs/guides/storage/management/delete-objects),
[share_plus](https://pub.dev/packages/share_plus).
