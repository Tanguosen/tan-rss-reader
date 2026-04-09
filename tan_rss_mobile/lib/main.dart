import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'core/api/api_client.dart';
import 'features/home/presentation/home_shell_screen.dart';
import 'features/auth/presentation/auth_providers.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/feed/presentation/feed_providers.dart';
import 'l10n/app_localizations.dart';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);

class LocaleNotifier extends Notifier<Locale?> {
  static const _key = 'app_locale';

  @override
  Locale? build() {
    _load();
    return null; // null = follow system
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value != null && value.isNotEmpty) {
      final parts = value.split('_');
      state = parts.length == 2 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
    }
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      final value = locale.countryCode != null
          ? '${locale.languageCode}_${locale.countryCode}'
          : locale.languageCode;
      await prefs.setString(_key, value);
    }
  }
}

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value != null) {
      state = ThemeMode.values.firstWhere(
        (e) => e.name == value,
        orElse: () => ThemeMode.system,
      );
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.windows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  final prefs = await SharedPreferences.getInstance();
  final savedBaseUrl = prefs.getString('api_base_url');
  if (savedBaseUrl != null && savedBaseUrl.trim().isNotEmpty) {
    ApiClient().setBaseUrl(savedBaseUrl.trim());
  }
  timeago.setLocaleMessages('zh', timeago.ZhCnMessages());
  timeago.setLocaleMessages('zh_CN', timeago.ZhCnMessages());
  timeago.setLocaleMessages('zh_TW', timeago.ZhMessages());
  timeago.setLocaleMessages('ja', timeago.JaMessages());
  timeago.setLocaleMessages('ko', timeago.KoMessages());
  timeago.setLocaleMessages('fr', timeago.FrMessages());
  timeago.setLocaleMessages('de', timeago.DeMessages());
  timeago.setLocaleMessages('es', timeago.EsMessages());
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    ApiClient().onUnauthorized = () {
      ref.read(authProvider.notifier).logout();
    };
    Future.microtask(() => ref.read(authProvider.notifier).restore());
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceSettingsProvider);
    final authState = ref.watch(authProvider);
    final appLocale = ref.watch(localeProvider);

    ThemeMode resolvedMode = ThemeMode.system;
    if (appearance.themeMode == 'light') resolvedMode = ThemeMode.light;
    if (appearance.themeMode == 'dark') resolvedMode = ThemeMode.dark;

    Color seedColor = const Color(0xFFB08968); // default dynamic/brown
    switch (appearance.themeColor) {
      case 'blue':
        seedColor = Colors.blue;
        break;
      case 'indigo':
        seedColor = Colors.indigo;
        break;
      case 'purple':
        seedColor = Colors.purple;
        break;
      case 'pink':
        seedColor = Colors.pink;
        break;
      case 'red':
        seedColor = Colors.red;
        break;
      case 'orange':
        seedColor = Colors.orange;
        break;
      case 'yellow':
        seedColor = Colors.yellow;
        break;
      case 'lime':
        seedColor = Colors.lime;
        break;
      case 'green':
        seedColor = Colors.green;
        break;
      case 'teal':
        seedColor = Colors.teal;
        break;
      case 'cyan':
        seedColor = Colors.cyan;
        break;
    }

    ColorScheme _buildScheme(Brightness brightness) {
      final hsl = HSLColor.fromColor(seedColor);
      final effectiveSeed = switch (appearance.colorSchemeStyle) {
        'fidelity' => seedColor,
        'neutral' => hsl.withSaturation(0.12).toColor(),
        _ =>
          hsl.withSaturation((hsl.saturation * 0.65).clamp(0.0, 1.0)).toColor(),
      };
      return ColorScheme.fromSeed(
        seedColor: effectiveSeed,
        brightness: brightness,
      );
    }

    final creamScheme = _buildScheme(Brightness.light).copyWith(
      surface: const Color(0xFFFFFBF5),
      surfaceContainer: const Color(0xFFFDF3E4),
      surfaceContainerHigh: const Color(0xFFF9ECD8),
      surfaceContainerHighest: const Color(0xFFF6E6CF),
      primary: appearance.themeColor == 'dynamic'
          ? const Color(0xFF6D4C41)
          : seedColor,
      onPrimary: Colors.white,
    );

    var darkScheme = _buildScheme(Brightness.dark);

    if (appearance.amoledBlack) {
      darkScheme = darkScheme.copyWith(
        surface: Colors.black,
        surfaceContainer: const Color(0xFF121212),
        surfaceContainerHigh: const Color(0xFF1E1E1E),
        surfaceContainerHighest: const Color(0xFF2C2C2C),
      );
    }

    return MaterialApp(
      title: 'TAN RSS Reader',
      themeMode: resolvedMode,
      locale: appLocale,
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      localeResolutionCallback: (locale, supported) {
        if (appLocale != null) return appLocale;
        if (locale != null) {
          for (final s in supported) {
            if (s.languageCode == locale.languageCode) return s;
          }
        }
        return supported.first;
      },
      theme: ThemeData(
        colorScheme: creamScheme,
        scaffoldBackgroundColor: const Color(0xFFFFFBF5),
        canvasColor: const Color(0xFFFFFBF5),
        cardColor: const Color(0xFFFFF5E8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFBF5),
          foregroundColor: Color(0xFF3E2F25),
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        scaffoldBackgroundColor: appearance.amoledBlack
            ? Colors.black
            : darkScheme.surface,
        canvasColor: appearance.amoledBlack ? Colors.black : darkScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: appearance.amoledBlack
              ? Colors.black
              : darkScheme.surface,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: authState.isInitializing
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (authState.isLoggedIn
                ? const HomeShellScreen()
                : const LoginScreen()),
    );
  }
}
