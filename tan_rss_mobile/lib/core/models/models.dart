class Entry {
  final String id;
  final String feedId;
  final String? feedTitle;
  final String? title;
  final String? translatedTitle;
  final String? url;
  final String? author;
  final String? summary;
  final String? content;
  final String? publishedAt;
  final String? insertedAt;
  final bool read;
  final bool starred;

  Entry({
    required this.id,
    required this.feedId,
    this.feedTitle,
    this.title,
    this.translatedTitle,
    this.url,
    this.author,
    this.summary,
    this.content,
    this.publishedAt,
    this.insertedAt,
    required this.read,
    required this.starred,
  });

  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      id: json['id'] ?? '',
      feedId: json['feed_id'] ?? '',
      feedTitle: json['feed_title'],
      title: json['title'],
      translatedTitle: json['translated_title'],
      url: json['url'],
      author: json['author'],
      summary: json['summary'],
      content: json['content'],
      publishedAt: json['published_at'],
      insertedAt: json['inserted_at'],
      read: json['read'] ?? false,
      starred: json['starred'] ?? false,
    );
  }

  Entry copyWith({
    bool? read,
    bool? starred,
    String? title,
    String? summary,
    String? content,
  }) {
    return Entry(
      id: id,
      feedId: feedId,
      feedTitle: feedTitle,
      title: title ?? this.title,
      url: url,
      author: author,
      summary: summary ?? this.summary,
      content: content ?? this.content,
      publishedAt: publishedAt,
      insertedAt: insertedAt,
      read: read ?? this.read,
      starred: starred ?? this.starred,
    );
  }

  String? get thumbnail {
    if (content == null || content!.isEmpty) return null;
    final imgMatch = RegExp(r'<img[^>]+src="([^">]+)"').firstMatch(content!);
    if (imgMatch != null && imgMatch.group(1) != null) {
      return imgMatch.group(1);
    }
    return null;
  }
}

class Feed {
  final String id;
  final String url;
  final String? title;
  final String? favicon;
  final int? unreadCount;
  final String? channelId;

  Feed({
    required this.id,
    required this.url,
    this.title,
    this.favicon,
    this.unreadCount,
    this.channelId,
  });

  factory Feed.fromJson(Map<String, dynamic> json) {
    return Feed(
      id: json['id'] ?? '',
      url: json['url'] ?? '',
      title: json['title'],
      favicon: json['favicon_url'] ?? json['favicon'],
      unreadCount: json['unread_count'] ?? 0,
      channelId: json['channel_id'],
    );
  }
}

class OpmlImportResult {
  final int imported;
  final int skipped;
  final List<String> errors;

  const OpmlImportResult({
    required this.imported,
    required this.skipped,
    required this.errors,
  });
}

class AppSettings {
  final int fetchIntervalMinutes;
  final String rsshubUrl;

  const AppSettings({
    required this.fetchIntervalMinutes,
    required this.rsshubUrl,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      fetchIntervalMinutes: json['fetch_interval_minutes'] ?? 15,
      rsshubUrl: json['rsshub_url'] ?? 'https://rsshub.app',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fetch_interval_minutes': fetchIntervalMinutes,
      'rsshub_url': rsshubUrl,
    };
  }
}

class ScheduledTask {
  final String id;
  final String name;
  final String taskType;
  final bool enabled;
  final String? lastRun;
  final int runCount;
  final int successCount;
  final int errorCount;
  final String? lastError;

  const ScheduledTask({
    required this.id,
    required this.name,
    required this.taskType,
    required this.enabled,
    required this.lastRun,
    required this.runCount,
    required this.successCount,
    required this.errorCount,
    required this.lastError,
  });

  factory ScheduledTask.fromJson(Map<String, dynamic> json) {
    return ScheduledTask(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      taskType: json['task_type'] ?? '',
      enabled: json['enabled'] ?? false,
      lastRun: json['last_run'],
      runCount: json['run_count'] ?? 0,
      successCount: json['success_count'] ?? 0,
      errorCount: json['error_count'] ?? 0,
      lastError: json['last_error'],
    );
  }
}

class AIServiceConfig {
  final String apiKey;
  final String baseUrl;
  final String modelName;
  final bool hasApiKey;

  const AIServiceConfig({
    required this.apiKey,
    required this.baseUrl,
    required this.modelName,
    required this.hasApiKey,
  });

