#!/usr/bin/env swift

import Foundation

// MARK: - Flags

let args = CommandLine.arguments
let dryRun = args.contains("--dry-run")

if args.contains("--help") || args.contains("-h") {
    print("""
    Usage: retrackt [--dry-run] [--help]

    Interactively rename Apple Music tracks by removing a suffix
    (e.g. "(2025 Remaster)") from track names in a specific album.

    Options:
      --dry-run  Preview changes without renaming
      --help, -h Show this help message
    """)
    exit(0)
}

// MARK: - Input

func prompt(_ message: String) -> String {
    print(message, terminator: " ")
    guard let input = readLine()?.trimmingCharacters(in: .whitespaces), !input.isEmpty else {
        print("Error: input required")
        exit(1)
    }
    return input
}

func escapeForAppleScript(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\")
     .replacingOccurrences(of: "\"", with: "\\\"")
}

let artist = prompt("Artist (e.g. Steely Dan):")
let album = prompt("Album (e.g. The Royal Scam):")
let suffixInput = prompt("Suffix to remove (e.g. (2025 Remaster)):")
let suffix = suffixInput.hasPrefix(" ") ? suffixInput : " \(suffixInput)"

let escapedArtist = escapeForAppleScript(artist)
let escapedAlbum = escapeForAppleScript(album)

// MARK: - Find tracks

let findScript = """
tell application "Music"
    set output to ""
    set theTracks to every track of library playlist 1 whose artist is "\(escapedArtist)" and album contains "\(escapedAlbum)"
    repeat with t in theTracks
        set output to output & (name of t) & linefeed
    end repeat
    return output
end tell
"""

let appleScript = NSAppleScript(source: findScript)!
var errorInfo: NSDictionary?
let result = appleScript.executeAndReturnError(&errorInfo)

if let error = errorInfo {
    print("Error: \(error)")
    exit(1)
}

let trackNames = result.stringValue?
    .split(separator: "\n")
    .map(String.init)
    .filter { !$0.isEmpty } ?? []

if trackNames.isEmpty {
    let artistCheck = NSAppleScript(source: """
    tell application "Music"
        count (every track of library playlist 1 whose artist is "\(escapedArtist)")
    end tell
    """)!
    var artistErr: NSDictionary?
    let artistResult = artistCheck.executeAndReturnError(&artistErr)

    if let err = artistErr {
        print("Error checking artist: \(err)")
    } else if artistResult.int32Value == 0 {
        print("Artist \"\(artist)\" not found in library.")
    } else {
        print("No album matching \"\(album)\" found for \(artist).")
    }
    exit(0)
}

// MARK: - Preview

print("\nFound \(trackNames.count) track(s):\n")

var toRename: [(old: String, new: String)] = []
for name in trackNames {
    if name.hasSuffix(suffix) {
        let newName = String(name.dropLast(suffix.count))
        toRename.append((old: name, new: newName))
        print("  \"\(name)\" → \"\(newName)\"")
    } else {
        print("  \"\(name)\" (no change)")
    }
}

if toRename.isEmpty {
    print("\nNo tracks match that suffix.")
    exit(0)
}

if dryRun {
    print("\n(dry run) \(toRename.count) track(s) would be renamed.")
    exit(0)
}

// MARK: - Confirm

let confirm = prompt("\nRename \(toRename.count) track(s)? (y/n)")
guard confirm.lowercased() == "y" else {
    print("Cancelled.")
    exit(0)
}

// MARK: - Rename

var renamed = 0
for (old, new) in toRename {
    let escapedOld = escapeForAppleScript(old)
    let escapedNew = escapeForAppleScript(new)

    let renameScript = """
    tell application "Music"
        set theTracks to every track of library playlist 1 whose artist is "\(escapedArtist)" and name is "\(escapedOld)"
        repeat with t in theTracks
            set name of t to "\(escapedNew)"
        end repeat
    end tell
    """

    let renameApple = NSAppleScript(source: renameScript)!
    var renameError: NSDictionary?
    renameApple.executeAndReturnError(&renameError)

    if let error = renameError {
        print("  Error renaming \"\(old)\": \(error)")
    } else {
        print("  Renamed: \"\(old)\" → \"\(new)\"")
        renamed += 1
    }
}

print("\nDone! Renamed \(renamed) track(s).")
