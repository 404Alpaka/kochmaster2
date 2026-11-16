# Konten und private Wochenpläne

Die Web-App bietet E-Mail/Passwort-Registrierung, Bestätigungshinweis, Login und
Logout. Die Supabase-E-Mail-Bestätigung bleibt aktiv. Nach Bestätigung kann man
sich in der App anmelden. Passwörter werden nur an Supabase Auth übermittelt,
nicht in unseren Tabellen oder im Browserspeicher abgelegt.

Die Web-Sitzung wird mit dem Supabase-Sessionformat im lokalen Browserspeicher
abgelegt und beim Start wiederhergestellt. Abmelden entfernt die gespeicherte
Sitzung. Ist Browserspeicherung blockiert, funktioniert das Login für die laufende
Sitzung. Native Plattformen behalten Sitzungen vorerst nur im Arbeitsspeicher.

`user_week_plans` enthält genau einen Datensatz je Nutzer und Montag einer
Kalenderwoche. Darin liegen Tagespositionen mit Rezept-ID und Portionen sowie
abgehakte Zutaten-IDs und Einheiten. Beim Wechsel der Woche wird der zugehörige
Plan geladen. Neue Gerichte und Änderungen werden erst nach bestätigter
Speicherung angezeigt. Bei Ladefehlern bleiben Änderungen gesperrt, um bestehende
Pläne nicht versehentlich zu überschreiben. Änderungen an Gerichten setzen den
Einkaufsstatus der Woche zurück, weil sich die benötigten Mengen ändern.

RLS erlaubt SELECT, INSERT und UPDATE ausschließlich mit `auth.uid() = user_id`;
anonyme Nutzer haben keinen Zugriff. Gleichzeitiges Bearbeiten in mehreren Tabs
verwendet vorläufig den zuletzt gespeicherten Wochenstand. Haushaltsfreigaben und
Konfliktauflösung sind noch nicht enthalten.

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

Die Bestätigungsmail verwendet die Site URL unter Supabase → Authentication →
URL Configuration. Sie muss auf die tatsächliche Website zeigen. Für die lokale
Vorschau wird `http://127.0.0.1:8766/` verwendet. Bei Veröffentlichung die echte
HTTPS-Domain eintragen. Danach ist eine manuelle Anmeldung in der App möglich;
Der PKCE-Speicher wird projektbezogen bereitgestellt. Ein Bestätigungscode wird beim Start gegen eine Sitzung getauscht und anschließend aus der URL entfernt. Ohne passenden Browser-Speicher kann man sich nach Bestätigung manuell anmelden. Passwort-zurücksetzen folgt separat.

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

Der tatsächliche E-Mail-Versand und die Supabase-Redirect-Konfiguration müssen
mit der verwendeten App-Adresse geprüft werden. Der automatisierte Recovery-Test
ist angelegt, aber noch nicht abschließend bestätigt.

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
