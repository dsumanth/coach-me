import Foundation
import PDFKit
let path = "output/pdf/coachme_app_summary.pdf"
if let doc = PDFDocument(url: URL(fileURLWithPath: path)) {
    print(doc.pageCount)
} else {
    print("open-failed")
}
