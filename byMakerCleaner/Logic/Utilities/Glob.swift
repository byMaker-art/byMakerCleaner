//
//  Glob.swift
//  byMakerCleaner
//
//  Utility for expanding shell wildcard patterns using libc's glob.
//

import Foundation
import Darwin

enum Glob {
    /// Expands a shell wildcard pattern into a list of matched file URLs.
    /// Supports `*`, `?`, `~`, and `{a,b}` syntax.
    static func expand(_ pattern: String) -> [URL] {
        let expandedPattern = (pattern as NSString).expandingTildeInPath
        
        var gt = glob_t()
        defer { globfree(&gt) }
        
        // GLOB_MARK: append a slash to each path which corresponds to a directory
        // GLOB_BRACE: expand {a,b} patterns
        // GLOB_TILDE: expand ~ (though we already did this manually above to be safe)
        // GLOB_NOSORT: do not sort the returned pathnames
        let flags = GLOB_MARK | GLOB_BRACE | GLOB_TILDE | GLOB_NOSORT
        
        let result = glob(expandedPattern.cString(using: .utf8)!, flags, nil, &gt)
        
        if result == 0 {
            var urls: [URL] = []
            for i in 0..<Int(gt.gl_pathc) {
                if let path = String(validatingUTF8: gt.gl_pathv[i]!) {
                    // Remove trailing slash if GLOB_MARK added it
                    var cleanPath = path
                    if cleanPath.hasSuffix("/") && cleanPath.count > 1 {
                        cleanPath.removeLast()
                    }
                    urls.append(URL(fileURLWithPath: cleanPath))
                }
            }
            return urls
        }
        
        // Return original path if it exists but didn't contain glob characters,
        // or just return empty if it truly doesn't exist.
        // Actually, glob returns GLOB_NOMATCH if no match is found.
        return []
    }
}
