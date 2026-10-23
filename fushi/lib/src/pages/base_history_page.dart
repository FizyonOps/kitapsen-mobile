import 'package:fushi/pages.dart';

/// A template for a single media type's history body content in the main menu
/// given a selected media source.
abstract class BaseHistoryPage extends BasePage {
  /// Create an instance of this tab page.
  const BaseHistoryPage({
    super.key,
  });

}

/// A base class for providing all tabs in the main menu. In large part, this
/// was implemented to define shortcuts for common lengthy methods across UI
/// code.
abstract class BaseHistoryPageState<T extends BaseHistoryPage>
    extends BasePageState<T> {

  /// Whether or not to allow edit and delete.
  bool get isHistory => true;

}
