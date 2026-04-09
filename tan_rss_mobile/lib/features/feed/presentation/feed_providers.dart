import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/models.dart';
import '../data/feed_repository.dart';

class HomeTabNotifier extends Notifier<int> {
  @override
  int build() {
    _loadInitialTab();
    return 0; // Default before load
  }

  Future<void> _loadInitialTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTab = prefs.getInt('default_startup_tab') ?? 0;
      if (savedTab >= 0 && savedTab <= 2) {
        state = savedTab;
      }
    } catch (_) {}
  }

  void change(int index) {
    if (index < 0 || index > 2) {
      state = 0;
      return;
    }
    state = index;
  }
}

class SelectedFeedNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? feedId) {
    state = feedId;
  }
}

class UnreadOnlyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }

  void setValue(bool value) {
    state = value;
  }
}

class HighQualityOnlyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }

  void setValue(bool value) {
    state = value;
  }
}

class StarredOnlyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }

  void setValue(bool value) {
    state = value;
  }
}

class InteractionSettings {
  final bool hapticFeedback;
  final bool immersiveReading;
  final bool swipeToChange;
  final bool scrollMarkRead;
  final bool lazyLoadDetails;
  final bool useExternalBrowser;
  final String fabPosition;
  final int pageSize;

  InteractionSettings({
    this.hapticFeedback = true,
    this.immersiveReading = false,
    this.swipeToChange = true,
    this.scrollMarkRead = false,
    this.lazyLoadDetails = false,
    this.useExternalBrowser = false,
    this.fabPosition = 'Right',
    this.pageSize = 50,
  });
}

class InteractionSettingsNotifier extends Notifier<InteractionSettings> {
  @override
  InteractionSettings build() {
    _load();
    return InteractionSettings(); // Default until loaded
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = InteractionSettings(
      hapticFeedback: prefs.getBool('interaction_haptic_feedback') ?? true,
      immersiveReading: prefs.getBool('interaction_immersive_reading') ?? false,
      swipeToChange: prefs.getBool('interaction_swipe_to_change') ?? true,
      scrollMarkRead: prefs.getBool('interaction_scroll_mark_read') ?? false,
      lazyLoadDetails: prefs.getBool('interaction_lazy_load_details') ?? false,
      useExternalBrowser:
          prefs.getBool('interaction_use_external_browser') ?? false,
      fabPosition: prefs.getString('interaction_fab_position') ?? 'Right',
      pageSize: prefs.getInt('interaction_page_size') ?? 50,
    );
  }

  void reload() {
    _load();
  }
}

class AppearanceSettings {
  final String viewMode; // list, magazine, card
  final String themeMode; // system, light, dark
  final bool amoledBlack;
  final String themeColor; // dynamic, blue, indigo, etc.
  final String colorSchemeStyle; // tonal_spot, fidelity, neutral

  AppearanceSettings({
    this.viewMode = 'magazine',
    this.themeMode = 'system',
    this.amoledBlack = false,
    this.themeColor = 'dynamic',
    this.colorSchemeStyle = 'tonal_spot',
  });
}

class AppearanceSettingsNotifier extends Notifier<AppearanceSettings> {
  @override
  AppearanceSettings build() {
    _load();
    return AppearanceSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppearanceSettings(
      viewMode: prefs.getString('appearance_view_mode') ?? 'magazine',
      themeMode: prefs.getString('appearance_theme_mode') ?? 'system',
      amoledBlack: prefs.getBool('appearance_amoled_black') ?? false,
      themeColor: prefs.getString('appearance_theme_color') ?? 'dynamic',
      colorSchemeStyle:
          prefs.getString('appearance_color_scheme_style') ?? 'tonal_spot',
    );
  }

  void reload() {
    _load();
  }
}

final homeTabProvider = NotifierProvider<HomeTabNotifier, int>(
  HomeTabNotifier.new,
);
final selectedFeedIdProvider = NotifierProvider<SelectedFeedNotifier, String?>(
  SelectedFeedNotifier.new,
);
final unreadOnlyProvider = NotifierProvider<UnreadOnlyNotifier, bool>(
  UnreadOnlyNotifier.new,
);
final highQualityOnlyProvider = NotifierProvider<HighQualityOnlyNotifier, bool>(
  HighQualityOnlyNotifier.new,
);
final starredOnlyProvider = NotifierProvider<StarredOnlyNotifier, bool>(
  StarredOnlyNotifier.new,
);
final interactionSettingsProvider =
    NotifierProvider<InteractionSettingsNotifier, InteractionSettings>(
      InteractionSettingsNotifier.new,
    );
