# Konten und private Wochenpläne

Die Web-App bietet E-Mail/Passwort-Registrierung, Bestätigungshinweis, Login und
Logout. Die Supabase-E-Mail-Bestätigung bleibt aktiv. Nach Bestätigung kann man
sich in der App anmelden. Passwörter werden nur an Supabase Auth übermittelt,
nicht in unseren Tabellen oder im Browserspeicher abgelegt.

## Registrierung und Kundennummer

Die Registrierung verlangt Vorname, Nachname, E-Mail-Adresse, Passwort und
Passwortbestätigung. Namen werden außen von Leerzeichen bereinigt, müssen
vorhanden sein und dürfen höchstens 100 Zeichen enthalten. Internationale Namen,
Bindestriche und Apostrophe sind erlaubt. Passwörter benötigen mindestens acht
Zeichen und müssen übereinstimmen. Die Anmeldung bleibt bei E-Mail und Passwort.

Die App übergibt `first_name` und `last_name` als Supabase-Registrierungsmetadaten.
Migration `202611180002_customer_profiles.sql` ergänzt `customer_profiles` und einen
Trigger auf `auth.users`. Dieser prüft beide Namen und erzeugt beim Anlegen eines
Kontos automatisch eine eindeutige numerische `customer_number` ab 100000.
Konto und Profil entstehen in derselben Transaktion, bereits vor E-Mail-Bestätigung.
Die Nummer wird nicht von der App vergeben und nicht aus Nutzermetadaten übernommen.
Nummernlücken bei fehlgeschlagenen Transaktionen sind möglich.

Bestehende Konten bekommen bei der Migration ebenfalls eine Kundennummer.
Bereits vorhandene gültige Namen werden übernommen; fehlende Namen bleiben NULL.
Die E-Mail-Adresse bleibt in Supabase Auth. App-Nutzer können nur ihr eigenes
Kundenprofil lesen und weder die Kundennummer noch andere Profile bearbeiten.
Eine spätere Änderung von Auth-Metadaten verändert die Kundennummer nicht.
Die Nummer wird derzeit im Hintergrund gespeichert und nicht im Formular angezeigt.

Die Migration wurde am 19.11.2026 vom Nutzer im Zielprojekt ausgeführt;
die Kundenprofil-Tabelle und ihre anonymen Zugriffssperren wurden live nachgewiesen.
Der Nutzer führte am selben Tag `supabase/tests/customer_profiles.sql` im echten
SQL Editor aus und meldete „PASS: Pflichtnamen, Kundennummern, Profilanlage und
private Zugriffsrechte“. Sämtliche Testdaten werden zurückgerollt.
Prüfung: `node tool/test_customer_profiles.mjs` und
`flutter test test/registration_test.dart test/account_test.dart`.
SQL-Testkonten werden zurückgerollt. Der SQL-Test prüft Profilanlage, Pflichtnamen,
eindeutige Nummern, unveränderte Nummer trotz Metadatenänderung und Zugriffsrechte.

Die Web-Sitzung wird mit dem Supabase-Sessionformat im lokalen Browserspeicher
abgelegt und beim Start wiederhergestellt. Abmelden entfernt die gespeicherte
Sitzung. Ist Browserspeicherung blockiert, ist keine dauerhafte Wiederherstellung
möglich; PKCE-Abläufe können mit einem Speicherhinweis abbrechen.

## Sitzungen auf Android und iOS

Android und iOS speichern das Supabase-Sessionformat einschließlich Refresh-Token
über `flutter_secure_storage`. iOS verwendet den Keychain mit
`first_unlock_this_device` ohne iCloud-Synchronisierung; Android verwendet den
verschlüsselten Speicher des Plugins. Passwörter werden dabei nicht gespeichert.
Die PKCE-Verifier liegen ebenfalls dauerhaft und nach Supabase-Projekt getrennt
im geschützten Speicher. Andere native Desktop-Plattformen verwenden bisher
einen flüchtigen Speicher. Der Web-Speicher bleibt `localStorage`.

