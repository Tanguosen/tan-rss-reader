import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

class LocalCacheDb {
  static final LocalCacheDb _instance = LocalCacheDb._internal();
  Database? _db;
  final Map<String, Map<String, Object?>> _memoryEntries = {};
  final Map<String, Map<String, Object?>> _memoryFeeds = {};
  final Map<String, Map<String, Object?>> _memoryChannels = {};
  final Map<String, Set<String>> _memoryChannelEntries = {};
  final Map<String, Map<String, Object?>> _memoryEntryAi = {};
  final Map<String, Map<String, Object?>> _memoryTextTranslations = {};

  factory LocalCacheDb() => _instance;

  LocalCacheDb._internal();

  bool get _useMemoryCache => kIsWeb;

  String _channelScopeKey(String scope, String id) => '$scope::$id';
  String _entryAiKey(String entryId, String language) => '$entryId::$language';
  String _textTranslationKey(String sourceText, String language) =>
      '$language::$sourceText';

  Map<String, Object?> _entryToMap(Entry entry, int now) => {
    'id': entry.id,
    'feed_id': entry.feedId,
    'feed_title': entry.feedTitle,
    'title': entry.title,
    'url': entry.url,
    'author': entry.author,
    'summary': entry.summary,
    'content': entry.content,
    'published_at': entry.publishedAt,
    'inserted_at': entry.insertedAt,
    'is_read': entry.read ? 1 : 0,
    'is_starred': entry.starred ? 1 : 0,
    'cached_at': now,
  };

  Entry _entryFromMap(Map<String, Object?> json) => Entry(
    id: '${json['id'] ?? ''}',
    feedId: '${json['feed_id'] ?? ''}',
    feedTitle: json['feed_title'] as String?,
    title: json['title'] as String?,
    url: json['url'] as String?,
    author: json['author'] as String?,
    summary: json['summary'] as String?,
    content: json['content'] as String?,
    publishedAt: json['published_at'] as String?,
    insertedAt: json['inserted_at'] as String?,
    read: (json['is_read'] as int? ?? 0) == 1,
    starred: (json['is_starred'] as int? ?? 0) == 1,
  );

  Map<String, Object?> _feedToMap(Feed feed, int now) => {
    'id': feed.id,
    'url': feed.url,
    'title': feed.title,
    'favicon': feed.favicon,
    'unread_count': feed.unreadCount,
    'cached_at': now,
  };

  Feed _feedFromMap(Map<String, Object?> json) => Feed(
    id: '${json['id'] ?? ''}',
    url: '${json['url'] ?? ''}',
    title: json['title'] as String?,
    favicon: json['favicon'] as String?,
    unreadCount: json['unread_count'] as int?,
  );

  Map<String, Object?> _channelToMap(Channel channel, String scope, int now) =>
      {
        'id': channel.id,
        'scope': scope,
        'name': channel.name,
        'is_public': channel.isPublic ? 1 : 0,
        'description': channel.description,
        'icon_url': channel.iconUrl,
        'cover_url': channel.coverUrl,
        'kind': channel.kind,
        'category_id': channel.categoryId,
        'owner_id': channel.ownerId,
        'created_at': channel.createdAt,
        'updated_at': channel.updatedAt,
        'cached_at': now,
      };

