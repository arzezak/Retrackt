#!/usr/bin/env swift

import Foundation

// MARK: - Flags

let args = CommandLine.arguments
let dryRun = args.contains("--dry-run")

if args.contains("--help") || args.contains("-h") {
  print(
    """
    Usage: retrackt [--dry-run] [--help]

    Interactively rename Apple Music tracks by removing a suffix
    (e.g. "(2025 Remaster)") from track names in a specific album.

    Options:
      --dry-run  Preview changes without renaming
      --help, -h Show this help message
    """)
  exit(0)
}

// MARK: - Helpers

func prompt(_ message: String) -> String {
  print(message, terminator: " ")
  guard let input = readLine()?.trimmingCharacters(in: .whitespaces), !input.isEmpty else {
    print("Error: input required")
    exit(1)
  }
  return input
}

func escapeForAppleScript(_ string: String) -> String {
  string.replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\"", with: "\\\"")
}

@discardableResult
func runAppleScript(_ source: String) -> NSAppleEventDescriptor? {
  guard let script = NSAppleScript(source: source) else { return nil }
  var error: NSDictionary?
  let result = script.executeAndReturnError(&error)
  if error != nil { return nil }
  return result
}

// MARK: - Input

let artist = prompt("Artist (e.g. Steely Dan):")
let album = prompt("Album (e.g. The Royal Scam):")
let suffixInput = prompt("Suffix to remove (e.g. (2025 Remaster)):")
let suffix = suffixInput.hasPrefix(" ") ? suffixInput : " \(suffixInput)"
let escapedArtist = escapeForAppleScript(artist)
let escapedAlbum = escapeForAppleScript(album)

// MARK: - Tracks

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

guard let findResult = runAppleScript(findScript) else {
  print("Error: failed to fetch tracks from Music.")
  exit(1)
}

let trackNames =
  findResult.stringValue?
  .split(separator: "\n")
  .map(String.init)
  .filter { !$0.isEmpty } ?? []

if trackNames.isEmpty {
  let artistScript = """
    tell application "Music"
        count (every track of library playlist 1 whose artist is "\(escapedArtist)")
    end tell
    """
  if let artistResult = runAppleScript(artistScript) {
    if artistResult.int32Value == 0 {
      print("Artist \"\(artist)\" not found in library.")
    } else {
      print("No album matching \"\(album)\" found for \(artist).")
    }
  } else {
    print("Error checking artist.")
  }
  exit(1)
}

// MARK: - Album

let albumNameScript = """
  tell application "Music"
      set theTracks to every track of library playlist 1 whose artist is "\(escapedArtist)" and album contains "\(escapedAlbum)"
      return album of (item 1 of theTracks)
  end tell
  """

guard let albumResult = runAppleScript(albumNameScript) else {
  print("Error: failed to fetch album name from Music.")
  exit(1)
}

let actualAlbum = albumResult.stringValue ?? album
let renameAlbum = actualAlbum.hasSuffix(suffix)
let newAlbum = renameAlbum ? String(actualAlbum.dropLast(suffix.count)) : actualAlbum

// MARK: - ANSI helpers

let bold = "\u{1B}[1m"
let dim = "\u{1B}[2m"
let green = "\u{1B}[32m"
let red = "\u{1B}[31m"
let reset = "\u{1B}[0m"

// MARK: - Preview

if renameAlbum {
  print("\n  \(bold)Album:\(reset) \(green)\(newAlbum)\(reset) \(dim)\(suffixInput)\(reset)\n")
}

var toRename: [(old: String, new: String)] = []
for name in trackNames {
  if name.hasSuffix(suffix) {
    let newName = String(name.dropLast(suffix.count))
    toRename.append((old: name, new: newName))
    print("  \(green)\(newName)\(reset) \(dim)\(suffixInput)\(reset)")
  } else {
    print("  \(dim)\(name) (no change)\(reset)")
  }
}

if toRename.isEmpty {
  print("\nNo tracks match that suffix.")
  exit(1)
}

if dryRun {
  print("\n\(dim)(dry run)\(reset) \(toRename.count) track(s) would be renamed.")
  exit(0)
}

// MARK: - Confirm

let albumNote = renameAlbum ? " + album" : ""

let confirm = prompt("\nRename \(toRename.count) track(s)\(albumNote)? (y/n)")
guard confirm.lowercased() == "y" else {
  print("Cancelled.")
  exit(0)
}

// MARK: - Rename

var renamed = 0
var errors = 0

for (i, (old, new)) in toRename.enumerated() {
  print("  Renaming [\(i + 1)/\(toRename.count)] \(new)\r", terminator: "")
  fflush(stdout)
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
  if runAppleScript(renameScript) != nil {
    renamed += 1
  } else {
    print("\r\(red)  Error renaming: \"\(old)\"\(reset)")
    errors += 1
  }
}

if renameAlbum {
  print("  Renaming album...\r", terminator: "")
  fflush(stdout)
  let escapedActualAlbum = escapeForAppleScript(actualAlbum)
  let escapedNewAlbum = escapeForAppleScript(newAlbum)
  let albumRenameScript = """
    tell application "Music"
        set theTracks to every track of library playlist 1 whose artist is "\(escapedArtist)" and album is "\(escapedActualAlbum)"
        repeat with t in theTracks
            set album of t to "\(escapedNewAlbum)"
        end repeat
    end tell
    """
  if runAppleScript(albumRenameScript) == nil {
    print("\r\(red)  Error renaming album\(reset)")
    errors += 1
  }
}

// MARK: - Summary

print("\r\u{1B}[2K", terminator: "")
if errors == 0 {
  let albumMsg = renameAlbum ? " Album updated." : ""
  print("\(green)\(bold)Done!\(reset) Renamed \(renamed) track(s).\(albumMsg)")
} else {
  print("\(green)\(bold)Done!\(reset) Renamed \(renamed), \(red)\(errors) failed\(reset).")
}