Beim Start wird die Sitzung vor Anzeige des Kontos geladen. Abgelaufene Sitzungen
werden über Supabase mit dem Refresh-Token erneuert. Auth-Ereignisse aktualisieren
den gespeicherten Stand; Abmelden entfernt Sitzung und Recovery-Markierung.
Schreibzugriffe werden serialisiert, damit ein älterer Speichervorgang nicht nach
dem Abmelden wieder eine Sitzung hinterlegt. Speicherfehler erscheinen als Hinweis;
bei einem vorübergehenden Verbindungsfehler wird die gespeicherte Sitzung erhalten.

Android setzt mindestens API 24 voraus. Automatische Android-App-Backups sind
deaktiviert, damit verschlüsselte Sitzungsdaten nicht ohne zugehörige Schlüssel
wiederhergestellt werden. Die iOS-Keychain-Entitlements sind für Debug, Profile
und Release eingebunden. Native Rückleitungen für Bestätigungs- und Reset-Links
(Deep Links) sind damit noch nicht eingerichtet.

`flutter test test/mobile_session_test.dart` prüft mit simuliertem Secure Storage:
Neustart mit gültiger und abgelaufener Sitzung, Token-Erneuerung, Abmelden,
Reihenfolge verzögerter Schreibzugriffe, Projekttrennung der PKCE-Verifier und
Start bei Lesefehlern. Ein Gerätetest auf Android und iOS steht noch aus.
Auf einem Mac mit Xcode zusätzlich iOS-Signierung und Keychain prüfen.
Der Android-Debug-Build konnte hier mangels Android SDK nicht ausgeführt werden.

Manuell: anmelden, App vollständig beenden, erneut öffnen, angemeldeten Zustand
prüfen; anschließend abmelden, beenden und nach Neustart den abgemeldeten Zustand
prüfen. Dasselbe mit abgelaufenem Access-Token und gültigem Refresh-Token testen.

Die lokale Windows-Umgebung meldete bei `flutter pub add` fehlende
Symlink-Unterstützung. Falls `flutter pub get` deshalb abbricht, den Windows-
Entwicklermodus aktivieren und den Befehl erneut ausführen. Dies wurde nicht
automatisch an den Systemeinstellungen geändert.

Plugin-Dokumentation: [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage).

## Private Wochenpläne

`user_week_plans` enthält genau einen Datensatz je Nutzer und Montag einer
Kalenderwoche. Darin liegen Tagespositionen mit Rezept-ID und Portionen sowie
abgehakte Zutaten-IDs und Einheiten. Beim Wechsel der Woche wird der zugehörige
Plan geladen. Neue Gerichte und Änderungen werden erst nach bestätigter
Speicherung angezeigt. Bei Ladefehlern bleiben Änderungen gesperrt, um bestehende
Pläne nicht versehentlich zu überschreiben. Änderungen an Gerichten behalten
Einkaufshäkchen nur bei unverändertem Zutatenbedarf; geänderte Mengen müssen
erneut abgehakt werden.

RLS beschränkt das Lesen auf `auth.uid() = user_id`; anonyme Nutzer haben keinen
Zugriff. Die Migration `202611180001_private_week_plan_revisions.sql` schützt
private Wochenpläne durch einen Versionsvergleich. Haushaltsanbindung und
kontoweite persönliche Daten sind in [households.md](households.md) beschrieben.

Private Pläne werden zuerst mit ihrer Revision geladen und über
`save_user_week_plan` atomar gespeichert. Jeder erfolgreiche Schreibzugriff erhöht
die Revision, auch bei Einkaufshäkchen. Hat ein anderer Tab oder ein anderes Gerät
inzwischen gespeichert, wird die Änderung mit `40001` abgelehnt. Die App zeigt
einen Konflikthinweis und sperrt weitere Speicherungen bis zum erfolgreichen
Neuladen. Danach muss die gewünschte Änderung erneut ausgeführt werden. Neuladen
verwirft auch den bisherigen Planungsvorschlag. Es gibt kein automatisches
Zusammenführen oder Erzwingen eines veralteten Stands.

Das Wochenplan-Repository bleibt bei Token-Erneuerungen und Änderungen der
Auth-Metadaten für dasselbe Konto erhalten. Dadurch gehen geladene Revisionen
nicht bei einem Neuaufbau der Oberfläche verloren. Ein anderer Client oder ein
anderes Konto erhält weiterhin einen eigenen Repository-Zustand.

