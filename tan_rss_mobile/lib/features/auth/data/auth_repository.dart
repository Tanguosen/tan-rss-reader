import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/models.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository(ApiClient()));

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  Future<void> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/login',
        data: {
          'username': username,
          'password': password,
        },
      );
      final token = (response.data as Map<String, dynamic>)['access_token'] as String?;
      if (token == null || token.isEmpty) {
        throw Exception('登录失败：服务器返回无效凭证');
      }
      await _apiClient.saveAuthToken(token);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final detail = e.response?.data?['detail'];
      
      if (detail != null) {
        throw Exception(detail.toString());
      }
      if (statusCode == 401) {
        throw Exception('用户名或密码错误');
      }
      if (statusCode == 422) {
        throw Exception('输入格式不正确，请检查用户名和密码');
      }
      throw Exception('登录失败，请检查网络连接后重试');
    }
  }

  Future<void> register({
    required String username,
    required String password,
    String? email,
  }) async {
    try {
      await _apiClient.dio.post(
        '/auth/register',
        data: {
          'username': username,
          'password': password,
          'email': email,
        },
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final detail = e.response?.data?['detail'];
      
      if (detail != null) {
        throw Exception(detail.toString());
      }
      if (statusCode == 409) {
        throw Exception('用户名已被注册');
      }
      if (statusCode == 422) {
        throw Exception('注册信息格式不正确，请检查输入');
      }
      throw Exception('注册失败，请检查网络连接后重试');
    }
  }

  Future<UserProfile> me() async {
    try {
      final response = await _apiClient.dio.get('/me');
      return UserProfile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('获取用户信息失败: ${e.message}');
    }
  }

  Future<void> logout() async {
    await _apiClient.clearAuthToken();
  }

  Future<UserProfile> updateMe({
    String? email,
    String? currentPassword,
    String? newPassword,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (email != null) data['email'] = email;
      if (currentPassword != null) data['current_password'] = currentPassword;
      if (newPassword != null) data['new_password'] = newPassword;

      final response = await _apiClient.dio.patch('/me', data: data);
      return UserProfile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      if (detail != null) {
        throw Exception(detail.toString());
      }
      throw Exception('更新用户信息失败: ${e.message}');
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await _apiClient.getAuthToken();
    final hasSessionFlag = await _apiClient.hasAuthSessionFlag();
    if (token == null || token.isEmpty) {
      return false;
    }
    if (!hasSessionFlag) {
      await _apiClient.clearAuthToken();
      return false;
    }
    if (_isExpiredToken(token)) {
      await _apiClient.clearAuthToken();
      return false;
    }
    return true;
  }

  bool _isExpiredToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! num) return true;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      return expiresAt.isBefore(DateTime.now());
    } catch (_) {
      return true;
    }
  }
}
