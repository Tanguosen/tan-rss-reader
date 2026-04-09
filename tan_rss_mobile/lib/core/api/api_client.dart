import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  static const String defaultBaseUrl = 'http://art.xshxy.cn/api';
  static const String authTokenKey = 'auth_token';
  static const String authSessionKey = 'auth_session_active';
  static const String desktopAuthTokenKey = 'desktop_auth_token';
  late Dio dio;
  final _storage = const FlutterSecureStorage();

  void Function()? onUnauthorized;

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: defaultBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 120), // AI生成需要较长时间
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await getAuthToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            await clearAuthToken();
            onUnauthorized?.call();
          }
          return handler.next(e);
        },
      ),
    );
  }

  String get baseUrl => dio.options.baseUrl;

  bool get _usePrefsForTokenStorage =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  void setBaseUrl(String value) {
    dio.options.baseUrl = value.trim();
  }

  Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    if (_usePrefsForTokenStorage) {
      await prefs.setString(desktopAuthTokenKey, token);
    } else {
      await _storage.write(key: authTokenKey, value: token);
    }
    await prefs.setBool(authSessionKey, true);
  }

  Future<String?> getAuthToken() async {
    if (_usePrefsForTokenStorage) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(desktopAuthTokenKey);
    }
    return _storage.read(key: authTokenKey);
  }

  Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (_usePrefsForTokenStorage) {
      await prefs.remove(desktopAuthTokenKey);
    } else {
      await _storage.delete(key: authTokenKey);
    }
    await prefs.remove(authSessionKey);
  }

  Future<bool> hasAuthSessionFlag() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(authSessionKey) ?? false;
  }

  /// Decode JWT and return expiry DateTime, or null if invalid.
  Future<DateTime?> getTokenExpiry() async {
    final token = await getAuthToken();
    if (token == null || token.isEmpty) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = payload['exp'];
      if (exp is int) return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Returns true if the stored token is expired.
  Future<bool> isTokenExpired() async {
    final expiry = await getTokenExpiry();
    if (expiry == null) return true;
    return DateTime.now().isAfter(expiry);
  }

  /// Returns true if the token will expire within [threshold].
  Future<bool> isTokenExpiringSoon({
    Duration threshold = const Duration(hours: 1),
  }) async {
    final expiry = await getTokenExpiry();
    if (expiry == null) return true;
    return DateTime.now().add(threshold).isAfter(expiry);
  }
}