Bei einer verlorenen Speicherantwort (Timeout) ist unbekannt, ob die Datenbank
bereits gespeichert hat. Die App meldet deshalb „Speicherstand unklar“ und sperrt
weitere Speicherungen bis zum Neuladen. Sie behauptet weder Erfolg noch ein
Zurückrollen der Datenbank und überschreibt den möglicherweise gespeicherten Stand
nicht durch einen automatischen Wiederholungsversuch.

`flutter test test/week_plan_lifecycle_test.dart test/weekly_plan_conflict_test.dart test/planning_page_test.dart`
prüft Token-Erneuerung, zwei unabhängige Testclients, Einkaufsstatus,
Versionskonflikte und verlorene Speicherantworten. Der SQL-Schreibtest wurde am
19.11.2026 vom Nutzer im Zielprojekt mit PASS abgeschlossen; siehe [database.md](database.md).

Direkte INSERT-/UPDATE-Rechte für App-Nutzer entfallen mit der Migration.
Die Speicherfunktion prüft die Konto-ID. Bestehende Pläne starten mit Revision 0.
Die Migration muss vor Verwendung der aktualisierten App angewendet werden;
ältere Clients können anschließend keine direkten Upserts mehr durchführen.

Prüfung: `flutter test test/weekly_plan_conflict_test.dart test/planning_page_test.dart`
und `node tool/test_private_week_plans.mjs` (benötigt die PGlite-Installation
aus [households.md](households.md)). Die SQL-Prüfung liegt in
`supabase/tests/private_week_plan_revisions.sql` und rollt alle Testdaten zurück.

## Nachweise

- SQL-Migration `202611160002_user_week_plans.sql` im Entwicklungsprojekt angewendet.
- RLS mit zwei nur innerhalb einer zurückgerollten Transaktion angelegten Nutzern
  geprüft: eigener Zugriff erfolgreich, fremdes Lesen/Ändern/Einfügen und Wechsel
  des Besitzers gesperrt, anonymer Zugriff gesperrt. Keine Testkonten hinterlassen.
- Automatische Tests: Formularvalidierung, Kalenderwochen über Jahresgrenzen,
  Serialisierung von Plan und Einkaufsstatus, Auth-/Speicherablauf über Mock-HTTP.
- Echter Versand einer Bestätigungsmail und Anmeldung mit einem persönlichen
  Konto benötigen den Nutzer; dafür wurden keine Passwörter oder Mailadressen erfunden.

## Lokaler Start und E-Mail-Bestätigung

Registrierung, erneuter Bestätigungsmail-Versand und Passwort-Reset übergeben im
Web die aktuelle App-Adresse ohne Query oder Fragment als Rückleitungsadresse.
Unter Supabase → Authentication → URL Configuration muss diese Adresse in den
Redirect URLs freigegeben sein. Die Site URL bleibt der serverseitige Rückfall.
Der lokale Port kann je Start wechseln; am 19.11.2026 wurde
`http://localhost:62926/` verwendet und vom Nutzer als Redirect URL eingetragen.
Für eine feste Testadresse beispielsweise `flutter run -d chrome --web-port=8766`
verwenden und die tatsächlich geöffnete Adresse konfigurieren. `localhost` und
`127.0.0.1` besitzen getrennten Browserspeicher und dürfen im PKCE-Ablauf nicht
vertauscht werden. Bei Veröffentlichung die echte HTTPS-Domain eintragen.

Der PKCE-Speicher wird projektbezogen bereitgestellt. Ein Bestätigungscode wird
beim Start gegen eine Sitzung getauscht und anschließend aus der URL entfernt.
Ohne passenden Browser-Speicher kann man sich nach Bestätigung manuell anmelden.
Passwort-Zurücksetzen ist wie unten beschrieben implementiert.

Nach einer Registrierung ohne Sitzung oder bei `email_not_confirmed` bietet die
Anmeldeseite „Bestätigungsmail erneut senden“. Die Anforderung verwendet die
aktuelle E-Mail-Adresse und einen neuen PKCE-Verifier; der neueste Link muss im
selben Browser geöffnet werden. Versandlimits werden als Hinweis angezeigt.
Passwörter werden beim Wechsel zur Anmeldung aus den Formularfeldern entfernt.

## Passwort vergessen

