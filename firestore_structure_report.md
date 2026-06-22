# ReadAlert Firestore Structure Report

## Scope and Method

This report documents the Firestore structure actually referenced by the Flutter project. The audit covered all Dart files under `lib/` and searched for `FirebaseFirestore.instance`, collection/document paths, collection-group queries, reads, listeners, writes, updates, and deletes. Types are inferred from concrete write maps and read logic. No credentials or API keys are included.

## Executive Summary

- **Confirmed root collections:** `users` only.
- **Confirmed subcollections under `users/{userId}`:** `library`, `shelves`, `questClaims`, and `custom_genres`.
- **Collection-group queries:** none found.
- **Dynamic collection names:** none found.
- `custom_genres` is read by the UI, but no Firestore write path for it exists in this project. Its document ID convention is therefore uncertain.
- Recommendations, statistics, reports, achievement definitions, quest definitions, and notifications do **not** have separate Firestore collections.

## Root Collection

### `users`

**Document ID pattern:** `{userId}`

`{userId}` is the authenticated Firebase Authentication UID. A user document is created or merged after email/password registration, email/password login, or Google sign-in.

**Purpose:**

- Authentication-linked user profile
- Onboarding state
- XP, points, level, rank selection, and streak state
- Claimed and displayed achievements/badges
- Search history used by the search interface
- Local reading-reminder preference
- Parent document for the user's library, shelves, quest claims, and custom genres

### Fields in `users/{userId}`

- `name`: user's display name; `String`.
- `email`: authenticated email address; `String`.
- `photoURL`: profile image URL or local image path; `String`. An empty string represents a removed avatar.
- `totalXp`: authoritative accumulated XP; `int`.
- `points`: compatibility/mirror value of `totalXp`; `int`.
- `level`: calculated level derived from XP; `int`.
- `currentStreak`: stored consecutive reading-day count; `int`.
- `longestStreak`: highest recorded reading streak; `int`.
- `lastReadDate`: last qualifying reading date in `YYYY-MM-DD` form; `String`.
- `booksRead`: initialized when the user document is created; `int`. The current statistics code derives completed books from the library instead of relying on this field.
- `claimedAchievements`: IDs of claimed achievement definitions; `List<String>`.
- `equippedBadge`: one equipped achievement badge ID; `String`.
- `selectedBadges`: badge IDs selected for display on the profile, limited by the UI to five; `List<String>`.
- `equippedRankBookIndex`: selected unlocked rank/tier image index; `int`.
- `recentSearches`: up to ten recent book-search strings; `List<String>`. The field may be deleted when history is cleared.
- `dailyStreakReminderEnabled`: whether the daily local reminder is enabled; `bool`.
- `dailyStreakReminderTime`: configured reminder time, currently stored as `20:00`; `String`.
- `hasSeenOnboarding`: whether the first-time onboarding dialog has been completed; `bool`.
- `createdAt`: user-document creation time; Firestore `Timestamp`.

## Subcollections

### `users/{userId}/library`

**Document ID pattern:** `{bookId}`

- Books obtained from an external book source use the supplied external book ID.
- Manually created books use a generated UUID v4.

**Purpose:**

- Personal library management
- Book metadata and reading status
- Page-progress and reading-history tracking
- XP and streak calculations
- Quest evaluation
- Recommendation preference extraction
- Statistics, charts, and period reports
- Membership in custom shelves

### Fields in `users/{userId}/library/{bookId}`

- `title`: book title; `String`.
- `authors`: author information; normally `String`, but read logic also accepts `List` for compatibility.
- `categories`: genre/category information; `String`, `List`, or `null` depending on source.
- `description`: book description; nullable `String`.
- `publisher`: publisher name; nullable `String`.
- `publishedDate`: publication date/year as supplied by metadata or manual input; nullable `String`.
- `thumbnail`: external cover URL or local image path; nullable `String`.
- `industryIdentifiers`: ISBN and identifier entries; `List<Map<String, String>>`. Entries can contain `type` and `identifier`; fallback metadata can provide only `identifier`.
- `bookUrl`: optional external book link; nullable `String`.
- `bookFormat`: manual-book format; nullable `String`.
- `location`: optional physical/digital location entered for a manual book; nullable `String`.
- `pageCount`: total pages; `int`.
- `currentPage`: current recorded page; `int`.
- `bestProgress`: highest page used for non-duplicated page XP; `int`.
- `status`: reading state; `String` with code values `Want to read`, `Reading`, or `Finished`.
- `startedReading`: reading start date, generally `YYYY-MM-DD`; nullable `String`.
- `finishedReading`: completion date, generally `YYYY-MM-DD`; nullable `String`. It can be deleted when a finished book is moved back to another status.
- `rating`: user rating, normally `int` from 0 to 5; optional.
- `note`: personal book note; optional `String`.
- `progressHistory`: reading-session records; `List<Map>`.
- `addedAt`: time the book entered the library; Firestore `Timestamp`.
- `onShelves`: IDs of shelves containing the book; `List<String>`.
- `shelfAddedAt`: map of shelf ID to membership timestamp; `Map<String, Timestamp>`.

