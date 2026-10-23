import 'package:fushi/media.dart';
import 'package:fushi/pages.dart';

/// A default page for a [ReaderMediaSource]'s tab body content when selected
/// as a source in the main menu.
abstract class HistoryReaderPage extends BaseHistoryPage {
  /// Create an instance of this tab page.
  const HistoryReaderPage({
    super.key,
  });
}

/// A base class for providing all tabs in the main menu. In large part, this
/// was implemented to define shortcuts for common lengthy methods across UI
/// code.
abstract class HistoryReaderPageState<T extends BaseHistoryPage>
    extends BaseHistoryPageState {}
