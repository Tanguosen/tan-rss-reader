import 'package:flutter_test/flutter_test.dart';
import 'package:tan_rss_mobile/core/models/models.dart';

void main() {
  group('Entry Model', () {
    test('fromJson should parse correctly', () {
      final json = {
        'id': '123',
        'feed_id': '456',
        'title': 'Test Title',
        'read': true,
        'starred': false,
      };

      final entry = Entry.fromJson(json);

      expect(entry.id, '123');
      expect(entry.feedId, '456');
      expect(entry.title, 'Test Title');
      expect(entry.read, true);
      expect(entry.starred, false);
    });
  });

  group('Feed Model', () {
    test('fromJson should parse correctly', () {
      final json = {
        'id': 'f1',
        'url': 'https://example.com/rss',
        'title': 'Example Feed',
        'unread_count': 5,
      };

      final feed = Feed.fromJson(json);

      expect(feed.id, 'f1');
      expect(feed.url, 'https://example.com/rss');
      expect(feed.title, 'Example Feed');
      expect(feed.unreadCount, 5);
    });
  });
}
