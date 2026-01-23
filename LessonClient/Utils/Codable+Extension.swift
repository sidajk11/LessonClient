//
//  Codable+Extension.swift
//  LessonClient
//
//  Created by ym on 1/19/26.
//

import Foundation

extension Encodable {
    func encode() -> Data? {
        let encoder = JSONEncoder()
        var jsonData: Data? = nil

        encoder.outputFormatting = .prettyPrinted
        
        do {
            jsonData = try encoder.encode(self)
        } catch {
            print(error.localizedDescription)
        }
        
        return jsonData
    }
}

extension Encodable {
    func toDict() -> [String: Any] {
        do {
            let jsonData = try JSONEncoder().encode(self)
            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                return jsonObject
            }
        } catch {
            print("Error converting object to dictionary: \(error)")
        }
        return [:]
    }
    
    func toArray() -> [Any] {
        do {
            let jsonData = try JSONEncoder().encode(self)
            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [Any] {
                return jsonObject
            }
        } catch {
            print("Error converting object to dictionary: \(error)")
        }
        return []
    }
}

extension Decodable {
    static func fromDict(dict: [String: Any]) -> Self? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])
            let person = try JSONDecoder().decode(Self.self, from: jsonData)
            return person
        } catch {
            print("Error converting dictionary to Person: \(error)")
            return nil
        }
    }
}
