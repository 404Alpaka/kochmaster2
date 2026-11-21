import AVFoundation
import CryptoKit
import Flutter
import ImageIO
import PDFKit
import PhotosUI
import UIKit
import UniformTypeIdentifiers
import Vision
import VisionKit

/// Receipts are processed on-device. Only a barcode lookup uses the network.
final class ReceiptNativeReader: NSObject, UIDocumentPickerDelegate,
  UIImagePickerControllerDelegate, UINavigationControllerDelegate, VNDocumentCameraViewControllerDelegate, PHPickerViewControllerDelegate {
  private enum Operation { case receipt, barcode }
  private let channel: FlutterMethodChannel
  private let queue = DispatchQueue(label: "kochmaster.receipt-recognition", qos: .userInitiated)
  private var pending: FlutterResult?
  private var operation: Operation = .receipt
  static let maxBytes = 15 * 1024 * 1024

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "kochmaster/receipt_reader", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: "Die Erkennung ist momentan nicht verfügbar.", details: nil))
        return
      }
      self.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    if call.method == "lookupProductBarcode" {
      lookupBarcode(args["barcode"] as? String ?? "", result: result)
      return
    }
    guard call.method == "readReceiptFile" || call.method == "scanProductBarcode" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard pending == nil else {
      result(FlutterError(code: "busy", message: "Eine Erkennung läuft bereits. Bitte kurz warten.", details: nil))
      return
    }
    pending = result
    operation = call.method == "readReceiptFile" ? .receipt : .barcode
    let camera = args["camera"] as? Bool ?? false
    if camera { openCamera() } else { chooseImportSource() }
  }

  private var presenter: UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }
    guard var controller = scenes.flatMap({ $0.windows }).first(where: { $0.isKeyWindow })?.rootViewController else { return nil }
    while let next = controller.presentedViewController { controller = next }
    return controller
  }

  private func finish(_ value: Any?) {
    guard Thread.isMainThread else {
      DispatchQueue.main.async { self.finish(value) }
      return
    }
    let callback = pending
    pending = nil
    callback?(value)
  }

  private func fail(_ message: String, code: String = "recognition_failed") {
    finish(FlutterError(code: code, message: message, details: nil))
  }

  private func chooseImportSource() {
    guard let controller = presenter else { fail("Die Dateiauswahl konnte nicht geöffnet werden."); return }
    let sheet = UIAlertController(title: operation == .receipt ? "Bon importieren" : "Barcode-Bild auswählen", message: nil, preferredStyle: .actionSheet)
    sheet.addAction(UIAlertAction(title: operation == .receipt ? "Datei auswählen (PDF oder Bild)" : "Bilddatei auswählen", style: .default) { [weak sheet] _ in
      sheet?.dismiss(animated: true) { self.openFiles() }
    })
    sheet.addAction(UIAlertAction(title: "Foto aus Mediathek", style: .default) { [weak sheet] _ in
      sheet?.dismiss(animated: true) { self.openPhotoLibrary() }
    })
    sheet.addAction(UIAlertAction(title: "Abbrechen", style: .cancel) { _ in self.finish(nil) })
    if let popover = sheet.popoverPresentationController {
      popover.sourceView = controller.view
      popover.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.maxY - 1, width: 1, height: 1)
      popover.permittedArrowDirections = []
    }
    controller.present(sheet, animated: true)
  }

  private func openPhotoLibrary() {
    guard let controller = presenter else { fail("Die Fotomediathek konnte nicht geöffnet werden."); return }
    var configuration = PHPickerConfiguration()
    configuration.filter = .images
    configuration.selectionLimit = 1
    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    controller.present(picker, animated: true)
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    let currentOperation = operation
    picker.dismiss(animated: true) {
      guard let provider = results.first?.itemProvider else { self.finish(nil); return }
      guard provider.canLoadObject(ofClass: UIImage.self) else { self.fail("Dieses Fotoformat konnte nicht geöffnet werden."); return }
      provider.loadObject(ofClass: UIImage.self) { object, error in
        guard let image = object as? UIImage, error == nil else { self.fail("Das Foto konnte nicht geladen werden."); return }
        self.processImage(image, operation: currentOperation)
      }
    }
  }

  private func processImage(_ image: UIImage, operation: Operation) {
    queue.async {
      do {
        let data = try Self.normalizedData(image)
        if operation == .barcode { self.finish(try Self.recognizeBarcode(data)) }
        else { self.finish(["text": try Self.recognizeText(data), "name": "Bonfoto.jpg", "fingerprint": Self.fingerprint(data)]) }
      } catch { self.fail(error.localizedDescription) }
    }
  }

  private func openFiles() {
    guard let controller = presenter else { fail("Die Dateiauswahl konnte nicht geöffnet werden."); return }
    let types: [UTType] = operation == .receipt ? [.pdf, .image, .plainText, .commaSeparatedText] : [.image]
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
    picker.delegate = self
    picker.allowsMultipleSelection = false
    controller.present(picker, animated: true)
  }

  private func openCamera() {
    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
      fail("Keine Kamera verfügbar. Bitte einen Bon oder ein Barcode-Bild importieren.", code: "camera_unavailable")
      return
    }
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: presentCamera()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { allowed in
        DispatchQueue.main.async {
          if allowed { self.presentCamera() }
          else { self.fail("Kamerazugriff wurde nicht erlaubt. Du kannst weiterhin eine Datei importieren.", code: "camera_permission") }
        }
      }
    default:
      fail("Bitte den Kamerazugriff in den iPhone-Einstellungen für mise. erlauben oder eine Datei importieren.", code: "camera_permission")
    }
  }

  private func presentCamera() {
    guard let controller = presenter else { fail("Die Kamera konnte nicht geöffnet werden."); return }
    if operation == .receipt && VNDocumentCameraViewController.isSupported {
      let scanner = VNDocumentCameraViewController()
      scanner.delegate = self
      scanner.modalPresentationStyle = .fullScreen
      controller.present(scanner, animated: true)
    } else {
      let picker = UIImagePickerController()
      picker.sourceType = .camera
      picker.delegate = self
      picker.modalPresentationStyle = .fullScreen
      controller.present(picker, animated: true)
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finish(nil) }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let url = urls.first else { finish(nil); return }
    let currentOperation = operation
    controller.dismiss(animated: true) {
      self.queue.async {
        let access = url.startAccessingSecurityScopedResource()
        defer {
          if access { url.stopAccessingSecurityScopedResource() }
          Self.removeImportedCopy(url)
        }
        do {
          let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
          guard size <= Self.maxBytes else { throw ReceiptFailure("Die Datei darf höchstens 15 MB groß sein.") }
          let data = try Data(contentsOf: url, options: .mappedIfSafe)
          guard !data.isEmpty && data.count <= Self.maxBytes else { throw ReceiptFailure("Die Datei ist leer oder größer als 15 MB.") }
          if currentOperation == .barcode {
            self.finish(try Self.recognizeBarcode(data))
          } else {
            let text: String
            if data.starts(with: Data("%PDF-".utf8)) {
              text = try Self.pdfText(data)
            } else if ["txt", "csv"].contains(url.pathExtension.lowercased()) {
              guard let decoded = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { throw ReceiptFailure("Diese Textdatei konnte nicht gelesen werden.") }
              text = decoded
            } else {
              text = try Self.recognizeText(data)
            }
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ReceiptFailure("Kein lesbarer Bontext gefunden. Bitte eine deutlichere Aufnahme verwenden.") }
            self.finish(["text": text, "name": url.lastPathComponent, "fingerprint": Self.fingerprint(data)])
          }
        } catch { self.fail(error.localizedDescription) }
      }
    }
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true) { self.finish(nil) }
  }

  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
    guard let image = info[.originalImage] as? UIImage else { picker.dismiss(animated: true) { self.fail("Das Foto konnte nicht gelesen werden.") }; return }
    let currentOperation = operation
    picker.dismiss(animated: true) { self.processImage(image, operation: currentOperation) }
  }

  func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
    controller.dismiss(animated: true) { self.finish(nil) }
  }

  func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
    controller.dismiss(animated: true) { self.fail("Der Bon konnte nicht aufgenommen werden. Bitte erneut versuchen oder eine Datei importieren.") }
  }

  func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
    guard (1...15).contains(scan.pageCount) else {
      controller.dismiss(animated: true) { self.fail("Bitte höchstens 15 Bonseiten auf einmal scannen.") }
      return
    }
    // Obtain scanner images before dismissing the controller that owns them.
    let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
    controller.dismiss(animated: true) {
      self.queue.async {
        do {
          var hasher = SHA256()
          var size = 0
          var pages: [String] = []
          for image in images {
            let data = try Self.normalizedData(image)
            size += data.count
            guard size <= Self.maxBytes else { throw ReceiptFailure("Die Aufnahmen dürfen zusammen höchstens 15 MB groß sein.") }
            hasher.update(data: data)
            pages.append(try Self.recognizeText(data))
          }
          self.finish(["text": pages.joined(separator: "\n\n"), "name": "Gescannter Bon", "fingerprint": hasher.finalize().map { String(format: "%02x", $0) }.joined()])
        } catch { self.fail(error.localizedDescription) }
      }
    }
  }

  private static func removeImportedCopy(_ url: URL) {
    let path = url.resolvingSymlinksInPath().standardizedFileURL.path
    let home = URL(fileURLWithPath: NSHomeDirectory()).resolvingSymlinksInPath().standardizedFileURL.path
    // Only the file picker's copy inside our own sandbox may be removed.
    if path.hasPrefix(home + "/tmp/") || path.hasPrefix(home + "/Documents/Inbox/") {
      try? FileManager.default.removeItem(at: url)
    }
  }

  static func fingerprint(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

  static func normalizedData(_ image: UIImage) throws -> Data {
    let factor = min(1, 3000 / max(image.size.width, image.size.height))
    let size = CGSize(width: max(1, image.size.width * factor), height: max(1, image.size.height * factor))
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    let upright = UIGraphicsImageRenderer(size: size, format: format).image { context in
      UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size))
      image.draw(in: CGRect(origin: .zero, size: size))
    }
    guard let data = upright.jpegData(compressionQuality: 0.9) else { throw ReceiptFailure("Das Foto konnte nicht verarbeitet werden.") }
    return data
  }

  struct Fragment {
    let text: String
    let box: CGRect
  }

  /// Join name and price columns into a row before passing text to Dart.
  static func orderedLines(_ fragments: [Fragment]) -> String {
    var rows: [[Fragment]] = []
    for fragment in fragments.sorted(by: { $0.box.midY > $1.box.midY }) {
      if let index = rows.firstIndex(where: { row in
        guard let first = row.first else { return false }
        return abs(first.box.midY - fragment.box.midY) <= max(0.002, min(first.box.height, fragment.box.height) * 0.45)
      }) { rows[index].append(fragment) } else { rows.append([fragment]) }
    }
    return rows.map { $0.sorted(by: { $0.box.minX < $1.box.minX }).map { $0.text }.joined(separator: " ") }.joined(separator: "\n")
  }

  static func recognizeText(_ data: Data) throws -> String {
    guard let image = UIImage(data: data), let cgImage = image.cgImage else { throw ReceiptFailure("Dieses Bildformat konnte nicht geöffnet werden.") }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["de-DE", "en-US"]
    request.usesLanguageCorrection = true
    try VNImageRequestHandler(cgImage: cgImage, orientation: image.imageOrientation.visionOrientation, options: [:]).perform([request])
    let fragments = (request.results ?? []).compactMap { observation -> Fragment? in
      guard let text = observation.topCandidates(1).first?.string else { return nil }
      return Fragment(text: text, box: observation.boundingBox)
    }
    let text = orderedLines(fragments)
    guard !text.isEmpty else { throw ReceiptFailure("Kein lesbarer Text erkannt. Bitte den ganzen Bon scharf und gut beleuchtet aufnehmen.") }
    return text
  }

  static func recognizeBarcode(_ data: Data) throws -> String {
    guard let image = UIImage(data: data), let cgImage = image.cgImage else { throw ReceiptFailure("Das Barcode-Foto konnte nicht geöffnet werden.") }
    let request = VNDetectBarcodesRequest()
    request.symbologies = [.ean13, .ean8]
    try VNImageRequestHandler(cgImage: cgImage, orientation: image.imageOrientation.visionOrientation, options: [:]).perform([request])
    guard let code = request.results?.compactMap({ $0.payloadStringValue }).first else { throw ReceiptFailure("Kein Produktbarcode erkannt. Bitte ein schärferes Foto verwenden oder die Nummer eingeben.") }
    return code
  }

  static func pdfText(_ data: Data) throws -> String {
    guard let pdf = PDFDocument(data: data), !pdf.isLocked else { throw ReceiptFailure("Das PDF ist beschädigt oder passwortgeschützt.") }
    guard (1...15).contains(pdf.pageCount) else { throw ReceiptFailure("Bitte einen Bon mit höchstens 15 Seiten auswählen.") }
    var pages: [String] = []
    for index in 0..<pdf.pageCount {
      guard let page = pdf.page(at: index) else { throw ReceiptFailure("Eine PDF-Seite konnte nicht gelesen werden.") }
      let bounds = page.bounds(for: .mediaBox)
      guard bounds.width > 0 && bounds.height > 0 else { throw ReceiptFailure("Ungültige PDF-Seitengröße.") }
      let selections = page.selection(for: bounds)?.selectionsByLine() ?? []
      let fragments = selections.compactMap { selection -> Fragment? in
        guard let text = selection.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        let box = selection.bounds(for: page)
        return Fragment(text: text, box: CGRect(x: box.minX / bounds.width, y: box.minY / bounds.height, width: box.width / bounds.width, height: box.height / bounds.height))
      }
      let text = fragments.isEmpty ? (page.string ?? "") : orderedLines(fragments)
      if text.count >= 30 && text.range(of: "[0-9]+[.,][0-9]{2}", options: .regularExpression) != nil { pages.append(text) }
      else {
        let scale = min(3, 3000 / max(bounds.width, bounds.height))
        let image = page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
        pages.append(try recognizeText(normalizedData(image)))
      }
    }
    return pages.joined(separator: "\n\n")
  }

  private func lookupBarcode(_ code: String, result: @escaping FlutterResult) {
    guard code.range(of: "^(?:[0-9]{8}|[0-9]{12}|[0-9]{13}|[0-9]{14})$", options: .regularExpression) != nil else {
      result(FlutterError(code: "invalid_barcode", message: "Bitte eine gültige Produktnummer eingeben.", details: nil)); return
    }
    var components = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/\(code).json")!
    components.queryItems = [URLQueryItem(name: "fields", value: "product_name_de,product_name,quantity,categories_tags")]
    guard let url = components.url else { result(FlutterError(code: "invalid_barcode", message: "Ungültige Produktnummer.", details: nil)); return }
    var request = URLRequest(url: url, timeoutInterval: 20)
    request.setValue("Kochmaster/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
    URLSession.shared.dataTask(with: request) { data, response, error in
      let value: Any?
      if error != nil || (response as? HTTPURLResponse)?.statusCode != 200 {
        value = FlutterError(code: "product_lookup", message: "Die Produktdatenbank ist nicht erreichbar. Bitte später erneut versuchen oder manuell erfassen.", details: nil)
      } else if let data = data, let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
        value = (json["status"] as? Int) == 1 ? json["product"] as? [String: Any] : nil
      } else { value = FlutterError(code: "product_lookup", message: "Die Produktantwort konnte nicht gelesen werden.", details: nil) }
      DispatchQueue.main.async { result(value) }
    }.resume()
  }
}

private struct ReceiptFailure: LocalizedError {
  let message: String
  init(_ message: String) { self.message = message }
  var errorDescription: String? { message }
}

private extension UIImage.Orientation {
  var visionOrientation: CGImagePropertyOrientation {
    switch self {
    case .up: return .up
    case .down: return .down
    case .left: return .left
    case .right: return .right
    case .upMirrored: return .upMirrored
    case .downMirrored: return .downMirrored
    case .leftMirrored: return .leftMirrored
    case .rightMirrored: return .rightMirrored
    @unknown default: return .up
    }
  }
}
