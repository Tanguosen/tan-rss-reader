// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TAN RSS';

  @override
  String get appTitleFull => 'TAN RSS Reader';

  @override
  String get navArticles => 'Articles';

  @override
  String get navChannels => 'Channels';

  @override
  String get navDiscovery => 'Discover';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get create => 'Create';

  @override
  String get retry => 'Retry';

  @override
  String get refresh => 'Refresh';

  @override
  String get back => 'Back';

  @override
  String get done => 'Done';

  @override
  String get remove => 'Remove';

  @override
  String get subscribe => 'Subscribe';

  @override
  String get unsubscribe => 'Unsubscribe';

  @override
  String get loadFailed => 'Load failed';

  @override
  String get operationFailed => 'Operation failed';

  @override
  String get createFailed => 'Create failed';

  @override
  String get updateFailed => 'Update failed';

  @override
  String get deleteFailed => 'Delete failed';

  @override
  String get saveFailed => 'Save failed';

  @override
  String get search => 'Search';

  @override
  String get all => 'All';

  @override
  String get noTitle => 'Untitled';

  @override
  String get noContent => 'No content';

  @override
  String get noDescription => 'No description';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get unknown => 'Unknown';

  @override
  String get settings => 'Settings';

  @override
  String get about => 'About';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutDescription =>
      'A modern AI-powered RSS reader with smart summaries, translations, and an elegant reading experience.';

  @override
  String get aboutSlogan =>
      'TAN is dedicated to bringing a refreshing and efficient reading experience to your information flow.';

  @override
  String get aboutCoreFeatures => 'Core Features';

  @override
  String get aboutCoreFeaturesDesc =>
      'RSS Subscribe · AI Summary · Smart Translation · Favorites';

  @override
  String get aboutTechStack => 'Tech Stack';

  @override
  String get aboutTechStackDesc =>
      'Flutter Frontend | Python FastAPI Backend | SQLite Database';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get username => 'Username';

  @override
  String get usernameHint => 'Enter username';

  @override
  String get usernameHelper =>
      'Only letters, numbers, underscores (_) and hyphens (-), at least 3 characters';

  @override
  String get password => 'Password';

  @override
  String get passwordHint => 'Enter password';

  @override
  String get passwordHelper => 'At least 6 characters';

  @override
  String get emailOptional => 'Email (optional)';

  @override
  String get emailHint => 'Enter email address';

  @override
  String get loginWelcome => 'Welcome back, please login';

  @override
  String get createNewAccount => 'Create new account';

  @override
  String get noAccount => 'No account? ';

  @override
  String get clickToRegister => 'Click to register';

  @override
  String get hasAccount => 'Already have an account? ';

  @override
  String get clickToLogin => 'Click to login';

  @override
  String get loginSuccess => 'Login successful';

  @override
  String get loginSuccessWelcome => 'Login successful, welcome back!';

  @override
  String get registerSuccess => 'Registration successful, welcome!';

  @override
  String get usernameRequired => 'Please enter username';

  @override
  String get usernameMinChars => 'Username must be at least 3 characters';

  @override
  String get usernameInvalidChars =>
      'Username can only contain letters, numbers, _ and -';

  @override
  String get emailFormatInvalid => 'Invalid email format';

  @override
  String get passwordRequired => 'Please enter password';

  @override
  String get passwordMinChars => 'Password must be at least 6 characters';

  @override
  String get passwordLengthError => 'Password must be at least 6 characters';

  @override
  String get serverAddress => 'Server Address';

  @override
  String get serverAddressHint => 'Enter server address';

  @override
  String get serverAddressMustHttp => 'Address must start with http or https';

  @override
  String get collapseConfig => 'Collapse config';

  @override
  String get serverConfig => 'Server config';

  @override
  String get myChannels => 'My Channels';

  @override
  String get noSubscribedChannels => 'No subscribed channels';

  @override
  String get goToChannelSquare => 'Browse channel square';

  @override
  String get starred => 'Favorites';

  @override
  String get noStarredArticles => 'No favorited articles yet';

  @override
  String get renameChannel => 'Rename Channel';

  @override
  String get newName => 'New name';

  @override
  String get deleteChannel => 'Delete Channel';

  @override
  String get deleteChannelConfirm =>
      'Delete this channel? Only the channel and subscription relationship will be removed, not the feeds.';

  @override
  String get addFeedToChannel => 'Add Feed to Channel';

  @override
  String get rssAtomUrl => 'RSS/Atom URL';

  @override
  String get titleOptional => 'Title (optional)';

  @override
  String get createNewFeed => 'New Feed';

  @override
  String get url => 'URL';

  @override
  String get editFeed => 'Edit Feed';

  @override
  String get title => 'Title';

  @override
  String get updateIntervalMinutes => 'Update interval (minutes)';

  @override
  String get defaultInterval => 'Default (15 min)';

  @override
  String get minutes5 => '5 minutes';

  @override
  String get minutes10 => '10 minutes';

  @override
  String get minutes15 => '15 minutes';

  @override
  String get minutes30 => '30 minutes';

  @override
  String get hour1 => '1 hour';

  @override
  String get hours2 => '2 hours';

  @override
  String get hours6 => '6 hours';

  @override
  String get hours12 => '12 hours';

  @override
  String get hours24 => '24 hours';

  @override
  String unsubscribeConfirm(Object title) {
    return 'Unsubscribe from \"$title\"?\nYou will no longer receive updates from this feed.';
  }

  @override
  String get thinkAgain => 'Think again';

  @override
  String get confirmUnsubscribe => 'Confirm unsubscribe';

  @override
  String get unsubscribed => 'Unsubscribed';

  @override
  String get allUnread => 'All unread';

  @override
  String unreadCount(Object count) {
    return '$count unread';
  }

  @override
  String get addFeedHere => 'Add feed to this channel';

  @override
  String get renameChannelMenu => 'Rename channel';

  @override
  String get deleteChannelMenu => 'Delete channel';

  @override
  String get noFeedsClickToAdd => 'No feeds, click + to add';

  @override
  String get addSubscriptionSource => 'Add Feed';

  @override
  String get subscriptionLink => 'Feed Link';

  @override
  String get subscriptionLinkHint => 'https://example.com/feed.xml';

  @override
  String get paste => 'Paste';

  @override
  String get enterSubscriptionLink => 'Please enter feed link';

  @override
  String get linkMustHttp => 'Link must start with http:// or https://';

  @override
  String get addingContent => 'Adding and fetching content...';

  @override
  String get addSubscriptionSourceButton => 'Add Feed';

  @override
  String get supportedSources => 'Supported sources';

  @override
  String get blogWebsite => 'Blog / Website';

  @override
  String get other => 'Other';

  @override
  String get quickAddExamples => 'Quick add examples';

  @override
  String get subscriptionAddedSuccess => 'Feed added successfully';

  @override
  String get fetchingInBackground => 'Fetching latest content in background...';

  @override
  String get reading => 'Read';

  @override
  String get aiSummary => 'AI Summary';

  @override
  String get translateTitleButton => 'Translate Title';

  @override
  String get translateContent => 'Translate Content';

  @override
  String get deepDive => 'Deep Dive';

  @override
  String get showTranslatedTitle => 'Show translated title';

  @override
  String get showTranslatedContent => 'Show translated content';

  @override
  String get aiDeepDive => 'AI Deep Dive';

  @override
  String get aiSummaryFailed => 'AI summary failed: ';

  @override
  String get titleTranslationFailed => 'Title translation failed: ';

  @override
  String get contentTranslationFailed => 'Content translation failed: ';

  @override
  String get deepDiveFailed => 'AI deep dive failed: ';

  @override
  String get markRead => 'Mark read';

  @override
  String get markUnread => 'Mark unread';

  @override
  String get star => 'Favorite';

  @override
  String get unstar => 'Unfavorite';

  @override
  String get addToBatch => 'Add to batch';

  @override
  String get translateTitle => 'Translate title';

  @override
  String get articlesSection => 'Articles';

  @override
  String get batchOperation => 'Batch';

  @override
  String get unread => 'Unread';

  @override
  String get highQuality => 'Quality';

  @override
  String get starredFilter => 'Favorites';

  @override
  String selectedCount(Object count) {
    return '$count selected';
  }

  @override
  String get batchStar => 'Batch favorite';

  @override
  String get batchUnstar => 'Batch unfavorite';

  @override
  String get deselect => 'Deselect';

  @override
  String get noArticlesMatch => 'No articles match current filters';

  @override
  String get aiBriefing => 'AI Briefing';

  @override
  String get noArticlesForBriefing => 'No articles available for briefing';

  @override
  String get trendsTab => 'Trends';

  @override
  String get semanticSearchTab => 'Semantic Search';

  @override
  String get majorEvents => 'Major Events';

  @override
  String get sourceHighlights => 'Source Highlights';

  @override
  String get deepAnalysis => 'Deep Analysis';

  @override
  String get integratedToDailyBriefing => 'Integrated into daily briefing';

  @override
  String get aiDailyBriefing => 'AI Daily Briefing';

  @override
  String get dailyBriefingDesc => 'Read highlights from all channels';

  @override
  String get noUnreadForBriefing => 'No unread articles for briefing';

  @override
  String get getArticlesFailed => 'Failed to get articles';

  @override
  String get timeRange => 'Time range: ';

  @override
  String get last24Hours => 'Last 24 hours';

  @override
  String get last3Days => 'Last 3 days';

  @override
  String get lastWeek => 'Last week';

  @override
  String get last1Month => 'Last month';

  @override
  String get last3Months => 'Last 3 months';

  @override
  String get noTrendTopics => 'No trending topics found';

  @override
  String articleCount(Object count) {
    return '$count articles';
  }

  @override
  String moreArticles(Object count) {
    return '+ $count more';
  }

  @override
  String get smartAnalysis => 'Smart Analysis';

  @override
  String get searchHint => 'Enter question or keyword...';

  @override
  String get searchFailed => 'Search failed';

  @override
  String get noResults => 'No results found';

  @override
  String get inputKeywordsToSearch => 'Enter keywords to search';

  @override
  String get publishTime => 'Published: ';

  @override
  String get openArticleFailed => 'Failed to open article';

  @override
  String get generatingAnalysis => 'Generating smart analysis report...';

  @override
  String get analysisFailed => 'Analysis failed';

  @override
  String get noAnalysisData => 'No analysis data';

  @override
  String get smartTrendAnalysis => 'Smart Trend Analysis';

  @override
  String get trendPrediction => 'Trend Prediction';

  @override
  String get keywords => 'Keywords:';

  @override
  String get sentiment => 'Sentiment:';

  @override
  String get sentimentPositive => 'Positive';

  @override
  String get sentimentNegative => 'Negative';

  @override
  String get sentimentNeutral => 'Neutral';

  @override
  String get summary => 'Summary';

  @override
  String get eventTimeline => 'Event Timeline';

  @override
  String get channelSquare => 'Channel Square';

  @override
  String get searchChannels => 'Search channels';

  @override
  String get discover => 'Discover';

  @override
  String get mySubscriptions => 'My Subscriptions';

  @override
  String get curatedPacks => 'Curated Packs';

  @override
  String get noChannelsFound => 'No channels found';

  @override
  String get noSubscriptions => 'No subscriptions';

  @override
  String get subscribed => 'Subscribed';

  @override
  String subscribedSuccess(Object name) {
    return 'Subscribed to $name';
  }

  @override
  String get subscribeFailed => 'Subscribe failed';

  @override
  String get unsubscribeChannel => 'Unsubscribe';

  @override
  String unsubscribeChannelConfirm(Object name) {
    return 'Unsubscribe from \"$name\"?';
  }

  @override
  String unsubscribedSuccess(Object name) {
    return 'Unsubscribed from $name';
  }

  @override
  String get unsubscribeFailed => 'Unsubscribe failed';

  @override
  String get noPacks => 'No packs';

  @override
  String get clickToCreatePack => 'Create your own channel collection';

  @override
  String get oneClickSubscribe => 'One-click subscribe';

  @override
  String channelCount(Object count) {
    return '$count channels';
  }

  @override
  String installCount(Object count) {
    return '$count installs';
  }

  @override
  String get includedChannels => 'Included channels:';

  @override
  String moreChannels(Object count) {
    return 'and $count more';
  }

  @override
  String installedPack(Object added, Object name) {
    return 'Installed \"$name\", added $added channel subscriptions';
  }

  @override
  String skippedChannels(Object skipped) {
    return ', skipped $skipped already subscribed';
  }

  @override
  String get installFailed => 'Install failed';

  @override
  String get createPack => 'Create Pack';

  @override
  String get packNameRequired => 'Pack name *';

  @override
  String get packNameHint => 'e.g.: AI News Collection';

  @override
  String get packDesc => 'Description (optional)';

  @override
  String get includedChannelsSection => 'Included channels';

  @override
  String get addChannels => 'Add';

  @override
  String get noChannelsSelected => 'No channels selected';

  @override
  String get selectChannels => 'Select channels to include';

  @override
  String get noSubscribedChannelsForPack =>
      'No subscribed channels, subscribe to some first';

  @override
  String get packNameRequiredMsg => 'Please enter pack name';

  @override
  String get selectAtLeastOneChannel => 'Please select at least one channel';

  @override
  String get createSuccess => 'Created successfully';

  @override
  String get noArticlesForAnalysis => 'No articles for analysis';

  @override
  String get channelLinkCopied => 'Channel link copied';

  @override
  String get getLatestContent => 'Get latest content';

  @override
  String get markAllAsRead => 'Mark all as read';

  @override
  String get viewSources => 'View sources';

  @override
  String get shareChannel => 'Share channel';

  @override
  String get noArticles => 'No articles';

  @override
  String newContentCount(Object count) {
    return 'Got $count new items';
  }

  @override
  String get alreadyLatest => 'Already up to date';

  @override
  String get refreshFailed => 'Refresh failed';

  @override
  String markedReadCount(Object count) {
    return 'Marked $count articles as read';
  }

  @override
  String get noUnreadArticles => 'No unread articles';

  @override
  String submittedBy(Object author) {
    return 'submitted by $author';
  }

  @override
  String get getLatestContentButton => 'Get latest content';

  @override
  String get channelManagement => 'Channel Management';

  @override
  String get noChannels => 'No channels';

  @override
  String get clickPlusToCreateChannel => 'Click + to create a new channel';

  @override
  String get createChannel => 'Create Channel';

  @override
  String get channelName => 'Channel name';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get channelCreated => 'Channel created';

  @override
  String get editChannel => 'Edit Channel';

  @override
  String get iconUrlOptional => 'Icon URL (optional)';

  @override
  String get coverUrlOptional => 'Cover URL (optional)';

  @override
  String get categoryOptional => 'Category (optional)';

  @override
  String get noCategory => 'No category';

  @override
  String get publicChannel => 'Public channel';

  @override
  String get publicChannelVisible => 'Visible to all users';

  @override
  String get privateChannelVisible => 'Visible only to you';

  @override
  String get channelUpdated => 'Channel updated';

  @override
  String deleteChannelConfirmAdmin(Object name) {
    return 'Delete channel \"$name\"?';
  }

  @override
  String get channelDeleted => 'Channel deleted';

  @override
  String get manageSources => 'Manage sources';

  @override
  String channelSources(Object channelName) {
    return '$channelName - Sources';
  }

  @override
  String get noSources => 'No sources';

  @override
  String get clickPlusToAddSource => 'Click + to add sources';

  @override
  String get noUserFeeds => 'You haven\'t subscribed to any feeds yet';

  @override
  String get allFeedsAdded => 'All feeds already added to this channel';

  @override
  String get addSource => 'Add source';

  @override
  String get sourceAdded => 'Source added';

  @override
  String get addFailed => 'Add failed';

  @override
  String get removeSource => 'Remove source';

  @override
  String removeSourceConfirm(Object name) {
    return 'Remove \"$name\" from channel?';
  }

  @override
  String get sourceRemoved => 'Source removed';

  @override
  String get removeFailed => 'Remove failed';

  @override
  String get platformAdmin => 'Platform Admin';

  @override
  String get myChannelsAdmin => 'My Channels';

  @override
  String get channelsTab => 'Channels';

  @override
  String get feedsTab => 'Feeds';

  @override
  String get noChannelAdmin => 'No channels';

  @override
  String get clickToCreateFirstChannel =>
      'Click below to create your first channel';

  @override
  String get noPersonalChannels => 'No personal channels';

  @override
  String get platformChannels => 'Platform channels';

  @override
  String get personalChannels => 'Personal channels';

  @override
  String get createChannelAdmin => 'Create channel';

  @override
  String get publicChannelOtherUsers =>
      'Discoverable and subscribable by others';

  @override
  String get privateChannelSelf => 'Visible only to you';

  @override
  String get deleteChannelAdmin => 'Delete channel';

  @override
  String deleteChannelAdminConfirm(Object name) {
    return 'Delete \"$name\"? This won\'t delete its feeds.';
  }

  @override
  String get channelDeletedAdmin => 'Channel deleted';

  @override
  String get noSourcesAdmin => 'No sources, click + to add';

  @override
  String sourcesCount(Object count) {
    return '$count sources';
  }

  @override
  String get addSourceAdmin => 'Add source';

  @override
  String get sourceAddedAdmin => 'Source added';

  @override
  String get addFailedAdmin => 'Add failed';

  @override
  String get removeSourceAdmin => 'Remove source';

  @override
  String removeSourceAdminConfirm(Object name) {
    return 'Remove \"$name\"?';
  }

  @override
  String get removeFailedAdmin => 'Remove failed';

  @override
  String get noFeedsAdmin => 'No feeds';

  @override
  String get addFeedAdmin => 'Add feed';

  @override
  String get deleteFeed => 'Delete feed';

  @override
  String deleteFeedConfirm(Object title) {
    return 'Delete feed \"$title\"?';
  }

  @override
  String get feedDeleted => 'Deleted';

  @override
  String get deleteFeedFailed => 'Delete failed';

  @override
  String get addButton => 'Add feed';

  @override
  String get changelog => 'Changelog';

  @override
  String get changelogSubtitle => 'See latest improvements';

  @override
  String get membershipCenter => 'Membership';

  @override
  String get membershipSubtitle => 'Unlock premium AI features';

  @override
  String get account => 'Account';

  @override
  String get accountSubtitle => 'Local, cloud sync';

  @override
  String get colorAndStyle => 'Colors & Style';

  @override
  String get colorAndStyleSubtitle => 'Theme, article style';

  @override
  String get interaction => 'Interaction';

  @override
  String get interactionSubtitle => 'Gestures, startup page';

  @override
  String get language => 'Language';

  @override
  String get languageSubtitle => 'UI, AI, translation';

  @override
  String get aiFeatures => 'AI Features';

  @override
  String get aiFeaturesSubtitle => 'AI provider, AI prompts';

  @override
  String get highlightSettings => 'Highlights';

  @override
  String get highlightSubtitle => 'Manage keyword highlights';

  @override
  String get ttsSettings => 'TTS Settings';

  @override
  String get ttsSubtitle => 'Voice, language settings';

  @override
  String get syncSettings => 'Sync Settings';

  @override
  String get syncSubtitle => 'Auto refresh, API config';

  @override
  String get importExport => 'Import/Export';

  @override
  String get importExportSubtitle => 'Feeds, app settings';

  @override
  String get platformAdminCenter => 'Platform Admin';

  @override
  String get platformAdminSubtitle => 'Global channels, groups, sources';

  @override
  String get userManagement => 'User Management';

  @override
  String get userManagementSubtitle => 'Manage permissions and membership';

  @override
  String get aboutSubtitle => 'App info, version';

  @override
  String get articleDisplayMode => 'Article display mode';

  @override
  String get listView => 'List';

  @override
  String get listViewDesc => 'Simple list with title and source info';

  @override
  String get magazineView => 'Magazine';

  @override
  String get magazineViewDesc => 'Rich layout with content preview';

  @override
  String get cardView => 'Card';

  @override
  String get cardViewDesc => 'Image-based card layout';

  @override
  String get themeMode => 'Theme mode';

  @override
  String get followSystem => 'Follow system';

  @override
  String get followSystemDesc =>
      'Automatically switch based on system settings';

  @override
  String get lightMode => 'Light mode';

  @override
  String get lightModeDesc => 'Use light theme';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get darkModeDesc => 'Use dark theme';

  @override
  String get amoledBlack => 'AMOLED pure black';

  @override
  String get themeColor => 'Theme color';

  @override
  String get colorSchemeStyleTitle => 'Color scheme style';

  @override
  String get tonalSpot => 'Tonal spot';

  @override
  String get tonalSpotDesc => 'Default soft palette, low saturation';

  @override
  String get fidelity => 'Fidelity';

  @override
  String get fidelityDesc => 'Match theme color even if bright';

  @override
  String get neutral => 'Neutral';

  @override
  String get neutralDesc => 'Near grayscale with a hint of color';

  @override
  String get gestureOperations => 'Gesture operations';

  @override
  String get hapticFeedback => 'Haptic feedback';

  @override
  String get hapticFeedbackDesc => 'Vibration feedback on tap and swipe';

  @override
  String get immersiveReading => 'Immersive reading';

  @override
  String get immersiveReadingDesc => 'Auto-hide toolbar when reading';

  @override
  String get swipeToChange => 'Swipe to change article';

  @override
  String get swipeToChangeDesc => 'Swipe left/right to switch articles';

  @override
  String get scrollMarkRead => 'Scroll to mark read';

  @override
  String get scrollMarkReadDesc =>
      'Auto-mark visible articles as read when scrolling';

  @override
  String get lazyLoadDetails => 'Lazy load details';

  @override
  String get lazyLoadDetailsDesc =>
      'Improve performance on some devices, may cause scroll jumping';

  @override
  String get useExternalBrowser => 'Use external browser';

  @override
  String get useExternalBrowserDesc =>
      'Open links in external browser instead of in-app';

  @override
  String get fabPosition => 'Mark-read FAB position';

  @override
  String get fabPositionDesc => 'Choose position of the mark-as-read button';

  @override
  String get fabHidden => 'Hidden';

  @override
  String get pageSize => 'Articles per page';

  @override
  String get pageSizeDesc =>
      'Number of articles loaded each time. Also affects AI aggregation.';

  @override
  String get startupPage => 'Startup page';

  @override
  String get startupPageDesc => 'Choose which page to show on launch';

  @override
  String get languageSettings => 'Language Settings';

  @override
  String get appLanguage => 'App language';

  @override
  String get appLanguageDesc => 'Language for the app interface';

  @override
  String get followSystemLang => 'Follow system';

  @override
  String get aiGeneratedLanguage => 'AI generation language';

  @override
  String get aiGeneratedLanguageDesc =>
      'Language for AI-generated content (summaries, etc.)';

  @override
  String get followAppLang => 'Follow app language';

  @override
  String get translationLanguage => 'Translation language';

  @override
  String get translationLanguageDesc =>
      'Target language for article translation';

  @override
  String get languageSupportNote =>
      'Language support depends on AI model and translation engine capabilities';

  @override
  String get syncSettingsTitle => 'Sync Settings';

  @override
  String get localConnectionConfig => 'Local connection config';

  @override
  String get backendApiUrl => 'Backend API Base URL';

  @override
  String get apiUrlHint => 'http://192.168.1.1:8080';

  @override
  String get serverBackgroundConfig => 'Server background config (global)';

  @override
  String get autoRefreshInterval => 'Auto refresh interval (minutes)';

  @override
  String get minutes => ' minutes';

  @override
  String get rsshubInstanceUrl => 'RSSHub instance URL';

  @override
  String get opmlImportExport => 'Import/Export';

  @override
  String get opmlImport => 'OPML Import';

  @override
  String get opmlImportDesc =>
      'Import feeds from other RSS readers. Supports .opml or .xml files.';

  @override
  String get importing => 'Importing...';

  @override
  String get selectFileAndImport => 'Select file and import';

  @override
  String get opmlExport => 'OPML Export';

  @override
  String get opmlExportDesc =>
      'Export current feeds as OPML format for use in other readers.';

  @override
  String get exporting => 'Exporting...';

  @override
  String get exportAndShare => 'Export and share';

  @override
  String get importResult => 'Import result';

  @override
  String importResultDetail(Object errors, Object imported, Object skipped) {
    return 'Imported: $imported\nSkipped: $skipped\nErrors: $errors';
  }

  @override
  String get importFailed => 'Import failed';

  @override
  String get exportShareTitle => 'TAN RSS Feed Export';

  @override
  String get exportFailed => 'Export failed';

  @override
  String get aiSettingsTitle => 'AI Features';

  @override
  String get aiProvider => 'AI Provider';

  @override
  String providerConfig(Object provider) {
    return '$provider Config';
  }

  @override
  String get apiKey => 'API Key';

  @override
  String get apiKeyHint => 'Enter API key';

  @override
  String get baseUrlOptional => 'Base URL (optional)';

  @override
  String get modelOptional => 'Model (optional)';

  @override
  String getApiKey(Object provider) {
    return 'Get $provider API key';
  }

  @override
  String get aiInstructionManagement => 'AI Instruction Management';

  @override
  String get articleAggregationPrompts => 'Article aggregation prompts';

  @override
  String get addCustomInstruction => 'Add custom instruction';

  @override
  String get editCustomInstruction => 'Edit custom instruction';

  @override
  String get promptName => 'Name';

  @override
  String get promptType => 'Type (summary or synthesis)';

  @override
  String get promptContent => 'Instruction content';

  @override
  String get deletePromptConfirm => 'Confirm delete';

  @override
  String get deletePromptContent => 'Delete this custom instruction?';

  @override
  String get tips => 'Tips';

  @override
  String tip1(Object content, Object title) {
    return 'Use $title and $content placeholders to reference article info';
  }

  @override
  String tip2(Object language) {
    return 'Use $language placeholder to reference AI generation language';
  }

  @override
  String get tip3 => 'API keys are securely stored on your local device';

  @override
  String get tip4 =>
      'You can configure custom models and endpoints for advanced use';

  @override
  String get advancedFeatures => 'Advanced features';

  @override
  String get autoQualityScoring => 'Auto quality scoring';

  @override
  String get autoQualityScoringDesc =>
      'Use AI to evaluate article quality and filter low-quality content';

  @override
  String get autoSummary => 'Auto summary';

  @override
  String get autoSummaryDesc => 'Auto-generate AI summaries for new articles';

  @override
  String get autoTitleTranslation => 'Auto translate titles';

  @override
  String get autoTitleTranslationDesc =>
      'Auto-translate foreign language titles';

  @override
  String get autoContentTranslation => 'Auto translate content';

  @override
  String get autoContentTranslationDesc => 'Auto-translate unread articles';

  @override
  String get saveSuccess => 'Saved successfully';

  @override
  String get testing => 'Testing...';

  @override
  String get testSuccess => 'Test successful!';

  @override
  String get testFailed => 'Test failed, please check config.';

  @override
  String get upgrade => 'Upgrade';

  @override
  String get freeMemberAiHint =>
      'Free members need their own API key for AI features. Upgrade Plus for ready-to-use AI!';

  @override
  String plusMemberHint(Object count) {
    return 'You have platform AI service privileges. Used today: $count times.';
  }

  @override
  String get membershipTitle => 'Membership';

  @override
  String upgradeSuccess(Object tier) {
    return 'Successfully upgraded to $tier!';
  }

  @override
  String get upgradeFailed => 'Upgrade failed';

  @override
  String currentLevel(Object tier) {
    return 'Current tier: $tier';
  }

  @override
  String expirationTime(Object time) {
    return 'Expires: $time';
  }

  @override
  String todayAiCalls(Object count) {
    return 'Platform AI calls today: $count';
  }

  @override
  String get subscriptionPlans => 'Subscription Plans';

  @override
  String get freePlan => 'Free';

  @override
  String get freePrice => 'Free';

  @override
  String get freeFeature1 => 'Basic RSS subscription management';

  @override
  String get freeFeature2 => 'Custom AI model support (bring your own key)';

  @override
  String get freeFeature3 => 'Community plugins and curated packs';

  @override
  String get currentPlan => 'Current plan';

  @override
  String get downgrade => 'Downgrade';

  @override
  String get plusPlan => 'Plus';

  @override
  String get plusPrice => '¥15 / month';

  @override
  String get plusFeature1 => 'All Free features';

  @override
  String get plusFeature2 => 'Ready-to-use platform AI models';

  @override
  String get plusFeature3 => '50 daily platform AI calls';

  @override
  String get plusFeature4 => 'Custom AI instruction management';

  @override
  String get upgradeNow => 'Upgrade now';

  @override
  String get proPlan => 'Pro';

  @override
  String get proPrice => '¥45 / month';

  @override
  String get proFeature1 => 'All Plus features';

  @override
  String get proFeature2 => '500 daily premium AI calls';

  @override
  String get proFeature3 => 'Advanced theme customization (coming soon)';

  @override
  String get proFeature4 => 'Priority customer support';

  @override
  String get currentBadge => 'Current';

  @override
  String get accountManagement => 'Account Management';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleUser => 'User';

  @override
  String get email => 'Email';

  @override
  String get emailNotSet => 'Not set';

  @override
  String get registrationTime => 'Registered';

  @override
  String get accountStatus => 'Account status';

  @override
  String get statusActive => 'Active';

  @override
  String get statusDisabled => 'Disabled';

  @override
  String get accountOperations => 'Account operations';

  @override
  String get changeEmail => 'Change email';

  @override
  String get newEmailLabel => 'New email address';

  @override
  String get newEmailHint => 'Enter new email address';

  @override
  String get emailEmpty => 'Email cannot be empty';

  @override
  String get emailUpdateSuccess => 'Email updated successfully';

  @override
  String get changePassword => 'Change password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get currentPasswordHint => 'Enter current password';

  @override
  String get newPassword => 'New password';

  @override
  String get newPasswordHint => 'At least 6 characters';

  @override
  String get confirmNewPassword => 'Confirm new password';

  @override
  String get confirmNewPasswordHint => 'Enter new password again';

  @override
  String get fillAllPasswordFields => 'Please fill all password fields';

  @override
  String get newPasswordMinChars =>
      'New password must be at least 6 characters';

  @override
  String get passwordsMismatch => 'Passwords don\'t match';

  @override
  String get passwordUpdateSuccess => 'Password updated successfully';

  @override
  String get logoutConfirm => 'Confirm logout';

  @override
  String get logoutConfirmContent => 'Are you sure you want to log out?';

  @override
  String get logout => 'Logout';

  @override
  String get logoutButton => 'Logout';

  @override
  String get changeEmailAction => 'Change email';

  @override
  String get changePasswordAction => 'Change password';

  @override
  String get changePasswordSubtitle =>
      'Regular password changes improve security';

  @override
  String get dailyDigestTitle => 'AI Daily Briefing';

  @override
  String get regenerate => 'Regenerate';

  @override
  String get readingAllUnread =>
      'Reading all unread articles...\nAI editor is writing your daily briefing';

  @override
  String get generationFailed => 'Generation failed';

  @override
  String get noArticlesForDigest => 'No latest articles for briefing';

  @override
  String referenceSource(Object index) {
    return 'Source [$index]';
  }

  @override
  String get readOriginal => 'Read original';

  @override
  String get aiSynthesis => 'AI Synthesis';

  @override
  String get ttsComingSoon => 'TTS reading coming soon';

  @override
  String readingChannelArticles(Object channelName) {
    return 'Reading $channelName recent articles...\nAI is generating your synthesis report';
  }

  @override
  String get synthesisFailed => 'Generation failed';

  @override
  String get noArticlesToAnalyze => 'No articles to analyze';

  @override
  String reference(Object index) {
    return 'Reference [$index]';
  }

  @override
  String get userManagementTitle => 'User Management';

  @override
  String get noUsers => 'No users';

  @override
  String get editUser => 'Edit user';

  @override
  String get role => 'Role';

  @override
  String get membershipTier => 'Membership tier';

  @override
  String get isActive => 'Status';

  @override
  String get active => 'Active';

  @override
  String get disabled => 'Disabled';

  @override
  String get userUpdated => 'User updated';

  @override
  String get updateUserFailed => 'Failed to update user';

  @override
  String get deleteUser => 'Delete user';

  @override
  String deleteUserConfirm(Object name) {
    return 'Delete user \"$name\"?';
  }

  @override
  String get userDeleted => 'User deleted';

  @override
  String get deleteUserFailed => 'Failed to delete user';

  @override
  String get healthCheck => 'Server status check';

  @override
  String get serverOnline => 'Server connected';

  @override
  String get serverOffline => 'Cannot connect to server';

  @override
  String get checkNow => 'Check now';

  @override
  String get dateFormatYear => 'y';

  @override
  String get dateFormatMonth => 'm';

  @override
  String get dateFormatDay => 'd';

  @override
  String readCount(Object count) {
    return '$count articles';
  }

  @override
  String get defaultValue => 'Default';
}
