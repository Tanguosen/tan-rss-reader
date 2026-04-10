import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import '../../../core/api/api_client.dart';
import '../../../core/models/models.dart';
import '../../../core/storage/local_cache_db.dart';

import 'dart:typed_data';

final feedRepositoryProvider = Provider((ref) => FeedRepository(ApiClient()));

class EntryQuery {
  final String? feedId;
  final bool unreadOnly;
  final bool starredOnly;
  final bool highQualityOnly;
  final int limit;
  final int offset;
  final String orderBy;
  final String order;
  final String searchText;
  final String dateRange;

  const EntryQuery({
    this.feedId,
    this.unreadOnly = false,
    this.starredOnly = false,
    this.highQualityOnly = false,
    this.limit = 100,
    this.offset = 0,
    this.orderBy = 'published_at',
    this.order = 'desc',
    this.searchText = '',
    this.dateRange = 'all',
  });
}

class FeedRepository {
  final ApiClient _apiClient;
  final LocalCacheDb _cache = LocalCacheDb();
  final Map<String, Future<String>> _inflightTextTranslations = {};

  FeedRepository(this._apiClient);

  Future<List<Feed>> getFeeds() async {
    try {
      final response = await _apiClient.dio.get('/feeds');
      final feeds = (response.data as List)
          .map((e) => Feed.fromJson(e))
          .toList();
      await _cache.cacheFeeds(feeds);
      return feeds;
    } catch (_) {
      final cachedFeeds = await _cache.readFeeds();
      if (cachedFeeds.isNotEmpty) return cachedFeeds;
      rethrow;
    }
  }

