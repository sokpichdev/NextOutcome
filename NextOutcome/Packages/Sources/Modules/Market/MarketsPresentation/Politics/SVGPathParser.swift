//
//  SVGPathParser.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import SwiftUI

/// Pure parser converting an SVG path-data string (a `d` attribute) into a SwiftUI `Path`.
///
/// Only supports the subset of commands present in `USStateGeometry`'s source data: moveto
/// (`M`/`m`), lineto (`L`/`l`), horizontal/vertical lineto (`H`/`h`, `V`/`v`), and closepath
/// (`Z`/`z`) — both absolute and relative forms, including the SVG shorthand of repeating a
/// command's coordinate pairs without re-stating the letter (e.g. `l 1,2 3,4` is two linetos).
/// No curve commands (`C`/`S`/`Q`/`T`/`A`) are handled since none appear in the source data.
public enum SVGPathParser {
    /// Parses an SVG path-data string into a `Path`.
    /// - Parameter d: The path's `d` attribute value.
    /// - Returns: The equivalent SwiftUI path. Stops (returning whatever was built so far) if
    ///   the data is malformed or uses an unsupported command.
    public static func path(from d: String) -> Path {
        var path = Path()
        var current = CGPoint.zero
        var start = CGPoint.zero
        let tokens = tokenize(d)
        var index = 0
        var lastCommand: Character?

        func nextNumber() -> Double? {
            guard index < tokens.count, case let .number(v) = tokens[index] else { return nil }
            index += 1
            return v
        }

        while index < tokens.count {
            let commandChar: Character
            if case let .command(c) = tokens[index] {
                commandChar = c
                index += 1
            } else if let last = lastCommand {
                commandChar = last   // implicit repeat of the previous command
            } else {
                break
            }
            lastCommand = commandChar

            let isRelative = commandChar.isLowercase
            switch Character(commandChar.lowercased()) {
            case "m":
                guard let dx = nextNumber(), let dy = nextNumber() else { return path }
                current = isRelative ? CGPoint(x: current.x + dx, y: current.y + dy) : CGPoint(x: dx, y: dy)
                path.move(to: current)
                start = current
                // Further implicit coordinate pairs after a moveto are linetos (SVG spec).
                lastCommand = isRelative ? "l" : "L"
            case "l":
                guard let dx = nextNumber(), let dy = nextNumber() else { return path }
                current = isRelative ? CGPoint(x: current.x + dx, y: current.y + dy) : CGPoint(x: dx, y: dy)
                path.addLine(to: current)
            case "h":
                guard let dx = nextNumber() else { return path }
                current = CGPoint(x: isRelative ? current.x + dx : dx, y: current.y)
                path.addLine(to: current)
            case "v":
                guard let dy = nextNumber() else { return path }
                current = CGPoint(x: current.x, y: isRelative ? current.y + dy : dy)
                path.addLine(to: current)
            case "z":
                path.closeSubpath()
                current = start
            default:
                return path
            }
        }
        return path
    }

    /// One lexical token: a command letter or a parsed number.
    private enum Token {
        case command(Character)
        case number(Double)
    }

    /// Splits a path-data string into command-letter and number tokens. Numbers are separated
    /// by commas/whitespace, or implicitly by a `-` sign starting a new negative number with
    /// no separator (a common SVG minification, e.g. `"1.2-3.4"` → `1.2`, `-3.4`).
    private static func tokenize(_ d: String) -> [Token] {
        var tokens: [Token] = []
        var numberBuffer = ""
        func flushNumber() {
            if !numberBuffer.isEmpty, let value = Double(numberBuffer) { tokens.append(.number(value)) }
            numberBuffer = ""
        }
        for char in d {
            if "MmLlHhVvZz".contains(char) {
                flushNumber()
                tokens.append(.command(char))
            } else if char == "," || char.isWhitespace {
                flushNumber()
            } else if char == "-" {
                flushNumber()
                numberBuffer.append(char)
            } else {
                numberBuffer.append(char)
            }
        }
        flushNumber()
        return tokens
    }
}