  factory AIServiceConfig.fromJson(Map<String, dynamic> json) {
    return AIServiceConfig(
      apiKey: json['api_key'] ?? '',
      baseUrl: json['base_url'] ?? '',
      modelName: json['model_name'] ?? '',
      hasApiKey: json['has_api_key'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'api_key': apiKey,
      'base_url': baseUrl,
      'model_name': modelName,
      'has_api_key': hasApiKey,
    };
  }
}

class AIFeatureConfig {
  final bool autoSummary;
  final bool autoTranslation;
  final bool autoTitleTranslation;
  final bool autoQualityScoring;
  final String translationLanguage;

  const AIFeatureConfig({
    required this.autoSummary,
    required this.autoTranslation,
    required this.autoTitleTranslation,
    required this.autoQualityScoring,
    required this.translationLanguage,
  });

  factory AIFeatureConfig.fromJson(Map<String, dynamic> json) {
    return AIFeatureConfig(
      autoSummary: json['auto_summary'] ?? false,
      autoTranslation: json['auto_translation'] ?? false,
      autoTitleTranslation: json['auto_title_translation'] ?? false,
      autoQualityScoring: json['auto_quality_scoring'] ?? true,
      translationLanguage: json['translation_language'] ?? 'zh',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'auto_summary': autoSummary,
      'auto_translation': autoTranslation,
      'auto_title_translation': autoTitleTranslation,
      'auto_quality_scoring': autoQualityScoring,
      'translation_language': translationLanguage,
    };
  }
}

class AIConfig {
  final AIServiceConfig summary;
  final AIServiceConfig translation;
  final AIFeatureConfig features;

  const AIConfig({
    required this.summary,
    required this.translation,
    required this.features,
  });