final appearanceSettingsProvider =
    NotifierProvider<AppearanceSettingsNotifier, AppearanceSettings>(
      AppearanceSettingsNotifier.new,
    );

final feedsProvider = FutureProvider<List<Feed>>((ref) async {
  final repository = ref.watch(feedRepositoryProvider);
  return repository.getFeeds();
});

final aiConfigProvider = FutureProvider<AIConfig>((ref) async {
  final repository = ref.watch(feedRepositoryProvider);
  return repository.getAIConfig();
});

final adminChannelsProvider = FutureProvider<List<Channel>>((ref) async {
  final repository = ref.watch(feedRepositoryProvider);
  return repository.getAdminChannels();
});

final entriesProvider = FutureProvider<List<Entry>>((ref) async {
  final repository = ref.watch(feedRepositoryProvider);
  final selectedFeedId = ref.watch(selectedFeedIdProvider);
  final unreadOnly = ref.watch(unreadOnlyProvider);
  final highQualityOnly = ref.watch(highQualityOnlyProvider);
  final starredOnly = ref.watch(starredOnlyProvider);
  final settings = ref.watch(interactionSettingsProvider);
  final query = EntryQuery(
    feedId: selectedFeedId,
    unreadOnly: unreadOnly,
    highQualityOnly: highQualityOnly,
    starredOnly: starredOnly,
    orderBy: 'published_at',
    limit: settings.pageSize,
  );
  return repository.getEntriesByQuery(query);
});

final starredEntriesProvider = FutureProvider<List<Entry>>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isLoggedIn) {
    return <Entry>[];
  }
  final repository = ref.watch(feedRepositoryProvider);
  final settings = ref.watch(interactionSettingsProvider);
  return repository.getStarredEntries(limit: settings.pageSize, offset: 0);
});

final readingHistoryProvider = FutureProvider<List<ReadingHistoryItem>>((
  ref,
) async {
  final authState = ref.watch(authProvider);
  if (!authState.isLoggedIn) {
    return <ReadingHistoryItem>[];
  }
  final repository = ref.watch(feedRepositoryProvider);
  return repository.getReadingHistory(limit: 30);
});

final recommendedTopicsProvider = FutureProvider<List<RecommendedTopic>>((
  ref,
) async {
  final authState = ref.watch(authProvider);
  if (!authState.isLoggedIn) {
    return <RecommendedTopic>[];
  }
  final repository = ref.watch(feedRepositoryProvider);
  return repository.getRecommendedTopics(limit: 6);
});

final channelSquareProvider = FutureProvider<List<Channel>>((ref) async {
  final repository = ref.watch(feedRepositoryProvider);
  return repository.getSquareChannels();
});

final publicCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repository = ref.watch(feedRepositoryProvider);
  return repository.getPublicCategories();
});

final mySubscriptionsProvider = FutureProvider<List<Channel>>((ref) async {
  final repository = ref.watch(feedRepositoryProvider);
  return repository.getMySubscriptions();
});

final publicPacksProvider = FutureProvider<List<SourcePack>>((ref) async {
  final repository = ref.watch(feedRepositoryProvider);
  return repository.getPublicPacks();
});

final myPacksProvider = FutureProvider<List<SourcePack>>((ref) async {
  final repository = ref.watch(feedRepositoryProvider);
  return repository.getMyPacks();
});

final selectedChannelIdProvider =
    NotifierProvider<SelectedChannelNotifier, String?>(
      () => SelectedChannelNotifier(),
    );

class SelectedChannelNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? channelId) {
    state = channelId;
  }
}

final channelEntriesProvider = FutureProvider.family<List<Entry>, String>((
  ref,
  channelId,
) async {
  final repository = ref.watch(feedRepositoryProvider);
  final settings = ref.watch(interactionSettingsProvider);
  return repository.getChannelEntries(
    channelId,
    limit: settings.pageSize,
    timeField: 'published_at',
  );
});

/// Returns the unread entry count for a specific channel.
final channelUnreadCountProvider = FutureProvider.family<int, String>((
  ref,
  channelId,
) async {
  final repository = ref.read(feedRepositoryProvider);
  final entries = await repository.getChannelEntries(
    channelId,
    limit: 500,
    unreadOnly: true,
    timeField: 'published_at',
  );
  return entries.length;
});
