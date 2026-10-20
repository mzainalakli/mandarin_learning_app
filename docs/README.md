# TOCFL Mandarin — Documentation

TOCFL Mandarin is an offline, cross-platform Flutter app for learning **Traditional Mandarin (正體字)** vocabulary aligned with Taiwan's **TOCFL** proficiency bands (A1–C2). It shows Traditional Hanzi, Pinyin and Zhuyin (注音符號), runs quizzes in several directions, tracks per-word review statistics in a local SQLite database, and imports/exports vocabulary as XLSX, CSV and JSON.

| | |
|---|---|
| Package name | `mandarin_app` (display name: *TOCFL Mandarin*) |
| Version | `1.0.0+1` |
| Framework | Flutter 3.47.6 (CI-pinned), Dart `^3.13.5` |
| Platforms built in CI | Android (APK), Linux (x64), Windows (x64) |
| Storage | Local SQLite via `sqflite` (mobile) / `sqflite_common_ffi` (desktop) |
| Network | None required. Everything runs offline. |

## Contents

| Document | Read it if you want to… |
|---|---|
| [Getting started](getting-started.md) | install prerequisites, run, test and build the app |
| [User guide](user-guide.md) | learn what every screen does and how to study with the app |
| [Quiz engine](quiz-engine.md) | understand quiz modules, answer modes, the pass queue, the timer and scoring |
| [Import & export](import-export.md) | prepare XLSX/CSV/JSON files, understand header aliases and category rules |
| [Data & database](data-and-database.md) | see the schema, migrations, the bundled dataset and how it is seeded |
| [Pinyin → Zhuyin converter](pinyin-zhuyin.md) | understand how Zhuyin is generated and its input rules |
| [Architecture](architecture.md) | navigate the code: layers, state management, navigation, startup |
| [Development](development.md) | contribute: project layout, lints, tests, CLI tools |
| [CI/CD](ci-cd.md) | understand the GitHub Actions build and release pipeline |
| [Known issues](known-issues.md) | learn about verified bugs and limitations before relying on a feature |

## At a glance

- **Content:** 14,868 bundled vocabulary entries (`assets/data/mandarin_vocabulary.csv`) spread across TOCFL A1–C2. See [Data & database](data-and-database.md) for the real distribution — most B2–C2 entries have no English meaning yet.
- **Practice:** three Pinyin/Hanzi/Meaning quiz modules, two Zhuyin training modules, Multiple Choice or Flashcard answer modes, optional per-question timer.
- **Personalisation:** custom word lists ("libraries"), quick-add form, bulk import/export.
- **UI:** Material 3, crimson and jade colour scheme, automatic light/dark theme (follows the system), responsive layout (drawer on phones, permanent sidebar on wide screens).

## A note on the older documents in this folder

`resume.md`, `summary.md` and `tes.md` are earlier working notes. Parts of them no longer match the code (for example, they describe an XLSX seed asset and a `tocfl_a1_seed.json` fallback that do not exist in the repository today — the app seeds from the CSV only). The documents listed above were written against the current source and are the ones to trust.
