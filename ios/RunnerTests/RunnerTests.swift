import Flutter
import PDFKit
import Testing
import UIKit
@testable import Runner

struct RunnerTests {
  @Test func receiptColumnsStayOnTheSameLine() {
    let fragments = [
      ReceiptNativeReader.Fragment(text: "JOGHURT", box: CGRect(x: 0.1, y: 0.8, width: 0.3, height: 0.03)),
      ReceiptNativeReader.Fragment(text: "1,29 B", box: CGRect(x: 0.8, y: 0.801, width: 0.15, height: 0.03)),
      ReceiptNativeReader.Fragment(text: "2 Stk x 1,09", box: CGRect(x: 0.2, y: 0.74, width: 0.5, height: 0.03)),
      ReceiptNativeReader.Fragment(text: "SUMME 2,18", box: CGRect(x: 0.1, y: 0.68, width: 0.8, height: 0.03)),
    ]
    #expect(ReceiptNativeReader.orderedLines(fragments) == "JOGHURT 1,29 B\n2 Stk x 1,09\nSUMME 2,18")
  }

  @Test func identicalFilesHaveTheSameFingerprint() {
    let data = Data("receipt".utf8)
    #expect(ReceiptNativeReader.fingerprint(data).count == 64)
    #expect(ReceiptNativeReader.fingerprint(data) == ReceiptNativeReader.fingerprint(data))
    #expect(ReceiptNativeReader.fingerprint(data) != ReceiptNativeReader.fingerprint(Data("other".utf8)))
  }

  @Test func digitalPDFKeepsArticleNamesPricesAndQuantityRows() throws {
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 600))
    let data = renderer.pdfData { context in
      context.beginPage()
      let style: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)]
      ("REWE\nMILCH              2,18 B\n   2 Stk x 1,09\nJOGHURT            1,29 B\nSUMME EUR          3,47" as NSString).draw(in: CGRect(x: 20, y: 20, width: 360, height: 500), withAttributes: style)
    }
    let text = try ReceiptNativeReader.pdfText(data)
    #expect(text.contains("MILCH"))
    #expect(text.contains("2,18 B"))
    #expect(text.contains("2 Stk x"))
    #expect(text.contains("JOGHURT"))
  }
}