#### Nested `progressHistory` entry

`progressHistory` is an array inside a library document, not a subcollection.

- `timestamp`: time of the progress event; Firestore `Timestamp`.
- `pagesRead`: newly read pages credited by the event; `int`.
- `dateKey`: normalized date in `YYYY-MM-DD` form; `String`.

### `users/{userId}/shelves`

**Document ID pattern:** `{shelfId}`

`{shelfId}` is a Firestore auto-generated ID because shelves are created with `.add(...)`.

**Fields:**

- `name`: unique shelf name within the user's shelves; `String`.
- `bookCount`: maintained count of linked library books; `int`.
- `createdAt`: shelf creation time; Firestore `Timestamp`.

**Purpose:** custom organization of library books. Shelf membership itself is stored on each library document through `onShelves` and `shelfAddedAt`.

### `users/{userId}/questClaims`

**Document ID pattern:** `{claimKey}`

Confirmed formats:

- Daily: `daily_{YYYY-MM-DD}_{questId}`
- Weekly: `weekly_{weekStartYYYY-MM-DD}_{questId}`

The deterministic claim key prevents the same quest from being claimed more than once in its daily or weekly period.

**Fields:**

- `questId`: hard-coded quest definition ID; `String`.
- `type`: `daily` or `weekly`; `String`.
- `title`: quest title captured at claim time; `String`.
- `rewardXp`: awarded quest XP; `int`.
- `claimedAt`: server claim time; Firestore `Timestamp`.

**Purpose:** records claimed daily/weekly quests and prevents duplicate XP awards. Quest definitions and completion rules are hard-coded in `QuestService`; they are not stored in Firestore.

### `users/{userId}/custom_genres`

**Document ID pattern:** uncertain.

The project only listens to this subcollection and reads its documents. No `.set`, `.add`, `.update`, or `.delete` operation for `custom_genres` was found. The IDs may be auto-generated or created by an older/external workflow, but this cannot be confirmed from the current code.

**Confirmed field:**

- `name`: custom genre name shown in the library category list; likely `String`.

**Purpose:** supplements genre/category names derived from books when displaying the user's genre list.

## Report-Ready Table

| Collection / Subcollection | Document ID | Main Fields | Purpose | Related Feature |
|---|---|---|---|---|
| `users` | `{userId}` (Firebase Auth UID) | `name`, `email`, `photoURL`, `totalXp`, `points`, `level`, streak fields, achievement fields, preferences | Central user profile and user-level state | Authentication, profile, onboarding, XP, rank, streak, achievements, search history, notifications |
| `users/{userId}/library` | `{bookId}` (external ID or UUID v4) | Metadata, `status`, `pageCount`, `currentPage`, `bestProgress`, dates, `progressHistory`, rating, shelf fields | Stores each user's books and reading activity | Library, reading progress, XP, quests, recommendations, statistics, reports |
| `users/{userId}/shelves` | `{shelfId}` (Firestore auto-ID) | `name`, `bookCount`, `createdAt` | Stores custom shelf definitions | Library organization |
| `users/{userId}/questClaims` | Daily/weekly deterministic `{claimKey}` | `questId`, `type`, `title`, `rewardXp`, `claimedAt` | Prevents duplicate quest claims and records awarded quest XP | Daily/weekly quests, XP, level/rank |
| `users/{userId}/custom_genres` | Uncertain | `name` | Supplies additional genre labels; read-only in current code | Library genre browsing |

## Feature-to-Storage Mapping

### Authentication and User Profile

- Firebase Authentication provides the UID and sign-in identity.
- `users/{userId}` stores profile details and initializes gamification state.
- No separate profile collection exists.

