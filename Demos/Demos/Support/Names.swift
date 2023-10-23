//
//  WordID.swift
//  Demos
//
//  Created by Jonathan Wight on 10/23/23.
//

import Foundation

// https://github.com/fnichol/names

struct Names {
    static let shared = Names()

    let adjectives: [String.SubSequence]
    let nouns: [String.SubSequence]

    init() {
        do {
            adjectives = try String(contentsOf: Bundle.main.url(forResource: "adjectives", withExtension: "txt")!).split(whereSeparator: \.isNewline)
            nouns = try String(contentsOf: Bundle.main.url(forResource: "nouns", withExtension: "txt")!).split(whereSeparator: \.isNewline)
            print(adjectives.count, nouns.count)
        }
        catch {
            fatalError("\(error)")
        }
    }

    func random(pad: Int? = nil) -> String {
        let adjective = adjectives.randomElement()!
        let noun = nouns.randomElement()!
        if let pad {
            let max = Int(pow(10, Double(pad)))
            let pad = Int.random(in: 1..<max)
            return "\(adjective)-\(noun)-\(pad)"
        }
        else {
            return "\(adjective)-\(noun)"
        }
    }

    func hashed<Value>(hashable value: Value, pad: Int? = nil) -> String where Value: Hashable {
        var value = abs(value.hashValue)
        print(value)
        let adjective = adjectives[value % adjectives.count]
        value /= adjectives.count
        let noun = nouns[value % nouns.count]
        value /= nouns.count
        if let pad {
            let padCount = Int(pow(10, Double(pad))) - 1
            print("TOTAL", adjectives.count, nouns.count, padCount, adjectives.count * nouns.count * padCount)
            let pad = value % padCount
            value /= padCount
            print(value)
            return "\(adjective)-\(noun)-\(pad)"
        }
        else {
            return "\(adjective)-\(noun)"
        }
    }
}