  Future<Feed> createFeed({
    required String url,
    String? title,
    int? updateInterval,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/feeds',
        data: {'url': url, 'title': title, 'update_interval': updateInterval},
      );
      return Feed.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('创建订阅源失败：${e.message}');
    }
  }

  Future<Feed> updateFeed({
    required String id,
    String? title,
    int? updateInterval,
  }) async {
    try {
      final response = await _apiClient.dio.patch(
        '/feeds/$id',
        data: {'title': title, 'update_interval': updateInterval},
      );
      return Feed.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('更新订阅源失败：${e.message}');
    }
  }

  Future<void> deleteFeed(String id) async {
    try {
      await _apiClient.dio.delete('/feeds/$id');
    } on DioException catch (e) {
      throw Exception('删除订阅源失败：${e.message}');
    }
  }

  Future<List<Feed>> getAdminFeeds() async {
    try {
      final response = await _apiClient.dio.get('/admin/feeds');
      return (response.data as List)
          .map((e) => Feed.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('加载平台订阅源失败：${e.message}');
    }
  }

  Future<Feed> createAdminFeed({
    required String url,
    String? title,
    int? updateInterval,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/admin/feeds',
        data: {'url': url, 'title': title, 'update_interval': updateInterval},
      );
      return Feed.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('创建平台订阅源失败：${e.message}');
    }
  }

  Future<Feed> updateAdminFeed({
    required String id,
    String? title,
    int? updateInterval,
  }) async {
    try {
      final response = await _apiClient.dio.patch(
        '/admin/feeds/$id',
        data: {'title': title, 'update_interval': updateInterval},
      );
      return Feed.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('更新平台订阅源失败：${e.message}');
    }
  }

  Future<void> deleteAdminFeed(String id) async {
    try {
      await _apiClient.dio.delete('/admin/feeds/$id');
    } on DioException catch (e) {
      throw Exception('删除平台订阅源失败：${e.message}');
    }
  }

  // Phase 3/Channel management: fetch channel's feeds
  Future<List<Feed>> getChannelFeeds(String channelId) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/channels/$channelId/feeds',
      );
      final feeds = (response.data as List)
          .map((e) => Feed.fromJson(e))
          .toList();
      await _cache.cacheFeeds(feeds);
      return feeds;
    } on DioException catch (e) {
      throw Exception('加载频道源失败：${e.message}');
    }
  }

  // (Phase 3) Channel sources management moved to admin endpoints below

  // Fetch feeds the current user has subscribed to
  Future<List<Feed>> getUserSubscribedFeeds() async {
    try {
      final response = await _apiClient.dio.get('/me/subscriptions/feeds');
      final feeds = (response.data as List)
          .map((e) => Feed.fromJson(e))
          .toList();
      await _cache.cacheFeeds(feeds);
      return feeds;
    } on DioException catch (e) {
      throw Exception('加载订阅源失败：${e.message}');
    }
  }

  // Add multiple feeds to a channel
  Future<void> addFeedsToChannel(String channelId, List<String> feedIds) async {
    try {
      await _apiClient.dio.post(
        '/api/channels/$channelId/feeds',
        data: {'feed_ids': feedIds},
      );
    } on DioException catch (e) {
      throw Exception('添加订阅源到频道失败：${e.message}');
    }
  }

  Future<List<Entry>> getEntries({int limit = 50, int offset = 0}) async {
    return getEntriesByQuery(EntryQuery(limit: limit, offset: offset));
  }

  Future<List<Entry>> getEntriesByQuery(EntryQuery query) async {
    final token = await _apiClient.getAuthToken();
    final isLoggedIn = token != null && token.isNotEmpty;
    final normalizedTimeField = query.orderBy == 'inserted_at'
        ? 'inserted_at'
        : 'published_at';
    final normalizedOrderBy = normalizedTimeField == 'published_at'
        ? 'published_at'
        : 'created_at';
    try {
      final params = <String, dynamic>{
        'limit': query.limit,
        'offset': query.offset,
        'time_field': normalizedTimeField,
        'order_by': normalizedOrderBy,
        'order': query.order,
      };
      if (query.dateRange.isNotEmpty && query.dateRange != 'all') {
        params['date_range'] = query.dateRange;
      }
      if (query.feedId != null && query.feedId!.isNotEmpty) {
        params['feed_id'] = query.feedId;
      }
      if (query.unreadOnly) {
        params['unread_only'] = true;
      }
      if (query.starredOnly) {
        params['is_starred'] = true;
      }
      if (query.highQualityOnly) {
        params['high_quality_only'] = true;
      }
      final path = isLoggedIn ? '/me/subscriptions/entries' : '/entries';
      final response = await _apiClient.dio.get(
        path,
        queryParameters: {...params},
      );
      final items = (response.data as List)
          .map((e) => Entry.fromJson(e))
          .toList();
      await _cache.cacheEntries(items);
      if (query.searchText.trim().isEmpty) {
        return items;
      }
      final keyword = query.searchText.toLowerCase();
      return items.where((entry) {
        final title = (entry.title ?? '').toLowerCase();
        final summary = (entry.summary ?? '').toLowerCase();
        final feedTitle = (entry.feedTitle ?? '').toLowerCase();
        return title.contains(keyword) ||
            summary.contains(keyword) ||
            feedTitle.contains(keyword);
      }).toList();
    } on DioException {
      final cachedItems = await _cache.readEntries(
        feedId: query.feedId,
        unreadOnly: query.unreadOnly,
        starredOnly: query.starredOnly,
        limit: query.limit,
        offset: query.offset,
        searchText: query.searchText,
        orderBy: normalizedTimeField,
        order: query.order,
      );
      if (cachedItems.isNotEmpty) {
        return cachedItems;
      }
      rethrow;
    }
  }

  Future<Entry> getEntry(String id) async {
    try {
      final response = await _apiClient.dio.get('/entries/$id');
      final entry = Entry.fromJson(response.data as Map<String, dynamic>);
      await _cache.cacheEntries([entry]);
      return entry;
    } on DioException {
      final cached = await _cache.readEntry(id);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<void> markEntryRead(String id, {required bool read}) async {
    try {
      if (read) {
        await _apiClient.dio.post('/entries/$id/read');
      } else {
        await _apiClient.dio.post('/entries/$id/unread');
      }
    } on DioException catch (e) {
      throw Exception('更新阅读状态失败：${e.message}');
    }
  }

  Future<void> trackEntryView(String id) async {
    try {
      await _apiClient.dio.post('/me/history/$id/view');
    } on DioException {
      // 阅读历史是增强能力，不阻塞主阅读流程
    }
  }

  Future<void> markEntryStarred(String id, {required bool starred}) async {
    try {
      if (starred) {
        await _apiClient.dio.post('/entries/$id/star');
      } else {
        await _apiClient.dio.post('/entries/$id/unstar');
      }
    } on DioException catch (e) {
      throw Exception('更新收藏状态失败：${e.message}');
    }
  }

  Future<void> bulkMarkStarred(
    List<String> ids, {
    required bool starred,
  }) async {
    if (ids.isEmpty) return;
    try {
      if (starred) {
        await _apiClient.dio.post('/entries/bulk-star', data: {'ids': ids});
      } else {
        await _apiClient.dio.post('/entries/bulk-unstar', data: {'ids': ids});
      }
    } on DioException catch (e) {
      throw Exception('批量收藏操作失败：${e.message}');
    }
  }

  Future<void> refreshFeed(String feedId) async {
    try {
      await _apiClient.dio.post('/feeds/$feedId/refresh');
    } on DioException catch (e) {
      throw Exception('刷新订阅源失败：${e.message}');
    }
  }

  Future<Map<String, dynamic>> refreshChannel(String channelId) async {
    try {
      final response = await _apiClient.dio.post(
        '/channels/$channelId/refresh',
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('刷新频道失败：${e.message}');
    }
  }

  Future<Map<String, dynamic>> refreshMySubscribedFeeds() async {
    try {
      final response = await _apiClient.dio.post('/me/subscriptions/refresh');
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw Exception('同步订阅源失败：${e.message}');
    }
  }

  Future<int> markChannelAllRead(String channelId) async {
    try {
      final response = await _apiClient.dio.post(
        '/channels/$channelId/mark-all-read',
      );
      final data = response.data as Map<String, dynamic>;
      return (data['updated'] ?? 0) as int;
    } on DioException catch (e) {
      throw Exception('标记全部已读失败：${e.message}');
    }
  }

  Future<OpmlImportResult> importOpml(String content) async {
    try {
      final response = await _apiClient.dio.post(
        '/opml/import',
        data: {'content': content},
      );
      final data = response.data as Map<String, dynamic>;
      return OpmlImportResult(
        imported: data['imported'] ?? 0,
        skipped: data['skipped'] ?? 0,
        errors: ((data['errors'] ?? []) as List).map((e) => '$e').toList(),
      );
    } on DioException catch (e) {
      throw Exception('导入OPML失败：${e.message}');
    }
  }

  Future<String> exportOpmlText() async {
    try {
      final response = await _apiClient.dio.get(
        '/opml/export',
        options: Options(responseType: ResponseType.plain),
      );
      final data = response.data;
      if (data is String) return data;
      if (data is List<int>) return utf8.decode(data);
      return '$data';
    } on DioException catch (e) {
      throw Exception('导出OPML失败：${e.message}');
    }
  }

  Future<List<ScheduledTask>> getTasks() async {
    try {
      final response = await _apiClient.dio.get('/tasks');
      final data = response.data as Map<String, dynamic>;
      final tasks = (data['tasks'] ?? []) as List;
      return tasks
          .map((e) => ScheduledTask.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('加载任务列表失败：${e.message}');
    }
  }

  Future<TaskExecutionResult> executeTask(String taskId) async {
    try {
      final response = await _apiClient.dio.post('/tasks/$taskId');
      final data = response.data as Map<String, dynamic>;
      final result = data['result'] as Map<String, dynamic>;
      return TaskExecutionResult.fromJson(result);
    } on DioException catch (e) {
      throw Exception('执行任务失败：${e.message}');
    }
  }

  Future<List<TaskExecutionResult>> getTaskHistory(String taskId) async {
    try {
      final response = await _apiClient.dio.get('/tasks/$taskId/history');
      final data = response.data as Map<String, dynamic>;
      final history = (data['history'] ?? []) as List;
      return history
          .map((e) => TaskExecutionResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('加载任务历史失败：${e.message}');
    }
  }

  // Channels
  Future<List<Channel>> getAdminChannels() async {
    try {
      final response = await _apiClient.dio.get('/admin/channels');
      return (response.data as List)
          .map((e) => Channel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('加载管理频道失败：${e.message}');
    }
  }

  Future<List<Channel>> getSquareChannels() async {
    try {
      final response = await _apiClient.dio.get('/channels/square');
      final channels = (response.data as List)
          .map((e) => Channel.fromJson(e as Map<String, dynamic>))
          .toList();
      await _cache.cacheChannels(channels, scope: 'square');
      return channels;
    } on DioException {
      final cached = await _cache.readChannels(scope: 'square');
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<Channel> createChannel({
    required String name,
    String? description,
    bool isPublic = true,
    String? iconUrl,
    String? ownerId,
  }) async {
    try {
      final data = {
        'name': name,
        'description': description,
        'is_public': isPublic,
      };
      if (iconUrl != null) data['icon_url'] = iconUrl;
      if (ownerId != null) data['owner_id'] = ownerId;
      final response = await _apiClient.dio.post('/admin/channels', data: data);
      return Channel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('创建频道失败：${e.message}');
    }
  }

  Future<Channel> updateChannel(
    String id, {
    String? name,
    String? description,
    bool? isPublic,
    String? iconUrl,
    String? coverUrl,
    String? categoryId,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (isPublic != null) data['is_public'] = isPublic;
      if (iconUrl != null) data['icon_url'] = iconUrl;
      if (coverUrl != null) data['cover_url'] = coverUrl;
      if (categoryId != null) data['category_id'] = categoryId;
      final response = await _apiClient.dio.patch(
        '/admin/channels/$id',
        data: data,
      );
      return Channel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('更新频道失败：${e.message}');
    }
  }

  Future<void> deleteChannel(String id) async {
    try {
      await _apiClient.dio.delete('/admin/channels/$id');
    } on DioException catch (e) {
      throw Exception('删除频道失败：${e.message}');
    }
  }

  Future<List<ChannelSourceItem>> getChannelSources(String channelId) async {
    try {
      final response = await _apiClient.dio.get(
        '/admin/channels/$channelId/sources',
      );
      return (response.data as List)
          .map((e) => ChannelSourceItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('加载频道数据源失败：${e.message}');
    }
  }

  Future<void> addChannelSource(String channelId, String feedId) async {
    try {
      await _apiClient.dio.post(
        '/admin/channels/$channelId/sources',
        data: {'feed_id': feedId},
      );
    } on DioException catch (e) {
      throw Exception('添加频道数据源失败：${e.message}');
    }
  }

  Future<void> addChannelSourceByUrl(String channelId, String url) async {
    try {
      final feed = await createFeed(url: url);
      await addChannelSource(channelId, feed.id);
    } on DioException catch (e) {
      throw Exception('添加频道数据源失败：${e.message}');
    }
  }

  Future<void> removeChannelSource(String channelId, String feedId) async {
    try {
      await _apiClient.dio.delete('/admin/channels/$channelId/sources/$feedId');
    } on DioException catch (e) {
      throw Exception('移除频道数据源失败：${e.message}');
    }
  }

  Future<ChannelSourceItem> updateChannelSource({
    required String channelId,
    required String feedId,
    String? title,
    int? updateInterval,
    int? orderIndex,
    int? weight,
  }) async {
    try {
      final response = await _apiClient.dio.patch(
        '/admin/channels/$channelId/sources/$feedId',
        data: {
          'title': title,
          'update_interval': updateInterval,
          'order_index': orderIndex,
          'weight': weight,
        },
      );
      return ChannelSourceItem.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('更新频道数据源失败：${e.message}');
    }
  }

  // System Settings
  Future<AppSettings> getSettings() async {
    try {
      final response = await _apiClient.dio.get('/settings');
      return AppSettings.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('加载系统设置失败：${e.message}');
    }
  }

  Future<void> updateSettings(Map<String, dynamic> settings) async {
    try {
      await _apiClient.dio.patch('/settings', data: settings);
    } on DioException catch (e) {
      throw Exception('更新系统设置失败：${e.message}');
    }
  }

  // AI Configuration
  Future<AIConfig> getAIConfig() async {
    try {
      final response = await _apiClient.dio.get('/ai/user/config');
      return AIConfig.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('加载AI配置失败：${e.message}');
    }
  }

  Future<void> updateAIConfig(AIConfig config) async {
    try {
      await _apiClient.dio.put('/ai/user/config', data: config.toJson());
    } on DioException catch (e) {
      throw Exception('更新AI配置失败：${e.message}');
    }
  }

  // AI Prompts
  Future<List<Map<String, dynamic>>> getAIPrompts() async {
    try {
      final response = await _apiClient.dio.get('/ai/prompts');
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      throw Exception('加载AI提示词失败：${e.message}');
    }
  }

  Future<Map<String, dynamic>> createAIPrompt(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.post('/ai/prompts', data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('创建AI提示词失败：${e.message}');
    }
  }

  Future<Map<String, dynamic>> updateAIPrompt(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _apiClient.dio.put('/ai/prompts/$id', data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('更新AI提示词失败：${e.message}');
    }
  }

  Future<void> deleteAIPrompt(String id) async {
    try {
      await _apiClient.dio.delete('/ai/prompts/$id');
    } on DioException catch (e) {
      throw Exception('删除AI提示词失败：${e.message}');
    }
  }

  // Membership
  Future<Map<String, dynamic>> getMembershipStatus() async {
    try {
      final response = await _apiClient.dio.get('/membership/status');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('加载会员状态失败：${e.message}');
    }
  }

  Future<Map<String, dynamic>> subscribeMembership(
    String tier, {
    int months = 1,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/membership/subscribe',
        data: {'tier': tier, 'months': months},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('订阅会员失败：${e.message}');
    }
  }

  Future<bool> testAIService(
    String serviceKey,
    Map<String, dynamic> config,
  ) async {
    try {
      final response = await _apiClient.dio.post(
        '/ai/test',
        data: {'service': serviceKey, 'config': config},
      );
      final data = response.data as Map<String, dynamic>;
      return data['success'] == true;
    } on DioException {
      return false;
    }
  }

  Future<List<Entry>> getStarredEntries({
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/entries/starred',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final items = (response.data as List)
          .map((e) => Entry.fromJson(e))
          .toList();
      await _cache.cacheEntries(items);
      return items;
    } on DioException {
      final cached = await _cache.readEntries(
        starredOnly: true,
        limit: limit,
        offset: offset,
      );
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<List<ReadingHistoryItem>> getReadingHistory({int limit = 30}) async {
    try {
      final response = await _apiClient.dio.get(
        '/me/history',
        queryParameters: {'limit': limit},
      );
      return (response.data as List)
          .map((e) => ReadingHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('加载最近阅读失败：${e.message}');
    }
  }

  Future<List<RecommendedTopic>> getRecommendedTopics({int limit = 6}) async {
    try {
      final response = await _apiClient.dio.get(
        '/me/topics/recommended',
        queryParameters: {'limit': limit},
      );
      return (response.data as List)
          .map((e) => RecommendedTopic.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('加载我的专题失败：${e.message}');
    }
  }

  Future<AiSummaryData> summarizeEntry({
    required String entryId,
    String language = 'zh',
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/ai/summary',
        data: {'entry_id': entryId, 'language': language},
      );
      final data = response.data as Map<String, dynamic>;
      final summary = (data['summary'] ?? '') as String;
      final keyPoints = ((data['key_points'] ?? []) as List)
          .map((e) => '$e')
          .toList();
      final result = AiSummaryData(
        language: language,
        summary: summary,
        keyPoints: keyPoints,
      );
      await _cache.cacheAiSummary(
        entryId: entryId,
        language: language,
        summary: summary,
        keyPoints: keyPoints,
      );
      return result;
    } on DioException {
      final cached = await _cache.readAiSummary(
        entryId: entryId,
        language: language,
      );
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<String> translateTitle({
    required String entryId,
    String language = 'zh',
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/ai/translate-title',
        data: {'entry_id': entryId, 'language': language},
      );
      final data = response.data as Map<String, dynamic>;
      final title = (data['title'] ?? '') as String;
      await _cache.cacheTranslatedTitle(
        entryId: entryId,
        language: language,
        title: title,
      );
      return title;
    } on DioException {
      final cached = await _cache.readTranslatedTitle(
        entryId: entryId,
        language: language,
      );
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<String> translateContent({
    required String entryId,
    String language = 'zh',
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/ai/translate',
        data: {
          'entry_id': entryId,
          'field_type': 'content',
          'target_language': language,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final content = (data['translated_text'] ?? '') as String;
      await _cache.cacheTranslatedContent(
        entryId: entryId,
        language: language,
        content: content,
      );
      return content;
    } on DioException {
      final cached = await _cache.readTranslatedContent(
        entryId: entryId,
        language: language,
      );
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<List<Category>> getPublicCategories() async {
    try {
      final response = await _apiClient.dio.get('/categories');
      return (response.data as List)
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('加载分类失败：${e.message}');
    }
  }

  /// 翻译任意纯文本（用于话题名称、聚类标题等不依赖 entry_id 的场景）
  Future<String> translateText({
    required String text,
    String language = 'zh',
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      return text;
    }
    final cached = await _cache.readTranslatedText(
      sourceText: normalizedText,
      language: language,
    );
    if (cached != null) {
      return cached;
    }

    final requestKey = '$language::$normalizedText';
    final inflight = _inflightTextTranslations[requestKey];
    if (inflight != null) {
      return inflight;
    }

    final future = _translateAndCacheText(
      sourceText: normalizedText,
      language: language,
      fallbackText: text,
    );
    _inflightTextTranslations[requestKey] = future;
    try {
      return await future;
    } finally {
      _inflightTextTranslations.remove(requestKey);
    }
  }

  Future<String> _translateAndCacheText({
    required String sourceText,
    required String language,
    required String fallbackText,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/ai/translate-text',
        data: {'text': sourceText, 'target_language': language},
      );
      final data = response.data as Map<String, dynamic>;
      final translated = (data['translated'] ?? sourceText) as String;
      if (translated.isNotEmpty) {
        await _cache.cacheTranslatedText(
          sourceText: sourceText,
          language: language,
          translatedText: translated,
        );
      }
      return translated;
    } on DioException {
      return fallbackText; // 翻译失败时返回原文
    }
  }

  Future<String> translateLongText({
    required String text,
    String language = 'zh',
    int maxChunkLength = 1800,
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      return text;
    }
    if (normalizedText.length <= maxChunkLength) {
      return translateText(text: normalizedText, language: language);
    }

    final chunks = <String>[];
    final buffer = StringBuffer();
    final paragraphs = normalizedText.split(RegExp(r'\n{2,}'));

    void flushBuffer() {
      final chunk = buffer.toString().trim();
      if (chunk.isNotEmpty) {
        chunks.add(chunk);
      }
      buffer.clear();
    }

    for (final paragraph in paragraphs) {
      final candidate = paragraph.trim();
      if (candidate.isEmpty) {
        continue;
      }
      if (candidate.length > maxChunkLength) {
        if (buffer.isNotEmpty) {
          flushBuffer();
        }
        for (var i = 0; i < candidate.length; i += maxChunkLength) {
          final end = (i + maxChunkLength).clamp(0, candidate.length);
          chunks.add(candidate.substring(i, end));
        }
        continue;
      }
      final pending = buffer.isEmpty
          ? candidate
          : '${buffer.toString().trim()}\n\n$candidate';
      if (pending.length > maxChunkLength && buffer.isNotEmpty) {
        flushBuffer();
        buffer.write(candidate);
      } else {
        if (buffer.isNotEmpty) {
          buffer.write('\n\n');
        }
        buffer.write(candidate);
      }
    }

    if (buffer.isNotEmpty) {
      flushBuffer();
    }

    final translatedChunks = <String>[];
    for (final chunk in chunks) {
      translatedChunks.add(
        await translateText(text: chunk, language: language),
      );
    }
    return translatedChunks.join('\n\n');
  }

  Future<List<Channel>> getMySubscriptions() async {
    try {
      final response = await _apiClient.dio.get('/me/subscriptions');
      final channels = (response.data as List)
          .map((e) => Channel.fromJson(e as Map<String, dynamic>))
          .toList();
      await _cache.cacheChannels(channels, scope: 'my_subscriptions');
      return channels;
    } on DioException {
      final cached = await _cache.readChannels(scope: 'my_subscriptions');
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<void> subscribeChannel(String channelId) async {
    try {
      await _apiClient.dio.post('/channels/$channelId/subscribe');
    } on DioException catch (e) {
      throw Exception('订阅频道失败：${e.message}');
    }
  }

  Future<void> unsubscribeChannel(String channelId) async {
    try {
      await _apiClient.dio.delete('/channels/$channelId/subscribe');
    } on DioException catch (e) {
      throw Exception('取消订阅失败：${e.message}');
    }
  }

  // Source Packs
  Future<List<SourcePack>> getPublicPacks({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/packs',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      return (response.data as List)
          .map((e) => SourcePack.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('加载源包列表失败：${e.message}');
    }
  }

  Future<List<SourcePack>> getMyPacks() async {
    try {
      final response = await _apiClient.dio.get('/my/packs');
      return (response.data as List)
          .map((e) => SourcePack.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('加载我的源包失败：${e.message}');
    }
  }

  Future<SourcePack> createPack({
    required String name,
    String? description,
    required String sourcesJson,
  }) async {
    try {
      final data = {
        'name': name,
        'description': description,
        'sources_json': sourcesJson,
      };
      final response = await _apiClient.dio.post('/packs', data: data);
      return SourcePack.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('创建源包失败：${e.message}');
    }
  }

  Future<void> deletePack(String id) async {
    try {
      await _apiClient.dio.delete('/packs/$id');
    } on DioException catch (e) {
      throw Exception('删除源包失败：${e.message}');
    }
  }

  Future<Map<String, dynamic>> installPack(String slug) async {
    try {
      final response = await _apiClient.dio.post('/packs/$slug/install');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('安装源包失败：${e.message}');
    }
  }

  Future<List<Entry>> getChannelEntries(
    String channelId, {
    int limit = 100,
    int offset = 0,
    bool? unreadOnly,
    String? dateRange,
    String? timeField,
  }) async {
    final normalizedTimeField = timeField == 'inserted_at'
        ? 'inserted_at'
        : 'published_at';
    try {
      final params = <String, dynamic>{
        'limit': limit,
        'offset': offset,
        'time_field': normalizedTimeField,
        'order_by': normalizedTimeField == 'published_at'
            ? 'published_at'
            : 'created_at',
        'order': 'desc',
      };
      if (unreadOnly == true) params['unread_only'] = true;
      if (dateRange != null && dateRange != 'all') {
        params['date_range'] = dateRange;
      }
      final response = await _apiClient.dio.get(
        '/channels/$channelId/entries',
        queryParameters: params,
      );
      final items = (response.data as List)
          .map((e) => Entry.fromJson(e as Map<String, dynamic>))
          .toList();
      await _cache.cacheChannelEntries(channelId, items);
      return items;
    } on DioException {
      final cached = await _cache.readChannelEntries(
        channelId,
        unreadOnly: unreadOnly == true,
        limit: limit,
        offset: offset,
        orderBy: normalizedTimeField,
      );
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<List<ClusterItem>> getClusters({int days = 3}) async {
    try {
      final response = await _apiClient.dio.post(
        '/vector/cluster',
        data: {'days': days, 'min_samples': 2, 'eps': 0.3},
      );
      final data = response.data as Map<String, dynamic>;
      final clusters = (data['clusters'] ?? []) as List;
      return clusters
          .map((c) => ClusterItem.fromJson(c as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('加载聚类数据失败：${e.message}');
    }
  }

  Future<ClusterAnalysis> analyzeCluster(List<String> entryIds) async {
    try {
      final response = await _apiClient.dio.post(
        '/vector/cluster/analyze',
        data: {'entry_ids': entryIds},
      );
      return ClusterAnalysis.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('分析聚类失败：${e.message}');
    }
  }

  Future<List<SearchResult>> semanticSearch(
    String query, {
    int limit = 10,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/vector/search',
        data: {'query': query, 'limit': limit},
      );
      final data = response.data as Map<String, dynamic>;
      final results = (data['results'] ?? []) as List;
      return results
          .map((r) => SearchResult.fromJson(r as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('搜索失败：${e.message}');
    }
  }

  Future<ResearchResult> runResearch(String query, {int limit = 8}) async {
    try {
      final response = await _apiClient.dio.post(
        '/ai/research',
        data: {'query': query, 'limit': limit},
      );
      return ResearchResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('研究失败：${e.message}');
    }
  }

  Future<OriginalArticle> getOriginalArticle(String entryId) async {
    try {
      final response = await _apiClient.dio.get(
        '/ai/entries/$entryId/original',
      );
      return OriginalArticle.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final detail = e.response?.data;
      if (detail is Map<String, dynamic> && detail['detail'] != null) {
        throw Exception('加载原文失败：${detail['detail']}');
      }
      throw Exception('加载原文失败：${e.message}');
    }
  }

  Stream<String> generateSynthesisStream(
    List<String> entryIds, {
    required void Function(List<SynthesisReference> references) onReferences,
  }) async* {
    try {
      final response = await _apiClient.dio.post(
        '/ai/synthesis',
        data: {'entry_ids': entryIds},
        options: Options(responseType: ResponseType.stream),
      );

      final stream = response.data.stream as Stream<Uint8List>;

      String buffer = '';

      await for (final chunk in stream) {
        buffer += utf8.decode(chunk);
        int index;
        while ((index = buffer.indexOf('\n\n')) != -1) {
          final line = buffer.substring(0, index).trim();
          buffer = buffer.substring(index + 2);

          if (line.startsWith('data: ')) {
            final dataStr = line.substring(6).trim();
            if (dataStr == '[DONE]') return;
            try {
              final json = jsonDecode(dataStr);
              if (json['type'] == 'references') {
                final refs = (json['data'] as List)
                    .map(
                      (e) => SynthesisReference.fromJson(
                        e as Map<String, dynamic>,
                      ),
                    )
                    .toList();
                onReferences(refs);
              } else if (json['type'] == 'chunk') {
                yield json['content'] as String;
              } else if (json['error'] != null) {
                throw Exception(json['error']);
              }
            } catch (e) {
              // ignore invalid json chunks
            }
          }
        }
      }
    } on DioException catch (e) {
      throw Exception('生成综合分析失败：${e.message}');
    }
  }

  Future<AIDailyDigest> getTodayDigest() async {
    try {
      final response = await _apiClient.dio.get('/ai/daily-digest/today');
      return AIDailyDigest.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('获取每日摘要失败：${e.message}');
    }
  }

  Stream<String> generateDailyDigestStream(
    List<String> entryIds, {
    required void Function(List<SynthesisReference> references) onReferences,
  }) async* {
    try {
      final response = await _apiClient.dio.post(
        '/ai/daily-digest',
        data: {'entry_ids': entryIds},
        options: Options(responseType: ResponseType.stream),
      );

      final stream = response.data.stream as Stream<Uint8List>;

      String buffer = '';

      await for (final chunk in stream) {
        buffer += utf8.decode(chunk);
        int index;
        while ((index = buffer.indexOf('\n\n')) != -1) {
          final line = buffer.substring(0, index).trim();
          buffer = buffer.substring(index + 2);

          if (line.startsWith('data: ')) {
            final dataStr = line.substring(6).trim();
            if (dataStr == '[DONE]') return;
            try {
              final json = jsonDecode(dataStr);
              if (json['type'] == 'references') {
                final refs = (json['data'] as List)
                    .map(
                      (e) => SynthesisReference.fromJson(
                        e as Map<String, dynamic>,
                      ),
                    )
                    .toList();
                onReferences(refs);
              } else if (json['type'] == 'chunk') {
                yield json['content'] as String;
              } else if (json['error'] != null) {
                throw Exception(json['error']);
              }
            } catch (e) {
              // ignore
            }
          }
        }
      }
    } on DioException catch (e) {
      throw Exception('生成每日摘要失败：${e.message}');
    }
  }

  Stream<String> generateDeepDiveStream(
    String entryId, {
    String? language,
  }) async* {
    try {
      final response = await _apiClient.dio.post(
        '/ai/deep-dive',
        data: {
          'entry_id': entryId,
          if (language != null && language.isNotEmpty) 'language': language,
        },
        options: Options(responseType: ResponseType.stream),
      );

      final stream = response.data.stream as Stream<Uint8List>;

      String buffer = '';

      await for (final chunk in stream) {
        buffer += utf8.decode(chunk);
        int index;
        while ((index = buffer.indexOf('\n\n')) != -1) {
          final line = buffer.substring(0, index).trim();
          buffer = buffer.substring(index + 2);

          if (line.startsWith('data: ')) {
            final dataStr = line.substring(6).trim();
            if (dataStr == '[DONE]') return;
            try {
              final json = jsonDecode(dataStr);
              if (json['type'] == 'chunk') {
                yield json['content'] as String;
              } else if (json['error'] != null) {
                throw Exception(json['error']);
              }
            } catch (e) {
              // ignore
            }
          }
        }
      }
    } on DioException catch (e) {
      throw Exception('生成深度解读失败：${e.message}');
    }
  }
}

class ClusterItem {
  final int clusterId;
  final String topic;
  final int size;
  final List<ClusterEntryItem> items;

  const ClusterItem({
    required this.clusterId,
    required this.topic,
    required this.size,
    required this.items,
  });

  factory ClusterItem.fromJson(Map<String, dynamic> json) {
    return ClusterItem(
      clusterId: json['cluster_id'] ?? 0,
      topic: json['topic'] ?? '',
      size: json['size'] ?? 0,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => ClusterEntryItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ClusterEntryItem {
  final String entryId;
  final String title;
  final int publishedAt;
  final String feedId;

  const ClusterEntryItem({
    required this.entryId,
    required this.title,
    required this.publishedAt,
    required this.feedId,
  });

  factory ClusterEntryItem.fromJson(Map<String, dynamic> json) {
    return ClusterEntryItem(
      entryId: json['entry_id'] ?? '',
      title: json['title'] ?? '',
      publishedAt: json['published_at'] ?? 0,
      feedId: json['feed_id'] ?? '',
    );
  }
}

class ClusterAnalysis {
  final List<TimelineItem> timeline;
  final ClusterAnalysisResult analysis;
  final Map<String, dynamic> stats;

  const ClusterAnalysis({
    required this.timeline,
    required this.analysis,
    required this.stats,
  });

  factory ClusterAnalysis.fromJson(Map<String, dynamic> json) {
    return ClusterAnalysis(
      timeline:
          (json['timeline'] as List<dynamic>?)
              ?.map((e) => TimelineItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      analysis: ClusterAnalysisResult.fromJson(
        json['analysis'] as Map<String, dynamic>? ?? {},
      ),
      stats: json['stats'] as Map<String, dynamic>? ?? {},
    );
  }
}

class TimelineItem {
  final String id;
  final String title;
  final int publishedAt;
  final String source;
  final String summary;

  const TimelineItem({
    required this.id,
    required this.title,
    required this.publishedAt,
    required this.source,
    required this.summary,
  });

  factory TimelineItem.fromJson(Map<String, dynamic> json) {
    return TimelineItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      publishedAt: json['published_at'] ?? 0,
      source: json['source'] ?? '',
      summary: json['summary'] ?? '',
    );
  }
}

class ClusterAnalysisResult {
  final String? trendPrediction;
  final List<String> keywords;
  final double sentimentScore;
  final String? summary;

  const ClusterAnalysisResult({
    this.trendPrediction,
    this.keywords = const [],
    this.sentimentScore = 0.0,
    this.summary,
  });

  factory ClusterAnalysisResult.fromJson(Map<String, dynamic> json) {
    return ClusterAnalysisResult(
      trendPrediction: json['trend_prediction'],
      keywords:
          (json['keywords'] as List<dynamic>?)?.map((e) => '$e').toList() ?? [],
      sentimentScore: (json['sentiment_score'] ?? 0.0).toDouble(),
      summary: json['summary'],
    );
  }
}
