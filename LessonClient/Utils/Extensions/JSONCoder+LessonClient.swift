import Foundation

enum LessonClientDateCoding {
    static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        return iso8601WithFractional.date(from: raw) ?? iso8601.date(from: raw)
    }

    static func string(_ date: Date) -> String {
        iso8601WithFractional.string(from: date)
    }

    static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

extension JSONDecoder {
    static var lessonClient: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()

            if let raw = try? container.decode(String.self),
               let date = LessonClientDateCoding.parse(raw) {
                return date
            }

            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSinceReferenceDate: timestamp)
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "지원하지 않는 날짜 형식입니다."
            )
        }
        return decoder
    }
}