Auf der Anmeldeseite führt „Passwort vergessen?“ zum E-Mail-Formular.
Der Link wird mit Supabase `resetPasswordForEmail` angefordert. Die Rückleitung
verwendet im Web die aktuelle App-Adresse ohne Query und Fragment. Diese Adresse
muss in Supabase unter Authentication → URL Configuration als Redirect URL
zugelassen sein. Den Link im selben Browser öffnen, in dem er angefordert wurde,
damit der PKCE-Verifier verfügbar ist.

`AccountScope` erkennt das Ereignis `passwordRecovery` nach dem Code-Austausch
und zeigt das Formular für das neue Passwort. Erst nach erfolgreichem
`updateUser` wird die App wieder geöffnet. Passwörter müssen mindestens acht
Zeichen haben und zweimal übereinstimmend eingegeben werden. Abgelaufene oder
nicht einlösbare Links führen zu einem Hinweis, einen neuen Link anzufordern.

Der automatisierte Recovery-Test besteht seit 19.11.2026. Der vorherige Hänger
entstand durch simulierte Testzeit bei asynchroner PKCE-/Speicherarbeit; diese
Prüfung läuft jetzt vollständig in realer asynchroner Testausführung. Geprüft
werden Reset-Anforderung, Code-Austausch, Passwortbestätigung, Server-Ablehnung
eines Passworts mit erhaltenen Eingaben, erneutes Speichern und der Wechsel
zur App erst nach Erfolg. Ohne gültige Sitzung wird kein Passwort gesendet.

`auth_callback_uri_test.dart` prüft saubere Rückleitungsadressen ohne angehängtes
`?#`, das Entfernen verbrauchter Codes und das Erkennen abgelaufener Links in
Query und Fragment. Die App zeigt dafür einen verständlichen Hinweis und
entfernt die Auth-Fehlerparameter aus der URL, ohne Serverbeschreibungen oder
Tokens als Meldung auszugeben.

Am 19.11.2026 wurden die öffentlichen Auth-Einstellungen live geprüft:
E-Mail-Anmeldung aktiv, Registrierung erlaubt, automatische Bestätigung deaktiviert.
Den echten Postfachtest unter `http://localhost:62926/` führte der Nutzer am
19.11.2026 durch und bestätigte „Alle Schritte funktionieren“: Registrierung mit
einer bisher unbenutzten erreichbaren E-Mail-Adresse, Bestätigung im selben
Browser, Anmeldung, Abmeldung, Reset-Mail, neues Passwort speichern sowie erneute
Anmeldung mit dem neuen Passwort. Der Mailversand-Nachweis beruht auf dieser
Nutzerrückmeldung; Mock-HTTP-Tests allein belegen keinen Mailversand.

Abschließende technische Prüfung am 19.11.2026: 16 Tests aus
`registration_test.dart`, `password_reset_test.dart`, `auth_callback_uri_test.dart`,
`mobile_session_test.dart`, `account_test.dart` und `week_plan_lifecycle_test.dart`
bestanden. Die gezielte Analyse meldete keine Probleme; der Web-Build war erfolgreich.
Die Freigabe von `http://localhost:62926/` in den Supabase Redirect URLs wurde vom
Nutzer bestätigt. Für den Mailtest die laufende Flutter-App mit großem `R` neu
starten, damit die korrigierten Rückleitungen verwendet werden.

Referenzen:
- https://supabase.com/docs/reference/dart/auth-signup
- https://supabase.com/docs/reference/dart/auth-signinwithpassword
- https://supabase.com/docs/guides/database/postgres/row-level-security


## Wochenplan und Einkauf verwenden

Gerichte im Rezeptbereich einem Tag zuordnen. Im Wochenplan lassen sich Portionen
pro Gericht ändern und Gerichte entfernen. Jede Änderung wird automatisch gespeichert;
zusätzlich gibt es den Knopf Wochenplan speichern und einen sichtbaren Speicherstatus.
Die Einkaufsliste summiert die Wochenmengen und speichert jedes Häkchen sofort.
Der Aktualisieren-Knopf lädt den gespeicherten Wochenstand erneut.

UI-Tests prüfen den kompletten Ablauf mit einem serialisierenden Test-Repository:
Planen, Abhaken, Widget-Neuaufbau, Wochenwechsel, Portionsänderung und fehlgeschlagene Speicherung.
