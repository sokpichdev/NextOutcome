//
//  EsportsSeriesScoreTests.swift
//  NextOutcome
//

import XCTest
@testable import MarketsDomain

final class EsportsSeriesScoreTests: XCTestCase {

    // MARK: - EsportsSeriesScore

    func test_fullScore_splitsIntoCurrentMapSeriesAndFormat() {
        // The shape every live esports event sends: map 3 has just started (0-0), the
        // series is level at one map each, and it's a best of three.
        let score = EsportsSeriesScore.parse("000-000|1-1|Bo3")
        XCTAssertEqual(score?.mapScore, EsportsScorePair(home: 0, away: 0))
        XCTAssertEqual(score?.seriesScore, EsportsScorePair(home: 1, away: 1))
        XCTAssertEqual(score?.format, "Bo3")
        XCTAssertEqual(score?.bestOf, 3)
    }

    func test_firstSegmentIsTheCurrentMapScore_notAHistory() {
        // Captured from the live feed: a LoL game 1 in progress at 5-5, series still 0-0.
        // This is the evidence that segment 1 tracks the map being played right now.
        let score = EsportsSeriesScore.parse("5-5|0-0|Bo3")
        XCTAssertEqual(score?.mapScore, EsportsScorePair(home: 5, away: 5))
        XCTAssertEqual(score?.seriesScore, EsportsScorePair(home: 0, away: 0))
    }

    func test_bareSeriesScore_hasNoMapScore() {
        let score = EsportsSeriesScore.parse("2-1")
        XCTAssertNil(score?.mapScore)
        XCTAssertEqual(score?.seriesScore, EsportsScorePair(home: 2, away: 1))
        XCTAssertNil(score?.format)
        XCTAssertNil(score?.bestOf)
    }

    func test_bestOf_readsBo1AndBo5() {
        XCTAssertEqual(EsportsSeriesScore.parse("0-0|0-0|Bo1")?.bestOf, 1)
        XCTAssertEqual(EsportsSeriesScore.parse("000-000|2-1|Bo5")?.bestOf, 5)
        XCTAssertEqual(EsportsSeriesScore.parse("000-000|2-1|bo5")?.bestOf, 5)
    }

    func test_unparseableInputs() {
        XCTAssertNil(EsportsSeriesScore.parse(nil))
        XCTAssertNil(EsportsSeriesScore.parse(""))
        XCTAssertNil(EsportsSeriesScore.parse("Bo3"))
        XCTAssertNil(EsportsSeriesScore.parse("live"))
    }

    func test_partiallyMalformedScore_keepsWhatItCanRead() {
        // A missing series segment shouldn't cost us the format or the map score.
        let score = EsportsSeriesScore.parse("3-2||Bo3")
        XCTAssertEqual(score?.mapScore, EsportsScorePair(home: 3, away: 2))
        XCTAssertNil(score?.seriesScore)
        XCTAssertEqual(score?.bestOf, 3)
    }

    func test_unrecognisedFormatMarker_yieldsNoMapCount() {
        let score = EsportsSeriesScore.parse("0-0|1-0|First to 4")
        XCTAssertEqual(score?.format, "First to 4")
        XCTAssertNil(score?.bestOf)
    }

    // MARK: - EsportsMatchProgress

    func test_period_readsCurrentAndTotalMaps() {
        let progress = EsportsMatchProgress.parse("3/3")
        XCTAssertEqual(progress?.currentMap, 3)
        XCTAssertEqual(progress?.totalMaps, 3)
    }

    func test_period_rejectsOtherSportsLabels() {
        // Soccer and basketball send period labels through the same field.
        XCTAssertNil(EsportsMatchProgress.parse("2H"))
        XCTAssertNil(EsportsMatchProgress.parse("FT"))
        XCTAssertNil(EsportsMatchProgress.parse("HT"))
        XCTAssertNil(EsportsMatchProgress.parse(nil))
        XCTAssertNil(EsportsMatchProgress.parse("3/0"))
    }
}
