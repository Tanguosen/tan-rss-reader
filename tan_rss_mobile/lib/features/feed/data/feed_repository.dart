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
    this.orderBy = 'created_at',
    this.order = 'desc',
    this.searchText = '',
    this.dateRange = 'all',
  });
}

class FeedRepository {
  final ApiClient _apiClient;
  final LocalCacheDb _cache = LocalCacheDb();

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
    try {
      final params = <String, dynamic>{
        'limit': query.limit,
        'offset': query.offset,
        'order_by': query.orderBy,
        'order': query.order,
      };
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
        orderBy: query.orderBy,
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
      return Entry.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('加载文章失败：${e.message}');
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
      return (response.data as List)
          .map((e) => Channel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('加载频道广场失败：${e.message}');
    }
  }

  Future<Channel> createChannel({
    required String name,
    String? description,
    bool isPublic = true,
    String? iconUrl,
  }) async {
    try {
      final data = {
        'name': name,
        'description': description,
        'is_public': isPublic,
      };
      if (iconUrl != null) data['icon_url'] = iconUrl;
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
      return (response.data as List).map((e) => Entry.fromJson(e)).toList();
    } on DioException catch (e) {
      throw Exception('加载收藏文章失败：${e.message}');
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
    try {
      final response = await _apiClient.dio.post(
        '/ai/translate-text',
        data: {'text': text, 'target_language': language},
      );
      final data = response.data as Map<String, dynamic>;
      return (data['translated'] ?? text) as String;
    } on DioException {
      return text; // 翻译失败时返回原文
    }
  }

  Future<List<Channel>> getMySubscriptions() async {
    try {
      final response = await _apiClient.dio.get('/me/subscriptions');
      return (response.data as List)
          .map((e) => Channel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('加载订阅列表失败：${e.message}');
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
    try {
      final params = <String, dynamic>{
        'limit': limit,
        'offset': offset,
        'order_by': timeField == 'published_at' ? 'published_at' : 'created_at',
        'order': 'desc',
      };
      if (unreadOnly == true) params['unread_only'] = true;
      if (dateRange != null && dateRange != 'all')
        params['date_range'] = dateRange;
      final response = await _apiClient.dio.get(
        '/channels/$channelId/entries',
        queryParameters: params,
      );
      return (response.data as List)
          .map((e) => Entry.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('加载频道文章失败：${e.message}');
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
      final response = await _apiClient.dio.get(
        '/vector/search',
        queryParameters: {'query': query, 'limit': limit},
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

  Stream<String> generateDeepDiveStream(String entryId) async* {
    try {
      final response = await _apiClient.dio.post(
        '/ai/deep-dive',
        data: {'entry_id': entryId},
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
