import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../data/auth_repository.dart';

class AuthState {
  final bool isInitializing;
  final bool isLoggedIn;
  final bool loading;
  final UserProfile? user;
  final String? error;

  const AuthState({
    required this.isInitializing,
    required this.isLoggedIn,
    required this.loading,
    required this.user,
    required this.error,
  });

  const AuthState.initial()
      : isInitializing = true,
        isLoggedIn = false,
        loading = false,
        user = null,
        error = null;

  bool get isAdmin => user?.role == 'admin';

  AuthState copyWith({
    bool? isInitializing,
    bool? isLoggedIn,
    bool? loading,
    UserProfile? user,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      isInitializing: isInitializing ?? this.isInitializing,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      loading: loading ?? this.loading,
      user: user ?? this.user,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState.initial();

  Future<void> restore() async {
    final repository = ref.read(authRepositoryProvider);
    final hasToken = await repository.isLoggedIn();
    
    if (!hasToken) {
      // 没有 Token，直接关闭初始化状态，瞬间显示登录页
      state = state.copyWith(isInitializing: false, isLoggedIn: false);
      return;
    }

    // 乐观登录：只要本地有 Token，立刻放行进入主页（解除白屏/加载圈阻塞）
    state = state.copyWith(isInitializing: false, isLoggedIn: true);

    // 后台静默刷新用户信息
    try {
      final me = await repository.me();
      state = state.copyWith(user: me);
    } catch (e) {
      // 如果是 401，Dio 拦截器会自动触发 logout() 清除状态并踢回登录页
      // 如果是网络问题或超时，保持登录态让用户能看到本地缓存或继续操作，不强行踢出
    }
  }

  Future<void> login(String username, String password) async {
    final repository = ref.read(authRepositoryProvider);
    state = state.copyWith(loading: true, clearError: true);
    try {
      await repository.login(username: username, password: password);
      final me = await repository.me();
      state = state.copyWith(
        isInitializing: false,
        isLoggedIn: true,
        loading: false,
        user: me,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> register(String username, String password, String? email) async {
    final repository = ref.read(authRepositoryProvider);
    state = state.copyWith(loading: true, clearError: true);
    try {
      await repository.register(username: username, password: password, email: email);
      await repository.login(username: username, password: password);
      final me = await repository.me();
      state = state.copyWith(
        isInitializing: false,
        isLoggedIn: true,
        loading: false,
        user: me,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    final repository = ref.read(authRepositoryProvider);
    await repository.logout();
    state = const AuthState(
      isInitializing: false,
      isLoggedIn: false,
      loading: false,
      user: null,
      error: null,
    );
  }

  Future<void> updateEmail(String newEmail) async {
    final repository = ref.read(authRepositoryProvider);
    state = state.copyWith(loading: true, clearError: true);
    try {
      final updated = await repository.updateMe(email: newEmail);
      state = state.copyWith(
        user: updated,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> updatePassword(String currentPassword, String newPassword) async {
    final repository = ref.read(authRepositoryProvider);
    state = state.copyWith(loading: true, clearError: true);
    try {
      final updated = await repository.updateMe(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(
        user: updated,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
