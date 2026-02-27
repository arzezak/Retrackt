# Retrackt

A command-line tool that batch-renames Apple Music tracks by stripping a suffix (e.g. "(2025 Remaster)") from track and album names.

## Usage

```
swift retrackt.swift [--dry-run] [--help]
```

## Example

```
$ swift retrackt.swift
Artist (e.g. Steely Dan): rolling stones
Album (e.g. The Royal Scam): let it bleed
Suffix to remove (e.g. (2025 Remaster)): (Remastered 2019)

  Album: Let It Bleed (Remastered 2019)

  Gimme Shelter (Remastered 2019)
  Love In Vain (Remastered 2019)
  Country Honk (Remastered 2019)
  Live with Me (Remastered 2019)
  Let It Bleed (Remastered 2019)
  Midnight Rambler (Remastered 2019)
  You Got the Silver (Remastered 2019)
  Monkey Man (Remastered 2019)
  You Can't Always Get What You Want (Remastered 2019)

Rename 9 track(s) + album? (y/n) y
Done! Renamed 9 track(s). Album updated.
```

## Notes

- **Artist and album** matching is case-insensitive and partial — "rolling stones" finds "The Rolling Stones".
- **Suffix** must match exactly as it appears in the track/album name (case-sensitive).
- If the album name also ends with the suffix, Retrackt offers to rename it too.
- Use `--dry-run` to preview changes without modifying anything.
