import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

class LocalCacheDb {
  static final LocalCacheDb _instance = LocalCacheDb._internal();
  Database? _db;

  factory LocalCacheDb() => _instance;

  LocalCacheDb._internal();

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final databasesPath = await getDatabasesPath();
    final dbPath = p.join(databasesPath, 'tan_rss_mobile_cache.db');
    _db = await openDatabase(
      dbPath,
      version: 2,
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
      },
    );
    return _db!;
  }

  Future<void> cacheEntries(List<Entry> entries) async {
    final db = await _database();
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in entries) {
      batch.insert(
        'entries_cache',
        {
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
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
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
    final queryOrderBy = orderBy == 'published_at' ? 'published_at' : 'inserted_at';
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

  Future<void> cacheFeeds(List<Feed> feeds) async {
    final db = await _database();
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final feed in feeds) {
      batch.insert(
        'feeds_cache',
        {
          'id': feed.id,
          'url': feed.url,
          'title': feed.title,
          'favicon': feed.favicon,
          'unread_count': feed.unreadCount,
          'cached_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Feed>> readFeeds() async {
    final db = await _database();
    final rows = await db.query(
      'feeds_cache',
      orderBy: 'cached_at DESC',
    );
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

  Future<void> cacheAiSummary({
    required String entryId,
    required String language,
    required String summary,
    required List<String> keyPoints,
  }) async {
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