### Library Management

- Books are stored in `users/{userId}/library/{bookId}`.
- Shelf definitions are stored in `users/{userId}/shelves/{shelfId}`.
- Shelf membership is denormalized into library fields `onShelves` and `shelfAddedAt`.

### Reading Progress Tracking

- `currentPage`, `bestProgress`, `status`, `startedReading`, and `finishedReading` are stored on each library book.
- Reading sessions are appended to the `progressHistory` array.
- There is no separate reading-history collection.

### XP, Level, Rank, and Streak

- `totalXp`, `points`, `level`, `currentStreak`, `longestStreak`, `lastReadDate`, and `equippedRankBookIndex` are stored directly on the user document.
- Page and completion XP calculations use library progress fields.

### Daily and Weekly Quests

- Quest completion is calculated from user and library data.
- Only claims are persisted in `questClaims`.
- Quest definitions are hard-coded and not Firestore documents.

### Achievements and Badges

- Achievement definitions and thresholds are hard-coded in `StatsService`.
- Claimed IDs and badge selections are stored in `claimedAchievements`, `equippedBadge`, and `selectedBadges` on the user document.
- There is no `achievements` collection.

### Recommendation

- Recommendation preferences are calculated from `authors` and `categories` in the user's library.
- Recommended books are fetched live from external book services.
- No recommendations or API responses are persisted in a Firestore collection.

### Statistics and Reports

- Statistics and weekly/monthly/yearly reports are calculated on demand from library metadata and `progressHistory`.
- No statistics or reports collection exists.

### Notifications

- Reminder preference is stored in `dailyStreakReminderEnabled` and `dailyStreakReminderTime` on the user document.
- Notifications are scheduled locally on the device.
- No notification collection exists.

## Firestore Hierarchy Diagram

```text
users
`-- {userId}                         # Firebase Authentication UID
    |-- name
    |-- email
    |-- photoURL
    |-- totalXp
    |-- points
    |-- level
    |-- currentStreak
    |-- longestStreak
    |-- lastReadDate
    |-- booksRead
    |-- claimedAchievements[]
    |-- equippedBadge
    |-- selectedBadges[]
    |-- equippedRankBookIndex
    |-- recentSearches[]
    |-- dailyStreakReminderEnabled
    |-- dailyStreakReminderTime
    |-- hasSeenOnboarding
    |-- createdAt
    |
    |-- library
    |   `-- {bookId}                 # External book ID or UUID v4
    |       |-- title
    |       |-- authors
    |       |-- categories
    |       |-- description
    |       |-- publisher
    |       |-- publishedDate
    |       |-- thumbnail
    |       |-- industryIdentifiers[]
    |       |-- bookUrl
    |       |-- bookFormat
    |       |-- location
    |       |-- pageCount
    |       |-- currentPage
    |       |-- bestProgress
    |       |-- status
    |       |-- startedReading
    |       |-- finishedReading
    |       |-- rating
    |       |-- note
    |       |-- addedAt
    |       |-- onShelves[]
    |       |-- shelfAddedAt.{shelfId}
    |       `-- progressHistory[]    # Embedded array, not a subcollection
    |           |-- timestamp
    |           |-- pagesRead
    |           `-- dateKey
    |
    |-- shelves
    |   `-- {shelfId}                # Firestore auto-ID
    |       |-- name
    |       |-- bookCount
    |       `-- createdAt
    |
    |-- questClaims
    |   `-- {claimKey}               # daily_/weekly_ deterministic ID
    |       |-- questId
    |       |-- type
    |       |-- title
    |       |-- rewardXp
    |       `-- claimedAt
    |
    `-- custom_genres
        `-- {documentId}             # ID convention uncertain
            `-- name
```

## Uncertainties and Important Notes

1. `custom_genres` has a confirmed read path but no write path in the current project. Only its `name` field can be confirmed.
2. `authors` and `categories` are handled as either strings or lists because data can originate from different sources or older records.
3. `booksRead` is initialized on the user document, but current completed-book statistics are derived from library documents whose `status` is `Finished`.
4. `points` mirrors `totalXp`; current services generally treat `totalXp` as the primary value and retain `points` for compatibility.
5. `progressHistory` is an embedded array of maps, not a nested Firestore subcollection.
6. No `collectionGroup(...)` usage was found.
