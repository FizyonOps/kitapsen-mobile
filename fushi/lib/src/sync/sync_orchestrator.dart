

/// Tally of what one orchestrated run transferred. `errors` collects per-item
/// failures that were skipped without aborting the whole run. `conflicts`
/// collects items judged a genuine fork and skipped without auto-resolving —
/// they are neither failures nor transfers, so they never feed `booksImported`
/// nor `errors`.
abstract class SyncRunReport {

}
