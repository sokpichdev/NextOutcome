//
//  WorldLandMask.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/09/2026.
//

import Foundation

/// A coarse equirectangular land/water bitmask of the Earth, used to draw real continents on
/// the hub's globe instead of a uniformly dotted sphere.
///
/// The data is derived from Natural Earth's public-domain `ne_110m_land` vector dataset
/// (<https://www.naturalearthdata.com>, CC0), rasterised offline onto a 720x360 grid of
/// half-degree cells and stored below as a run-length-encoded, base64-wrapped bit stream.
/// Runs alternate starting with *water*, and each run length is a little-endian base-128
/// varint — the whole map costs about 6 KB of source instead of a bundled image asset, and it
/// decodes once per process into a flat `[Bool]`.
enum WorldLandMask {
    /// Grid width in cells (one cell per half-degree of longitude).
    static let width = 720
    /// Grid height in cells (one cell per half-degree of latitude).
    static let height = 360

    /// `true` where the corresponding grid cell's centre falls on land.
    ///
    /// Row 0 is the northernmost band (+90 degrees latitude) and column 0 starts at -180
    /// degrees longitude, matching the layout an equirectangular texture expects.
    static let cells: [Bool] = decode()

    /// Whether the given coordinate falls on land, to the resolution of the grid.
    /// - Parameters:
    ///   - latitude: Latitude in degrees, -90...90.
    ///   - longitude: Longitude in degrees, -180...180.
    /// - Returns: `true` when the containing cell is land; `false` for water or out-of-range
    ///   input.
    static func isLand(latitude: Double, longitude: Double) -> Bool {
        guard latitude >= -90, latitude <= 90, longitude >= -180, longitude <= 180 else { return false }
        let x = min(width - 1, max(0, Int((longitude + 180) / 360 * Double(width))))
        let y = min(height - 1, max(0, Int((90 - latitude) / 180 * Double(height))))
        return cells[y * width + x]
    }

    /// Expands the encoded runs into one flag per grid cell.
    private static func decode() -> [Bool] {
        let total = width * height
        var cells = [Bool](repeating: false, count: total)
        guard let bytes = Data(base64Encoded: encodedRuns) else {
            assertionFailure("WorldLandMask: land data is not valid base64")
            return cells
        }

        var index = 0
        var isLand = false // runs alternate, starting with water
        var value = 0
        var shift = 0
        for byte in bytes {
            value |= Int(byte & 0x7F) << shift
            guard byte & 0x80 == 0 else {
                shift += 7
                continue
            }
            let end = min(total, index + value)
            if isLand, index < end {
                for cell in index..<end { cells[cell] = true }
            }
            index = end
            isLand.toggle()
            value = 0
            shift = 0
        }
        return cells
    }

