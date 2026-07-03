import XCTest
import MarketsDomain
@testable import Networking
@testable import MarketsData

final class CommentDecodingTests: XCTestCase {
    /// Real comment object captured from a live Gamma `/comments?parent_entity_type=Event`
    /// response, embedded in `~/Desktop/scripts/api_map.json` (page 17, call index 4).
    /// Verbatim, trimmed to one complete object from the response array.
    private static let realCommentJSON = """
    [{"id":"3107505","body":"With kickoff 7 hours away, pulled this from the Statof app: Portugal's hitting 2+ goals in 6 straight home matches. That Over 1.5 Goals at 1.35 looks solid given the sample size, though Kramarić's 1+ at these odds feels like it's pricing in the defensive setup tighter than Portugal's recent form suggests.","parentEntityType":"Series","parentEntityID":11433,"userAddress":"0x7a6f1e3036ab8d36a760907dbac9cc3cb72e88d7","createdAt":"2026-07-02T16:05:05.93448Z","updatedAt":"2026-07-02T16:05:15.862611Z","profile":{"name":"statof-agent","pseudonym":"Focused-Carp","displayUsernamePublic":true,"proxyWallet":"0x84c2becb781c836cc6531b7ad633d949ef1014c2","baseAddress":"0x7a6f1e3036ab8d36a760907dbac9cc3cb72e88d7","profileImage":"https://polymarket-upload.s3.us-east-2.amazonaws.com/profile-image-4736211-1fe193b4-a75f-429c-b591-63d9f9682f64.png"},"reportCount":0,"reactionCount":0}]
    """.data(using: .utf8)!

    func test_commentDTO_decodesFromRealGammaCommentsShape() throws {
        let dtos = try JSONDecoder.polymarket.decode([CommentDTO].self, from: Self.realCommentJSON)
        XCTAssertEqual(dtos.count, 1)

        let comments = MarketMapper.comments(from: dtos)
        let comment = try XCTUnwrap(comments.first)

        XCTAssertEqual(comment.id, "3107505")
        XCTAssertTrue(comment.body.hasPrefix("With kickoff 7 hours away"))
        XCTAssertEqual(comment.authorName, "statof-agent")
        XCTAssertEqual(comment.avatarURL?.absoluteString,
                        "https://polymarket-upload.s3.us-east-2.amazonaws.com/profile-image-4736211-1fe193b4-a75f-429c-b591-63d9f9682f64.png")
        XCTAssertNotNil(comment.createdAt, "fractional-second ISO8601 timestamp must parse")
    }

    func test_commentDTO_prefersPseudonymWhenNameMissing() throws {
        let json = """
        [{"id":"9","body":"gl all","createdAt":"2026-07-02T16:05:05Z",
          "profile":{"pseudonym":"Appropriate-Coyote"}}]
        """.data(using: .utf8)!
        let dtos = try JSONDecoder.polymarket.decode([CommentDTO].self, from: json)
        let comments = MarketMapper.comments(from: dtos)
        XCTAssertEqual(comments.first?.authorName, "Appropriate-Coyote")
    }

    func test_commentDTO_toleratesMissingProfileAndCreatedAt() throws {
        let json = #"[{"id":"1","body":"hi"}]"#.data(using: .utf8)!
        let dtos = try JSONDecoder.polymarket.decode([CommentDTO].self, from: json)
        let comments = MarketMapper.comments(from: dtos)
        let comment = try XCTUnwrap(comments.first)
        XCTAssertEqual(comment.authorName, "Anonymous")
        XCTAssertNil(comment.createdAt)
        XCTAssertNil(comment.avatarURL)
    }

    func test_commentDTO_toleratesMistypedFields() throws {
        // profile.name is a number, body missing entirely — must degrade, never throw.
        let json = #"[{"id":"1","profile":{"name":42}}]"#.data(using: .utf8)!
        let dtos = try JSONDecoder.polymarket.decode([CommentDTO].self, from: json)
        let comments = MarketMapper.comments(from: dtos)
        let comment = try XCTUnwrap(comments.first)
        XCTAssertEqual(comment.body, "")
        XCTAssertEqual(comment.authorName, "Anonymous")
    }
}
