import XCTest
@testable import MarketsPresentation

final class CandidateDateExtractorTests: XCTestCase {
    private func date(month: Int, day: Int, year: Int = 2026) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        return Calendar.current.date(from: comps)!
    }

    func test_extractsMonthAndDay_fromSimpleLabel() {
        let extracted = CandidateDateExtractor.extractedDate(from: "July 9", referenceDate: date(month: 1, day: 1))
        XCTAssertEqual(extracted.map { Calendar.current.component(.month, from: $0) }, 7)
        XCTAssertEqual(extracted.map { Calendar.current.component(.day, from: $0) }, 9)
    }

    func test_extractsMonthAndDay_fromSentenceLabel() {
        let extracted = CandidateDateExtractor.extractedDate(from: "June 24 or earlier", referenceDate: date(month: 1, day: 1))
        XCTAssertEqual(extracted.map { Calendar.current.component(.month, from: $0) }, 6)
        XCTAssertEqual(extracted.map { Calendar.current.component(.day, from: $0) }, 24)
    }

    func test_extractsMonthAndDay_fromFullQuestion() {
        let extracted = CandidateDateExtractor.extractedDate(
            from: "Will GPT-5.6 be released on July 7, 2026?", referenceDate: date(month: 1, day: 1)
        )
        XCTAssertEqual(extracted.map { Calendar.current.component(.month, from: $0) }, 7)
        XCTAssertEqual(extracted.map { Calendar.current.component(.day, from: $0) }, 7)
    }

    func test_noMonthMention_returnsNil() {
        XCTAssertNil(CandidateDateExtractor.extractedDate(from: "Never"))
    }

    func test_monthWithNoFollowingNumber_returnsNil() {
        XCTAssertNil(CandidateDateExtractor.extractedDate(from: "Not released before August"))
    }

    func test_usesReferenceDateYear() {
        let extracted = CandidateDateExtractor.extractedDate(from: "March 3", referenceDate: date(month: 1, day: 1, year: 2030))
        XCTAssertEqual(extracted.map { Calendar.current.component(.year, from: $0) }, 2030)
    }

    func test_ordersChronologically_acrossVariousLabels() {
        let labels = ["July 9", "June 25", "July 7", "June 24 or earlier"]
        let ref = date(month: 1, day: 1)
        let dates = labels.compactMap { CandidateDateExtractor.extractedDate(from: $0, referenceDate: ref) }
        XCTAssertEqual(dates.count, 4)
        let sortedLabels = labels.sorted {
            CandidateDateExtractor.extractedDate(from: $0, referenceDate: ref)! <
            CandidateDateExtractor.extractedDate(from: $1, referenceDate: ref)!
        }
        XCTAssertEqual(sortedLabels, ["June 24 or earlier", "June 25", "July 7", "July 9"])
    }
}