  Channel _channelFromMap(Map<String, Object?> json) => Channel(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    isPublic: (json['is_public'] as int? ?? 0) == 1,
    description: json['description'] as String?,
    iconUrl: json['icon_url'] as String?,
    coverUrl: json['cover_url'] as String?,
    kind: json['kind'] as String?,
    categoryId: json['category_id'] as String?,
    ownerId: json['owner_id'] as String?,
    createdAt: json['created_at'] as String?,
    updatedAt: json['updated_at'] as String?,
  );

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final databasesPath = await getDatabasesPath();
    final dbPath = p.join(databasesPath, 'tan_rss_mobile_cache.db');
    _db = await openDatabase(
      dbPath,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE entries_cache(
            id TEXT PRIMARY KEY,
            feed_id TEXT,
            feed_title TEXT,
            title TEXT,
            url TEXT,
            author TEXT,
            summary TEXT,
            content TEXT,
            published_at TEXT,
            inserted_at TEXT,
            is_read INTEGER,
            is_starred INTEGER,
            cached_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE feeds_cache(
            id TEXT PRIMARY KEY,
            url TEXT,
            title TEXT,
            favicon TEXT,
            unread_count INTEGER,
            cached_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE entry_ai_cache(
            entry_id TEXT NOT NULL,
            language TEXT NOT NULL,
            summary TEXT,
            key_points_json TEXT,
            translated_title TEXT,
            translated_content TEXT,
            updated_at INTEGER,
            PRIMARY KEY(entry_id, language)
          )
        ''');
        await db.execute('''
          CREATE TABLE text_translation_cache(
            source_text TEXT NOT NULL,
            language TEXT NOT NULL,
            translated_text TEXT,
            updated_at INTEGER,
            PRIMARY KEY(source_text, language)
          )
        ''');
        await db.execute('''
          CREATE TABLE channels_cache(
            id TEXT NOT NULL,
            scope TEXT NOT NULL,
            name TEXT,
            is_public INTEGER,
            description TEXT,
            icon_url TEXT,
            cover_url TEXT,
            kind TEXT,
            category_id TEXT,
            owner_id TEXT,
            created_at TEXT,
            updated_at TEXT,
            cached_at INTEGER,
            PRIMARY KEY(id, scope)
          )
        ''');
        await db.execute('''
          CREATE TABLE channel_entries_cache(
            channel_id TEXT NOT NULL,
            entry_id TEXT NOT NULL,
            cached_at INTEGER,
            PRIMARY KEY(channel_id, entry_id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS entry_ai_cache(
              entry_id TEXT NOT NULL,
              language TEXT NOT NULL,
              summary TEXT,
              key_points_json TEXT,
              translated_title TEXT,
              translated_content TEXT,
              updated_at INTEGER,
            PRIMARY KEY(entry_id, language)
          )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS text_translation_cache(
              source_text TEXT NOT NULL,
              language TEXT NOT NULL,
              translated_text TEXT,
              updated_at INTEGER,
              PRIMARY KEY(source_text, language)
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS channels_cache(
              id TEXT NOT NULL,
              scope TEXT NOT NULL,
              name TEXT,
              is_public INTEGER,
              description TEXT,
              icon_url TEXT,
              cover_url TEXT,
              kind TEXT,
              category_id TEXT,
              owner_id TEXT,
              created_at TEXT,
              updated_at TEXT,
              cached_at INTEGER,
              PRIMARY KEY(id, scope)
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS channel_entries_cache(
              channel_id TEXT NOT NULL,
              entry_id TEXT NOT NULL,
              cached_at INTEGER,
              PRIMARY KEY(channel_id, entry_id)
            )
          ''');
        }
      },
    );
    return _db!;
  }

  Future<void> cacheEntries(List<Entry> entries) async {
    if (_useMemoryCache) {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final entry in entries) {
        _memoryEntries[entry.id] = _entryToMap(entry, now);
      }
      return;
    }
    final db = await _database();
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in entries) {
      batch.insert('entries_cache', {
        'id': entry.id,
        'feed_id': entry.feedId,
        'feed_title': entry.feedTitle,
        'title': entry.title,
        'url': entry.url,
        'author': entry.author,
        'summary': entry.summary,
        'content': entry.content,
        'published_at': entry.publishedAt,
        'inserted_at': entry.insertedAt,
        'is_read': entry.read ? 1 : 0,
        'is_starred': entry.starred ? 1 : 0,
        'cached_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Entry>> readEntries({
    String? feedId,
    bool unreadOnly = false,
    bool starredOnly = false,
    int limit = 50,
    int offset = 0,
    String? searchText,
    String orderBy = 'inserted_at',
    String order = 'desc',
  }) async {
    if (_useMemoryCache) {
      final normalizedSearch = searchText?.trim().toLowerCase();
      final descending = order.toLowerCase() != 'asc';
      final items = _memoryEntries.values
          .where((json) {
            if (feedId != null &&
                feedId.isNotEmpty &&
                json['feed_id'] != feedId) {
              return false;
            }
            if (unreadOnly && (json['is_read'] as int? ?? 0) == 1) {
              return false;
            }
            if (starredOnly && (json['is_starred'] as int? ?? 0) != 1) {
              return false;
            }
            if (normalizedSearch != null && normalizedSearch.isNotEmpty) {
              final haystacks = [
                json['title'],
                json['summary'],
                json['feed_title'],
              ].map((value) => '${value ?? ''}'.toLowerCase());
              if (!haystacks.any((value) => value.contains(normalizedSearch))) {
                return false;
              }
            }
            return true;
          })
          .map((json) => Map<String, Object?>.from(json))
          .toList();

      String sortValue(Map<String, Object?> json) {
        final primary = orderBy == 'published_at'
            ? (json['published_at'] as String? ?? '')
            : (json['inserted_at'] as String? ?? '');
        if (primary.isNotEmpty) return primary;
        return (json['inserted_at'] as String? ?? '');
      }

      items.sort((a, b) {
        final compare = sortValue(a).compareTo(sortValue(b));
        return descending ? -compare : compare;
      });
      final sliced = items.skip(offset).take(limit);
      return sliced.map(_entryFromMap).toList();
    }
    final db = await _database();
    final where = <String>[];
    final args = <Object?>[];
    if (feedId != null && feedId.isNotEmpty) {
      where.add('feed_id = ?');
      args.add(feedId);
    }
    if (unreadOnly) {
      where.add('is_read = 0');
    }
    if (starredOnly) {
      where.add('is_starred = 1');
    }
    if (searchText != null && searchText.trim().isNotEmpty) {
      where.add('(title LIKE ? OR summary LIKE ? OR feed_title LIKE ?)');
      final keyword = '%${searchText.trim()}%';
      args.addAll([keyword, keyword, keyword]);
    }
    final queryOrderBy = orderBy == 'published_at'
        ? 'published_at'
        : 'inserted_at';
    final rows = await db.query(
      'entries_cache',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: '$queryOrderBy ${order.toUpperCase()}',
      limit: limit,
      offset: offset,
    );
    return rows
        .map(
          (json) => Entry(
            id: '${json['id'] ?? ''}',
            feedId: '${json['feed_id'] ?? ''}',
            feedTitle: json['feed_title'] as String?,
            title: json['title'] as String?,
            url: json['url'] as String?,
            author: json['author'] as String?,
            summary: json['summary'] as String?,
            content: json['content'] as String?,
            publishedAt: json['published_at'] as String?,
            insertedAt: json['inserted_at'] as String?,
            read: (json['is_read'] as int? ?? 0) == 1,
            starred: (json['is_starred'] as int? ?? 0) == 1,
          ),
        )
        .toList();
  }

  Future<Entry?> readEntry(String id) async {
    if (_useMemoryCache) {
      final json = _memoryEntries[id];
      return json == null ? null : _entryFromMap(json);
    }
    final db = await _database();
    final rows = await db.query(
      'entries_cache',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final json = rows.first;
    return Entry(
      id: '${json['id'] ?? ''}',
      feedId: '${json['feed_id'] ?? ''}',
      feedTitle: json['feed_title'] as String?,
      title: json['title'] as String?,
      url: json['url'] as String?,
      author: json['author'] as String?,
      summary: json['summary'] as String?,
      content: json['content'] as String?,
      publishedAt: json['published_at'] as String?,
      insertedAt: json['inserted_at'] as String?,
      read: (json['is_read'] as int? ?? 0) == 1,
      starred: (json['is_starred'] as int? ?? 0) == 1,
    );
  }

  Future<void> cacheFeeds(List<Feed> feeds) async {
    if (_useMemoryCache) {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final feed in feeds) {
        _memoryFeeds[feed.id] = _feedToMap(feed, now);
      }
      return;
    }
    final db = await _database();
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final feed in feeds) {
      batch.insert('feeds_cache', {
        'id': feed.id,
        'url': feed.url,
        'title': feed.title,
        'favicon': feed.favicon,
        'unread_count': feed.unreadCount,
        'cached_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Feed>> readFeeds() async {
    if (_useMemoryCache) {
      final items =
          _memoryFeeds.values
              .map((json) => Map<String, Object?>.from(json))
              .toList()
            ..sort(
              (a, b) => ((b['cached_at'] as int?) ?? 0).compareTo(
                (a['cached_at'] as int?) ?? 0,
              ),
            );
      return items.map(_feedFromMap).toList();
    }
    final db = await _database();
    final rows = await db.query('feeds_cache', orderBy: 'cached_at DESC');
    return rows
        .map(
          (json) => Feed(
            id: '${json['id'] ?? ''}',
            url: '${json['url'] ?? ''}',
            title: json['title'] as String?,
            favicon: json['favicon'] as String?,
            unreadCount: json['unread_count'] as int?,
          ),
        )
        .toList();
  }

  Future<void> cacheChannels(
    List<Channel> channels, {
    required String scope,
  }) async {
    if (_useMemoryCache) {
      final now = DateTime.now().millisecondsSinceEpoch;
      _memoryChannels.removeWhere((key, _) => key.startsWith('$scope::'));
      for (final channel in channels) {
        _memoryChannels[_channelScopeKey(scope, channel.id)] = _channelToMap(
          channel,
          scope,
          now,
        );
      }
      return;
    }
    final db = await _database();
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    batch.delete('channels_cache', where: 'scope = ?', whereArgs: [scope]);
    for (final channel in channels) {
      batch.insert('channels_cache', {
        'id': channel.id,
        'scope': scope,
        'name': channel.name,
        'is_public': channel.isPublic ? 1 : 0,
        'description': channel.description,
        'icon_url': channel.iconUrl,
        'cover_url': channel.coverUrl,
        'kind': channel.kind,
        'category_id': channel.categoryId,
        'owner_id': channel.ownerId,
        'created_at': channel.createdAt,
        'updated_at': channel.updatedAt,
        'cached_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Channel>> readChannels({required String scope}) async {
    if (_useMemoryCache) {
      final items =
          _memoryChannels.entries
              .where((entry) => entry.key.startsWith('$scope::'))
              .map((entry) => Map<String, Object?>.from(entry.value))
              .toList()
            ..sort(
              (a, b) => ((b['cached_at'] as int?) ?? 0).compareTo(
                (a['cached_at'] as int?) ?? 0,
              ),
            );
      return items.map(_channelFromMap).toList();
    }
    final db = await _database();
    final rows = await db.query(
      'channels_cache',
      where: 'scope = ?',
      whereArgs: [scope],
      orderBy: 'cached_at DESC',
    );
    return rows
        .map(
          (json) => Channel(
            id: '${json['id'] ?? ''}',
            name: '${json['name'] ?? ''}',
            isPublic: (json['is_public'] as int? ?? 0) == 1,
            description: json['description'] as String?,
            iconUrl: json['icon_url'] as String?,
            coverUrl: json['cover_url'] as String?,
            kind: json['kind'] as String?,
            categoryId: json['category_id'] as String?,
            ownerId: json['owner_id'] as String?,
            createdAt: json['created_at'] as String?,
            updatedAt: json['updated_at'] as String?,
          ),
        )
        .toList();
  }

  Future<void> cacheChannelEntries(
    String channelId,
    List<Entry> entries,
  ) async {
    if (_useMemoryCache) {
      await cacheEntries(entries);
      _memoryChannelEntries[channelId] = entries
          .map((entry) => entry.id)
          .toSet();
      return;
    }
    final db = await _database();
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    await cacheEntries(entries);
    batch.delete(
      'channel_entries_cache',
      where: 'channel_id = ?',
      whereArgs: [channelId],
    );
    for (final entry in entries) {
      batch.insert('channel_entries_cache', {
        'channel_id': channelId,
        'entry_id': entry.id,
        'cached_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Entry>> readChannelEntries(
    String channelId, {
    bool unreadOnly = false,
    int limit = 100,
    int offset = 0,
    String orderBy = 'inserted_at',
    String order = 'desc',
  }) async {
    if (_useMemoryCache) {
      final descending = order.toLowerCase() != 'asc';
      final ids = _memoryChannelEntries[channelId] ?? const <String>{};
      final items = ids
          .map((id) => _memoryEntries[id])
          .whereType<Map<String, Object?>>()
          .where((json) => !unreadOnly || (json['is_read'] as int? ?? 0) == 0)
          .map((json) => Map<String, Object?>.from(json))
          .toList();

      String sortValue(Map<String, Object?> json) {
        final primary = orderBy == 'published_at'
            ? (json['published_at'] as String? ?? '')
            : (json['inserted_at'] as String? ?? '');
        if (primary.isNotEmpty) return primary;
        return (json['inserted_at'] as String? ?? '');
      }

      items.sort((a, b) {
        final compare = sortValue(a).compareTo(sortValue(b));
        return descending ? -compare : compare;
      });
      final sliced = items.skip(offset).take(limit);
      return sliced.map(_entryFromMap).toList();
    }
    final db = await _database();
    final sortField = orderBy == 'published_at'
        ? 'e.published_at'
        : 'e.inserted_at';
    final unreadClause = unreadOnly ? 'AND e.is_read = 0' : '';
    final rows = await db.rawQuery(
      '''
      SELECT e.*
      FROM channel_entries_cache c
      JOIN entries_cache e ON e.id = c.entry_id
      WHERE c.channel_id = ?
      $unreadClause
      ORDER BY $sortField ${order.toUpperCase()}
      LIMIT ? OFFSET ?
      ''',
      [channelId, limit, offset],
    );
    return rows
        .map(
          (json) => Entry(
            id: '${json['id'] ?? ''}',
            feedId: '${json['feed_id'] ?? ''}',
            feedTitle: json['feed_title'] as String?,
            title: json['title'] as String?,
            url: json['url'] as String?,
            author: json['author'] as String?,
            summary: json['summary'] as String?,
            content: json['content'] as String?,
            publishedAt: json['published_at'] as String?,
            insertedAt: json['inserted_at'] as String?,
            read: (json['is_read'] as int? ?? 0) == 1,
            starred: (json['is_starred'] as int? ?? 0) == 1,
          ),
        )
        .toList();
  }

  Future<void> cacheAiSummary({
    required String entryId,
    required String language,
    required String summary,
    required List<String> keyPoints,
  }) async {
    if (_useMemoryCache) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final key = _entryAiKey(entryId, language);
      final base = Map<String, Object?>.from(
        _memoryEntryAi[key] ?? {'entry_id': entryId, 'language': language},
      );
      base.addAll({
        'summary': summary,
        'key_points_json': keyPoints.join('\n'),
        'updated_at': now,
      });
      _memoryEntryAi[key] = base;
      return;
    }
    final db = await _database();
    await _upsertAiCache(
      db: db,
      entryId: entryId,
      language: language,
      updates: {
        'summary': summary,
        'key_points_json': keyPoints.join('\n'),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<AiSummaryData?> readAiSummary({
    required String entryId,
    required String language,
  }) async {
    if (_useMemoryCache) {
      final row = _memoryEntryAi[_entryAiKey(entryId, language)];
      if (row == null) return null;
      final summary = row['summary'] as String?;
      if (summary == null || summary.isEmpty) return null;
      final keyPointsRaw = (row['key_points_json'] as String?) ?? '';
      final keyPoints = keyPointsRaw.isEmpty
          ? <String>[]
          : keyPointsRaw.split('\n').where((e) => e.trim().isNotEmpty).toList();
      return AiSummaryData(
        language: language,
        summary: summary,
        keyPoints: keyPoints,
      );
    }
    final db = await _database();
    final rows = await db.query(
      'entry_ai_cache',
      where: 'entry_id = ? AND language = ?',
      whereArgs: [entryId, language],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final summary = row['summary'] as String?;
    if (summary == null || summary.isEmpty) return null;
    final keyPointsRaw = (row['key_points_json'] as String?) ?? '';
    final keyPoints = keyPointsRaw.isEmpty
        ? <String>[]
        : keyPointsRaw.split('\n').where((e) => e.trim().isNotEmpty).toList();
    return AiSummaryData(
      language: language,
      summary: summary,
      keyPoints: keyPoints,
    );
  }

  Future<void> cacheTranslatedTitle({
    required String entryId,
    required String language,
    required String title,
  }) async {
    if (_useMemoryCache) {
      final key = _entryAiKey(entryId, language);
      final base = Map<String, Object?>.from(
        _memoryEntryAi[key] ?? {'entry_id': entryId, 'language': language},
      );
      base.addAll({
        'translated_title': title,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
      _memoryEntryAi[key] = base;
      return;
    }
    final db = await _database();
    await _upsertAiCache(
      db: db,
      entryId: entryId,
      language: language,
      updates: {
        'translated_title': title,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<String?> readTranslatedTitle({
    required String entryId,
    required String language,
  }) async {
    if (_useMemoryCache) {
      final title =
          _memoryEntryAi[_entryAiKey(entryId, language)]?['translated_title']
              as String?;
      if (title == null || title.isEmpty) return null;
      return title;
    }
    final db = await _database();
    final rows = await db.query(
      'entry_ai_cache',
      columns: ['translated_title'],
      where: 'entry_id = ? AND language = ?',
      whereArgs: [entryId, language],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final title = rows.first['translated_title'] as String?;
    if (title == null || title.isEmpty) return null;
    return title;
  }

  Future<void> cacheTranslatedContent({
    required String entryId,
    required String language,
    required String content,
  }) async {
    if (_useMemoryCache) {
      final key = _entryAiKey(entryId, language);
      final base = Map<String, Object?>.from(
        _memoryEntryAi[key] ?? {'entry_id': entryId, 'language': language},
      );
      base.addAll({
        'translated_content': content,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
      _memoryEntryAi[key] = base;
      return;
    }
    final db = await _database();
    await _upsertAiCache(
      db: db,
      entryId: entryId,
      language: language,
      updates: {
        'translated_content': content,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<String?> readTranslatedContent({
    required String entryId,
    required String language,
  }) async {
    if (_useMemoryCache) {
      final content =
          _memoryEntryAi[_entryAiKey(entryId, language)]?['translated_content']
              as String?;
      if (content == null || content.isEmpty) return null;
      return content;
    }
    final db = await _database();
    final rows = await db.query(
      'entry_ai_cache',
      columns: ['translated_content'],
      where: 'entry_id = ? AND language = ?',
      whereArgs: [entryId, language],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final content = rows.first['translated_content'] as String?;
    if (content == null || content.isEmpty) return null;
    return content;
  }

  Future<void> cacheTranslatedText({
    required String sourceText,
    required String language,
    required String translatedText,
  }) async {
    if (_useMemoryCache) {
      _memoryTextTranslations[_textTranslationKey(sourceText, language)] = {
        'translated_text': translatedText,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };
      return;
    }
    final db = await _database();
    await db.insert('text_translation_cache', {
      'source_text': sourceText,
      'language': language,
      'translated_text': translatedText,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> readTranslatedText({
    required String sourceText,
    required String language,
  }) async {
    if (_useMemoryCache) {
      final translated =
          _memoryTextTranslations[_textTranslationKey(
                sourceText,
                language,
              )]?['translated_text']
              as String?;
      if (translated == null || translated.isEmpty) return null;
      return translated;
    }
    final db = await _database();
    final rows = await db.query(
      'text_translation_cache',
      columns: ['translated_text'],
      where: 'source_text = ? AND language = ?',
      whereArgs: [sourceText, language],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final translated = rows.first['translated_text'] as String?;
    if (translated == null || translated.isEmpty) return null;
    return translated;
  }

  Future<void> _upsertAiCache({
    required Database db,
    required String entryId,
    required String language,
    required Map<String, Object?> updates,
  }) async {
    final rows = await db.query(
      'entry_ai_cache',
      where: 'entry_id = ? AND language = ?',
      whereArgs: [entryId, language],
      limit: 1,
    );
    final base = <String, Object?>{
      'entry_id': entryId,
      'language': language,
      'summary': null,
      'key_points_json': null,
      'translated_title': null,
      'translated_content': null,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (rows.isNotEmpty) {
      base.addAll(rows.first);
    }
    base.addAll(updates);
    await db.insert(
      'entry_ai_cache',
      base,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
