# AGENTS.md

## Commits

- Commit after every major change.
- Commit messages must be a single line only (no body, no trailers).

## Data Schema

- The data schema must remain compatible across versions. Data saved by an older version of the app must still decode in newer versions.
- This applies to the `Codable` models in `PowerView/Models/PowerReport.swift` and any other persisted or shared data.
- Do not rename or remove existing fields, or change their types. New fields must be optional or have a default value so older data still decodes.
