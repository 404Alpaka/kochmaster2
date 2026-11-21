# Bon-Import und Barcode-Erfassung

Die Web-App unterstützt digitale PDF-Bons, Bonbilder (JPG/PNG/WebP), Textdateien und eingefügten Bontext. „Kassenbon scannen“ öffnet die Bildaufnahme beziehungsweise Bildauswahl des Browsers. „Bon importieren“ steht in der leeren Vorratsansicht und im Plus-Menü bereit.

PDF.js liest digitale PDFs im Browser. Bildbons und gescannte PDF-Seiten werden lokal mit Tesseract.js erkannt. Das Dokument wird nicht hochgeladen oder gespeichert. Für die Fotoerkennung lädt der Browser einmalig OCR-Programmdateien und deutsche/englische Sprachdaten von jsDelivr/Project Naptha; dafür ist eine Internetverbindung nötig. Maximal 15 MB und 15 PDF-Seiten sind erlaubt.

Die Vorschau übernimmt nur ausgewählte Positionen nach ausdrücklicher Bestätigung. Mengen, Namen, Lagerort und Haltbarkeit sind editierbar. Stückangaben auf Bons zählen gekaufte Packungen, nicht deren unbekannten Inhalt. Ohne Mengenzeile bleibt „1 Packung“ als zu prüfende Angabe. Haltbarkeitsdaten werden nicht erfunden. Bekannte Haushaltsartikel und unspezifische Artikelbezeichnungen sind zunächst abgewählt. Diese Heuristik ersetzt die Prüfung nicht.

Der Parser ist anhand eines mehrseitigen REWE-eBons getestet. Andere Händlerlayouts und unscharfe Bilder können manuelle Korrekturen benötigen. Erstattungen, Rabatte und Pfand sind keine Vorratspositionen. Zahlungs- und Bonusdaten nach der Summenzeile werden ignoriert. Ein gespeicherter Fingerabdruck verhindert den erneuten Import derselben Datei beziehungsweise desselben eingefügten Textes. Neu erzeugte oder veränderte Dateien können einen anderen Fingerabdruck haben.

Nach der Übernahme gelten die vorhandenen Speicherregeln: ohne Konto lokal, angemeldet im Kundenkonto und bei aktivem Haushalt im gemeinsamen Vorrat. Bonfoto und kompletter Bontext werden nicht gespeichert. Konto-Synchronisierungsfehler werden durch die vorhandene Kontoverwaltung angezeigt. Der lokale Duplikatindex gehört zum jeweiligen Kundenkonto; gemeinsame Vorratspositionen enthalten zusätzlich die ursprünglichen Importkennungen.

Die Barcode-Erfassung unterstützt Live-Kamera, Barcode-Foto und manuelle EAN-Eingabe mit Prüfziffernprüfung. Live-Kamera benötigt Browserberechtigung und HTTPS oder localhost. ZXing erkennt den Barcode lokal, anschließend wird nur die Barcodenummer bei Open Food Facts abgefragt. Name und Packungsgröße werden vor dem Speichern im editierbaren Produktformular angezeigt. Unbekannte Produkte können manuell ergänzt werden. Quelle: [Open Food Facts](https://world.openfoodfacts.org/), Daten unter ODbL. Die Umsetzung ist für die Flutter-Web-App vorgesehen; native Plattformen zeigen derzeit einen Hinweis auf die Web-App.

## Entwicklung und Tests

- `flutter test test/receipt_parser_test.dart test/receipt_import_test.dart test/pantry_layout_test.dart`
- `node tool/test_receipt_tools.mjs /pfad/zum/bon.pdf` prüft die PDF-Auswertung in einem isolierten Chrome. Playwright und Chrome müssen verfügbar sein. Mit weiteren Bildpfaden werden Barcode und OCR getestet. `PLAYWRIGHT_MODULE` kann auf ein vorhandenes Playwright-Modul zeigen.
- `REWE_TEST_TEXT` kann auf eine lokal extrahierte Textdatei für den optionalen Test des REWE-Bons gesetzt werden. Echte Kundenbelege gehören nicht in Repository-Fixtures.
- Nach `flutter build web --dart-define=USE_DEMO=true --no-wasm-dry-run` prüft `node tool/test_receipt_app.mjs /pfad/zum/bon.pdf` die gesamte UI bis zur lokalen Speicherung und dem erneuten Laden.

Bibliotheken und Lizenzen liegen unter `web/vendor/receipts/`. Bilder für Erkennungstests lassen sich mit `tool/make_receipt_test_images.py` erzeugen (Pillow, unter Windows).
