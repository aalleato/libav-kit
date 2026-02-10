import Foundation

/// Parses user-input custom tag strings in various formats.
/// Supports separators: `=`, `:`, `|`
public enum CustomTagParser {
    /// Parses a custom tag input string and returns the key-value pair.
    /// The key is uppercased, and both key and value are trimmed of whitespace.
    ///
    /// Supported formats:
    /// - `KEY=value`
    /// - `KEY:value`
    /// - `KEY|value`
    ///
    /// Separator precedence: `=` is tried first, then `:`, then `|`.
    /// This allows values to contain `:` or `|` when using `=` as the separator.
    ///
    /// - Parameter input: The input string to parse
    /// - Returns: A tuple of (key, value) if parsing succeeds, nil otherwise
    public static func parse(_ input: String) -> (key: String, value: String)? {
        for separator in separators {
            if let range = input.range(of: separator) {
                let key = String(input[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let value = String(input[range.upperBound...]).trimmingCharacters(in: .whitespaces)

                if !key.isEmpty, !value.isEmpty {
                    return (key.uppercased(), value)
                }
            }
        }
        return nil
    }

    /// Formats a key-value pair as a string using the specified separator.
    ///
    /// - Parameters:
    ///   - key: The tag key
    ///   - value: The tag value
    ///   - separator: The separator to use (default: "=")
    /// - Returns: A formatted string like "KEY=value"
    public static func format(_ key: String, _ value: String, separator: String = "=") -> String {
        "\(key)\(separator)\(value)"
    }

    // MARK: - Multi-Value Parsing (for COMMENT field embedding)

    /// The supported key-value separators in order of precedence.
    public static let separators = ["=", ":", "|"]

    /// Detects the separator used in a string by checking for the first occurrence
    /// of any supported separator in the first line/pair.
    ///
    /// - Parameter input: The input string to analyze
    /// - Returns: The detected separator, or nil if none found
    public static func detectSeparator(_ input: String) -> String? {
        // Check the first line only to detect separator
        let firstLine = input.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? input

        for separator in separators where firstLine.contains(separator) {
            if let range = firstLine.range(of: separator) {
                let key = String(firstLine[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let value = String(firstLine[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !key.isEmpty, !value.isEmpty {
                    return separator
                }
            }
        }
        return nil
    }

    /// Parses multiple key-value pairs from a multi-line string (e.g., from COMMENT field).
    /// The separator is auto-detected from the first pair and applied consistently.
    ///
    /// - Parameter input: Multi-line string with key-value pairs
    /// - Returns: Array of (key, value) tuples, or nil if no valid pairs found
    public static func parseMultiple(_ input: String) -> [(key: String, value: String)]? {
        guard let separator = detectSeparator(input) else {
            return nil
        }

        return parseMultiple(input, separator: separator)
    }

    /// Parses multiple key-value pairs from a multi-line string using the specified separator.
    ///
    /// - Parameters:
    ///   - input: Multi-line string with key-value pairs
    ///   - separator: The separator to use for parsing
    /// - Returns: Array of (key, value) tuples, or nil if no valid pairs found
    public static func parseMultiple(_ input: String, separator: String) -> [(key: String, value: String)]? {
        let lines = input.split(separator: "\n", omittingEmptySubsequences: true)
        var results: [(key: String, value: String)] = []

        for line in lines {
            let lineStr = String(line).trimmingCharacters(in: .whitespaces)
            guard !lineStr.isEmpty else { continue }

            if let range = lineStr.range(of: separator) {
                let key = String(lineStr[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let value = String(lineStr[range.upperBound...]).trimmingCharacters(in: .whitespaces)

                if !key.isEmpty, !value.isEmpty {
                    results.append((key.uppercased(), value))
                }
            }
        }

        return results.isEmpty ? nil : results
    }

    /// Formats multiple key-value pairs into a multi-line string suitable for COMMENT field.
    ///
    /// - Parameters:
    ///   - pairs: Array of (key, value) tuples
    ///   - separator: The separator to use (default: "=")
    /// - Returns: A newline-separated string of key-value pairs
    public static func formatMultiple(_ pairs: [(key: String, value: String)], separator: String = "=") -> String {
        pairs.map { format($0.key, $0.value, separator: separator) }.joined(separator: "\n")
    }
}
