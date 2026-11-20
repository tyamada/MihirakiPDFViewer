import Foundation
import CryptoKit

/// Real manga is integration/capture input, prepared and verified outside the checkout.
enum SamplePDFFixture {
    struct Record: Decodable { let bytes: Int; let sha256: String }
    static func url(named name: String) throws -> URL {
        guard let directory = ProcessInfo.processInfo.environment["MIHIRAKI_SAMPLE_PDF_DIR"], !directory.isEmpty else {
            throw NSError(domain: "SamplePDFFixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Run scripts/prepare_sample_fixtures.py and set MIHIRAKI_SAMPLE_PDF_DIR; missing input is a failure, not a skipped test."])
        }
        let root = URL(fileURLWithPath: directory, isDirectory: true)
        let file = name + ".pdf"
        guard URL(fileURLWithPath: file).lastPathComponent == file else { throw CocoaError(.fileReadInvalidFileName) }
        let records = try JSONDecoder().decode([String: Record].self, from: Data(contentsOf: root.appendingPathComponent("fixture-index.json")))
        guard let record = records[file] else { throw CocoaError(.fileReadNoSuchFile) }
        let url = root.appendingPathComponent(file)
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard data.count == record.bytes, hash == record.sha256, data.starts(with: Data("%PDF-".utf8)) else { throw CocoaError(.fileReadCorruptFile) }
        return url
    }
}