    /// The run-length-encoded land bit stream, split into source-friendly chunks.
    private static let encodedRuns: String = [
        "qUsd3QQoITLLBDIWBQQk0wQyCFEICbcELwdQARSqBAkEKQVlfAQBBFMLywISCRoFYkgSKAVWDsoCEgEdDV47BQMGBA2FAQ61AgIWDwISEmA8",
        "EpQBDAMDogIDDAgEBAUMAhYLZj4RoQEJsQIFAwYIAwYWBmtADQQEmgEInQIHGwUMAwIPDWhEBwYGsAMHOREUZUIHqQEHigIKDgEYCwQXD2Ou",
        "AQVBDIUCBwYFBwQLCggFFAIWYaMBDjwehAILBAcHCgkHDAMtUJwBDDgrLw3FARcKBgMFAxkrTpgBCjYyLxACBsMBBh0EBRctS5gBCDUyNgMR",
        "A6oBCn5ImAEHOC79ARAfAQkKCAELATBHlAEIMD84A7oBEAIBEQQGCAMJBQUDBwIHK0CaAQcvTQgKGwS3AQ0CBgEEAwIDBQYDAQcCBgYIAQoz",
        "QZYBBxoHBAIKYRYEuQEMAhQBBgcKAgMIEwIIKT2aAQYbCAQBBAUCYBUTqwEKAxUBBgoHAgMIICVClAEIGQgEAwFqBgEOFTwFKQJBBAoYEAcG",
        "JSU3AQaWAQcVCgMFAWoEKDcCKQoBBEQdDgkFJx8DAjYCBFwMMAcSDAOqAU4cKAIbFwsKCSYbOGMPSQwCrAFKKxMLAwEDAwkgBAQDBg4EBAEH",
        "FBoGATdVGAECOAILCwKsARUNKDIFIgYBARkGBwMICggKEyA0ViE0CQYJA70BBBECARpnAwgGARcIAQMGCQoPIjFYKSACCAEECwUIBL0BARkW",
        "aAwHDQUDDQQIEA4cL1ovCgUJBQMaAQoC2gEYZQQFAwwDGQMKCQQEERYpXzQHBgQwBNwBFqUBCQMGERQpXzYGAwUxA94BAQYSoAESFxEnXzcH",
        "AwIyBOcBCQUDmAEYDAMJESQYAwoFNyoGBgMEATgB1wECEQWjARkMBQUUHhwTNRUEFQuYAgcHC6ABAgQMFQYCFhkkEDMUCBMKmAIKBQwKAZMB",
        "AwcIGRwXIhIzFQYVAwQElgInkgEDCgcBCBEaFyUNMxYFGAOaAiqNAQcGAwUQDhsVKAc1FgW4AhYEDJABCgEaCAIFGxNjFgW7AiCSAREDFwcD",
        "AR0QYhcGvQIekQESAgYBAwUCAgoEIQ9gGAibAgMYI5EBGwEDDC0OXxkIkwIBBgMVKI8BIA0tDGAYCY4CBgUDEysbAQcDaCERLwZgGQiMAgkB",
        "BRErAwIYAgcGZSIQMQNhGwgGBv0BDQ0DAjcSAgURXSIQCAOLARoU+wEOBQIBQhAFARdaIREHBYoBCQEPC/IBBQQFBwoGRgIDBAEHHlsdFAUG",
        "iQEHBAwN7AEkBlAHIlgfHnIEFAMHChDpASMHUQQDAyVTHx5wBB8KEOcBIgtOBAQDJ1IDARwebwgXAgMJCgMC5gEjDUsEMVgZHm8HFQUECAnr",
        "ASMOSQQ1WRUfcAUWBgMHCukBJA9GBjZcEiFuBxQEAgMBAw3oASUNRgM8YAslbQcUAwMCEuUBJwxEA0FgBixjBAMHEwMOAgTmASkNhwFgBi1g",
        "BgYFEgUCAgXzASUKhQECBV4HLF8HBgYRiAIEARoIhgECBl4GLl0HAwkKkAIBAxoIhwEBBl4HLlwGBAwGlgIZBZMBXQUvXAUFDAWWAhsEkwFe",
        "BC1eAgcMBpICAQMbA5UBiwECA2cLA5MCAwMaAZgBhwEEA2YIBZYCAwOxAXwFBwUCZgIBAQqWAgMEsgEEAXMFAwoFb5kCAwS0AQMCbwoCBwpn",
        "nQIDAgECtAEEAmsDBwoLYwMCmwIEArkBAQNqAgcMDGGhAgQBugEDAWkBCQsNY54CBQG7AWsBChMBAgJlmwIGAroBeBQCZk4CGQWrAQcDuQF3",
        "AgMCAXZABAUGFgiqAQgBuwGAAXY+BwMFFgmpAcUBdAMHdxwCIAYeCKsBCgG7AXIDBXscBRwJAwUTCaoBCgO6AW8FA34UAQcFGxQRB6sBCwQD",
        "AbUBbAgCfxMFBQUaFhAHqQEMCLQBbHsaAwIIBgcWGA8IoQEBBAwKtAFrfBgMAQIHCBQbDAqeAREItwFrfBgLAgQGCRIbDQmdARIDAgK5AWx6",
        "GAsCBQgHEQkHCw4IAQKYARQCvgFnfxYWBwYTBQsIEAuWARYCvAFngAETDwMJBwQJBAMDKQcBAYYBAg8VA7wBZYIBEhEDCgMDAQIGAQMFLwWG",
        "AQQNFwS8AWSCARIRAgwCBwYHLgiEAQQEAgYZBLwBYQEBggETEQINAgcGBi4HhAEFAgYEGQS9AWGDARMgAQgFBy0Kfw8GFwS/AV0BAoQBESAC",
        "CQYFLQqAAQ4HFgPBAVwBAYUBERoGDAMBAQYsCoIBAwEKBhMFwQFchwEPFQIHBAwDCS4HgwEBBQgGDgECBsIBXIsBCQoEAQsWAgkOASIBigEJ",
        "Bw4JwgFcjAECCxQmAgQDBKoBCwYNCcQBW4wBAggYMqgBDQYNCcUBWowBBgIaGQYNAgSnAQ4FBxDGAViMASIsAgWnAQ4DCA7LAVSNASIzqgEV",
        "BAIBAQTRAVCOASUxqgEUAQMEAgHVAU2NAScwqwESBQEC2wFKjgEtDwIarAERBd4BSY4BMgkGGK0BEgLfAQQBQ48BMgkKE68BEQLgAQMDQI8B",
        "NQcPBQQFrwERAeIBAwM/kAE3BMsB9QEDAy8HCZABhgL2AQIEJgEHCAEDBY8BcwWPAfYBAgMjCAIOBI4BWQEaBY8B9wECAyEZBYsBVwEDARsF",
        "jgH4AQIDHhwEigFZAR4GjAH3AQUEGxwFhwFdBBsGigH5AQQEGh4FhQFeBBwHhwH8AQQDGR4FAgKBAV8EHAcEA37/AQIEGB8EBQF9YQUbDAEB",
        "foACAQQZHwODAWIEGwIBCQECfIECAgUWIQGDAWMFGwEBBwMICARpggIDBRUmAn1kBB0GBBVoBAL9AQMFFCcBfGYEHQQGFWUFAoACAgUTJwF7",
        "ZwYnFGMFA4ECAQYRpAFnBikUXwcDiQIQHAl+aQYpFCoCMAoBiwIPGwIDCHtqBSoTKgMrDgGLAhAjBXlsBCkUJwYpnAIQEAURBHdsBCgWIgof",
        "BQG6AQFlEQ0HEgV1bAUmHRwLHQUCoAIRDQYUB3NrBiQeGwwcwwECYxIMBhwDAQJsawciHxkQGQYEugECZBIKBx0IaWwHIh4YERgGBKMCEQcJ",
        "HghpawcgIBcTGAUEpAISAQwTBAQHAQECAQMDY2wHHiEWFRcdBI8CHBUBem0HGyMVFhgcA5ICGZABbwcaJBIYGRsEkwIXkAFvBxYoERkFARQa",
        "BJYCFJABbwgTKhAZBAMVGQOaAgIFCgEIhwFwBhMrDh0BBBYXA6MCE4UBcgYRLQwjFxYDpAIShAF1BA0yCyQWFwKlAhKEAXUDDDMLJBYXAwEB",
        "pgINhQF2Awg2CyQXFwamAgIBCIUBdwEFOwskAwIRFgIDAqkCCIUBeAEDPAolAwIRFwEEAaoCBxcBbng/CiUDBQ0YAQYCqAIGFgICAmp2EAEx",
        "CSUDBgwgAakCBBQEAwRqdgkGMgglAgcLGwIDAqoCBBAPDQFcdgQKMgglAggJFgEFAQECrAIFEAcBDAIEAQJdgwEyByYCCgUYAQcCrQIBAQQO",
        "BwITX4EBNAUnAQwDGAEHArECBAQEBAgCFF+AATQFAgIjAQwCGAEOAa0CCAICAiBffzQDBAIiBAoBJgSuAgQFJV1+NwEDBCEFLQewAgMDJ1x+",
        "PAMjAysJsQIBBSdcfD0DJAIrAQMFuAInXXo9AyUDHgINAwEBuAIoXRsEWT4DJQQdAg0DugIvWBUJWGcEGwUNAboCMlYSC1deBAUGGAjHAjNW",
        "BRhVXwUFBhYIyAI0eU5gBQQGFQjKAjR5TGIFBAUUCMoCNXlLZAUEBBMJyQI2eUpmBQMEEAzIAjh4SWgFAwQPDccCOXdHawcCAgsBAg4TAbIC",
        "OndGbQcCAQoTDAEFAq8CPHdEbwgMEgQJBgKvAjt4Q3AJCxEFAQ4BrwJAc0NyCAsRBAEPAa8CQAECcEJ0BwwQBAIEAgkBBgWiAkdtQnUICg8F",
        "BhEGogJJa0F2CAsNBgUUBAcCmQJJbD94CAoNBQYXAgQGmQJMaDx7CQgNBQMBAhQFAwsSAoECUWQ7fAgMAgEGBQMBAwcCAgUEFBIB/wFUYzp9",
        "BxEDBwIBAwgBBwEEAQEUjgJWYzh+BxsCAgMYFA0D+wFYYjeBAQUbAgIBAQEbEgwC/QFbXzaCAQQbAgQBHREKAv4BXF42gwEDQBEEBgYB+AFc",
        "XjaGAQQ0AQgSBAIJAfgBW182hAEGBAMsAQgREQEBAfcBWWA1hgENMxEUAfYBWWA0igEBAgovDQEFFgH0AVhgNJEBCA4BHQMCBwUEFwHyAVhg",
        "NZsBBAIEBgQbBgYEGAHxAVZhNakBAyIBCAUXAfABVmE2nwECBgMtBRQC8gFUYzWnAQExBIcCUmU28gEC8AFRZTa3AQETApcCUGY2uAECEQKY",
        "Ak5nNhEBowEBAQoKApgCTmY3EQGiAQ0KA5gCTGY4EAOhAQwKBJgCS2c4EAOgAQwLBJkCSmY5DwSXAQUDDQsFmAJKZjoNBZYBBgMMDAcrAesB",
        "SWY5DQeUARcLCCoB7QFHZjkMBgEBlAEZCQiaAkVlOQkLkwEBARoICCsBGAHXAUNlOAoLkQEBAR0GCUIC2gFBZTUMC5IBIQQKnQJBZjIOC5IB",
        "Lz8C3gE+ZzEPC5EBMJ8CPmgvEAqRATKfAj1oLhIJkQEzngI8aiwTCY8BN5wCO2srFAiNATsfAfsBO2wrEgmIAUEfAvkBOm0rEQqGAUQfAvgB",
        "Om4rEAmGAUUgAvcBOXAqEAmFAUYiAfUBOXEqEAmEAUqVAjV1KhAIhQFKlQIyeCoQCIQBS5UCMHoqEAiEAU2TAi58KBMGhQFOkgItfSYWA4gB",
        "TpECLH8jowFOkAItfyShAU+QAi1/JKEBT5ACLYABIqMBTpACLYABIqMBT48CLYEBIaQBTo4CLYMBH6UBTo4CLIQBHqcBTY4CK4YBHKgBTY4C",
        "K4cBGqkBTI8CKogBGqkBTI8CKYoBGKsBS48CKIsBF6wBGwYqjwImjQEWrgEUAQENJpACJo0BFK8BExIkkQIljgETsAERFQYBG5ECJY8BELIB",
        "EhYEAhuRAhsBCZABBrsBCR8DAhuSAhwDBJQBAcABBSIBAwEBGSwB5AEeiAMYLQPiAR6JAxcuAuEBIIkDFTAB4QEgigMUMQHfASGKAxQxA90B",
        "IIwDEjIEAwHYAR+PAwYBBTYI2AEcmwMBOAfaARbYAwbbARfZAwXbARbbAwTaAReeAwE3AQQD2wESpAMHLwIBAQED3AESpAMHLgXgAQEBEQEB",
        "ogMFLwXgAQEBEqMDBS4F4QEBARCmAwMtBuQBENUDB+EBAQIP0wMH5AES0gMH5QEP1AMI5QEO1AMI5QEP1QMG5gEQwQUSvQUSvQUTvQURvwUQ",
        "kAIErAMQkAICrgMOwwUMxAUMFAGvBQwQBq4FDQ8BtQUHAQPFBQEBBAEFxQUCAQIBBccFC8cFDcYFBt9fBMgFAwEBxwUDzAUDywUFygICPwK8",
        "AgflAQpZBw0GKAO6AgbmAQ08AhgLCA4KDQEPuAIF4wEUMAEDFgIuATSlAgTfAR4FBR6DAaQCBNsBMhWJAaACB8QBAw04EpIBBQKLAgQCC8AB",
        "CQU7EZ0BiAIEAgy7AQ8BPQyoAYICBQEMiwEGBQUBDA9OC68B/gEHAQyFAQwCcwi3AfMBCwIMbAQGBAOHAQfDAbEBATUNAwtlngEHxwGuAQss",
        "AwIFBQxiowEBygGrAQEbASoOX/ACrAELCQMECQoBERZa8wKBAQIEByAqAQoEG1nyApEBDBhPXO0CbzcTSl7sAmhTAUhd7QJinwFd8QJkmAFc",
        "9wJhjgFggQNMAwIFBpYBWoUDTKgBUooDTaEBOAkSkgM+BwicATgND5YDPQYPlAE3Dg+LA2aOAR8BEhAc/QJpjgEcBAsTIPoCaJkBDAoNCyCA",
        "A1gKAqMBPo0DWbcBGgcImQNauQEOsQNYvAEFvANShAVNhQUXAQQCBAolhgUEAwceLK4FBgoO2jc="
    ].joined()
}
