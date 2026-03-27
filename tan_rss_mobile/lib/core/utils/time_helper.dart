import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

class TimeHelper {
  static String formatTimeAgo(String? dateStr, {Locale? locale}) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final langCode = locale?.languageCode ?? 'zh';
      final timeagoLocale = _toTimeagoLocale(langCode);
      return timeago.format(DateTime.parse(dateStr), locale: timeagoLocale);
    } catch (_) {
      return '';
    }
  }

  static String formatTimeAgoFromDateTime(DateTime date, {Locale? locale}) {
    try {
      final langCode = locale?.languageCode ?? 'zh';
      final timeagoLocale = _toTimeagoLocale(langCode);
      return timeago.format(date, locale: timeagoLocale);
    } catch (_) {
      return '';
    }
  }

  static String _toTimeagoLocale(String langCode) {
    switch (langCode) {
      case 'zh':
        return 'zh';
      case 'en':
        return 'en';
      case 'ja':
        return 'ja';
      case 'ko':
        return 'ko';
      case 'fr':
        return 'fr';
      case 'de':
        return 'de';
      case 'es':
        return 'es';
      default:
        return 'en';
    }
  }

  static String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  static String formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
