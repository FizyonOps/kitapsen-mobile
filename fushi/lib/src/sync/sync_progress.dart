/// Progress reporting for a manual full sync ([SyncOrchestrator.run]).
///
/// A full sync runs as a sequence of phases (import remote books → per-book
/// reading data → dictionaries → local audio → audiobooks). A single global
/// percentage is dishonest because the per-phase totals aren't known until each
/// phase lists its remote side, so progress is reported PER PHASE: each phase
/// knows its item count up front, and large-file transfers blend their
/// byte-level fraction into the current item. This mirrors the determinate bar
/// the compare dialog already shows on Apply.
library;

/// One progress tick within a sync phase.
///
/// [itemIndex] is the number of items already completed in this phase (0-based
/// at the start of the current item), [itemTotal] the phase's item count.
/// [fileFraction] is the in-flight large-file transfer fraction (0..1) for the
/// current item, or null when the item is atomic (for example, small JSON).
abstract class SyncProgress {

}
