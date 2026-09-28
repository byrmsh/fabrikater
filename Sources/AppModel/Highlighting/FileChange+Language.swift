import TranscriptKit

extension FileChange {
    /// The language the changes panel highlights this file's diff lines in, from its extension.
    public var language: CodeLanguage? {
        CodeLanguage(path: path)
    }
}