  factory AIConfig.fromJson(Map<String, dynamic> json) {
    return AIConfig(
      summary: AIServiceConfig.fromJson(json['summary'] ?? {}),
      translation: AIServiceConfig.fromJson(json['translation'] ?? {}),
      features: AIFeatureConfig.fromJson(json['features'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'summary': summary.toJson(),
      'translation': translation.toJson(),
      'features': features.toJson(),
    };
  }
}

class Tag {
  final String id;
  final String name;

  const Tag({required this.id, required this.name});

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

class Category {
  final String id;
  final String name;
  final int sortOrder;

  const Category({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}

class PreviewEntry {
  final String id;
  final String? title;
  final String? coverImage;
  final String? publishedAt;

  const PreviewEntry({
    required this.id,
    this.title,
    this.coverImage,
    this.publishedAt,
  });

  factory PreviewEntry.fromJson(Map<String, dynamic> json) {
    return PreviewEntry(
      id: json['id'] ?? '',
      title: json['title'],
      coverImage: json['cover_image'],
      publishedAt: json['published_at'],
    );
  }
}

class Channel {
  final String id;
  final String name;
  final bool isPublic;
  final String? description;
  final String? iconUrl;
  final String? coverUrl;
  final String? kind;
  final String? categoryId;
  final String? ownerId;
  final List<Tag> tags;
  final List<PreviewEntry> previewEntries;
  final String? createdAt;
  final String? updatedAt;

  const Channel({
    required this.id,
    required this.name,
    required this.isPublic,
    this.description,
    this.iconUrl,
    this.coverUrl,
    this.kind,
    this.categoryId,
    this.ownerId,
    this.tags = const [],
    this.previewEntries = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      isPublic: json['is_public'] ?? false,
      description: json['description'],
      iconUrl: json['icon_url'],
      coverUrl: json['cover_url'],
      kind: json['kind'],
      categoryId: json['category_id'],
      ownerId: json['owner_id'],
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => Tag.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      previewEntries: (json['preview_entries'] as List<dynamic>?)
              ?.map((e) => PreviewEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}

class ChannelSourceItem {
  final String feedId;
  final String url;
  final String? title;
  final String? faviconUrl;
  final int? orderIndex;
  final int? weight;
  final String? createdAt;

  const ChannelSourceItem({
    required this.feedId,
    required this.url,
    this.title,
    this.faviconUrl,
    this.orderIndex,
    this.weight,
    this.createdAt,
  });

  factory ChannelSourceItem.fromJson(Map<String, dynamic> json) {
    return ChannelSourceItem(
      feedId: json['feed_id'] ?? '',
      url: json['url'] ?? '',
      title: json['title'],
      faviconUrl: json['favicon_url'],
      orderIndex: json['order_index'],
      weight: json['weight'],
      createdAt: json['created_at'],
    );
  }
}


class TaskExecutionResult {
  final String taskId;
  final String taskName;
  final String startedAt;
  final String? completedAt;
  final bool success;
  final String message;
  final int? durationMs;

  const TaskExecutionResult({
    required this.taskId,
    required this.taskName,
    required this.startedAt,
    required this.completedAt,
    required this.success,
    required this.message,
    required this.durationMs,
  });

  factory TaskExecutionResult.fromJson(Map<String, dynamic> json) {
    return TaskExecutionResult(
      taskId: json['task_id'] ?? '',
      taskName: json['task_name'] ?? '',
      startedAt: json['started_at'] ?? '',
      completedAt: json['completed_at'],
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      durationMs: json['duration_ms'],
    );
  }
}

class UserProfile {
  final String id;
  final String username;
  final String? email;
  final String role;
  final bool isActive;
  final String? createdAt;

  const UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'],
      role: json['role'] ?? 'user',
      isActive: json['is_active'] ?? false,
      createdAt: json['created_at'],
    );
  }
}

class AiSummaryData {
  final String language;
  final String summary;
  final List<String> keyPoints;

  const AiSummaryData({
    required this.language,
    required this.summary,
    required this.keyPoints,
  });
}

class SearchResult {
  final String id;
  final String title;
  final int publishedAt;
  final double score;

  const SearchResult({
    required this.id,
    required this.title,
    required this.publishedAt,
    required this.score,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      publishedAt: json['published_at'] ?? 0,
      score: (json['score'] ?? 0.0).toDouble(),
    );
  }
}

class SynthesisReference {
  final int index;
  final String id;
  final String title;
  final String url;
  final String? publishedAt;

  const SynthesisReference({
    required this.index,
    required this.id,
    required this.title,
    required this.url,
    this.publishedAt,
  });

  factory SynthesisReference.fromJson(Map<String, dynamic> json) {
    return SynthesisReference(
      index: json['index'] ?? 0,
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      publishedAt: json['published_at'],
    );
  }
}

class SynthesisResult {
  final String markdown;
  final List<SynthesisReference> references;

  const SynthesisResult({
    required this.markdown,
    required this.references,
  });

  factory SynthesisResult.fromJson(Map<String, dynamic> json) {
    return SynthesisResult(
      markdown: json['markdown'] ?? '',
      references: (json['references'] as List<dynamic>?)
              ?.map((e) => SynthesisReference.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class AIDailyDigest {
  final bool exists;
  final String? content;
  final List<SynthesisReference> references;
  final String? createdAt;

  const AIDailyDigest({
    required this.exists,
    this.content,
    this.references = const [],
    this.createdAt,
  });

  factory AIDailyDigest.fromJson(Map<String, dynamic> json) {
    return AIDailyDigest(
      exists: json['exists'] ?? false,
      content: json['content'],
      references: (json['references'] as List<dynamic>?)
              ?.map((e) => SynthesisReference.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'],
    );
  }
}

class SourceInfo {
  final String name;
  final String type;
  final Map<String, dynamic> config;

  const SourceInfo({
    required this.name,
    this.type = 'channel',
    this.config = const {},
  });

  factory SourceInfo.fromJson(Map<String, dynamic> json) {
    return SourceInfo(
      name: json['name'] ?? '',
      type: json['type'] ?? 'channel',
      config: json['config'] ?? {},
    );
  }
}

class SourcePack {
  final String id;
  final String name;
  final String? description;
  final String? slug;
  final List<SourceInfo> sources;
  final bool isPublic;
  final int installCount;
  final String? createdAt;
  final String? updatedAt;

  const SourcePack({
    required this.id,
    required this.name,
    this.description,
    this.slug,
    this.sources = const [],
    this.isPublic = true,
    this.installCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory SourcePack.fromJson(Map<String, dynamic> json) {
    return SourcePack(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      slug: json['slug'],
      sources: (json['sources'] as List<dynamic>?)
              ?.map((e) => SourceInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isPublic: json['is_public'] ?? true,
      installCount: json['install_count'] ?? 0,
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}
