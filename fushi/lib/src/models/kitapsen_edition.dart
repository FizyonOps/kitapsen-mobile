/// Kitapsen edition: the e-book reader build of Fushi that FizyonOps ships on
/// Google Play and the App Store.
///
/// Kitapsen users read the EPUB / PDF books they bought on kitapsen.com. Every
/// other Fushi capability (manga, video, games, dictionaries and lookup, Anki,
/// AI, browse / downloads, interconnect and cloud sync, floating ball, update
/// feeds, ...) stays in the source tree but is unreachable: the gates read
/// [kKitapsenEdition] instead of deleting code, so upstream merges stay
/// tractable and every Kitapsen-specific decision is greppable.
library;

/// Always `true` in this repository. A named constant rather than a bare
/// literal so each gate documents why it exists.
const bool kKitapsenEdition = true;

/// Legal / support links shown in Settings › System › About.
///
/// Store policy (Apple 3.1.1 / 3.1.3(a) reader apps, Google Play payments):
/// the app must not send users to buy books elsewhere, so it links only to
/// the privacy policy, the support address and the GPL source — never to the
/// kitapsen.com storefront or book pages, and it shows no prices.
const String kKitapsenPrivacyPolicyUrl = 'https://kitapsen.com/privacy';
const String kKitapsenSupportEmail = 'support@kitapsen.com';

/// GPLv3 corresponding source of this app (a fork of Fushi).
const String kKitapsenSourceUrl =
    'https://github.com/FizyonOps/kitapsen-mobile';

/// Upstream project Kitapsen is based on.
const String kFushiUpstreamUrl = 'https://github.com/hajisensai/Fushi';

/// iOS / Android store identity.
const String kKitapsenBundleId = 'com.fizyonops.kitapsen';
