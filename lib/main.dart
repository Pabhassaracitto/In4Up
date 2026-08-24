import 'dart:async';
import 'package:device_preview/device_preview.dart';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in4up/l10n/app_localizations.dart';
import 'package:in4up/screens/memory_mode/controllers/memory_controller.dart';
import 'package:in4up/screens/understand_mode/understand_provider.dart';
import 'package:in4up/services/storage_service.dart';
import 'package:in4up_ai/in4up_ai.dart';
import 'package:in4up_stt/models/stt_config.dart';
import 'package:in4up_stt/models/stt_model_info.dart';
import 'package:in4up_stt/stt_service_facade.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/responsive/app_responsive.dart';
import 'features/learn_by_heart/controllers/learn_by_heart_provider.dart';
import 'features/shadowing/providers/shadowing_provider.dart';
import 'firebase_options.dart';
import 'providers/audio_library_provider.dart';
import 'providers/focus_provider.dart';
import 'providers/karaoke_settings_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/player_provider.dart';
import 'providers/soundlist_provider.dart';
import 'providers/text_provider.dart';
import 'providers/vocabulary_provider.dart';
import 'providers/waveform_provider.dart';
import 'screens/main_shell.dart';
import 'screens/memory_mode/memory_provider.dart';
import 'screens/read_mode/services/playback_controller.dart';
import 'screens/read_mode/services/playback_engine.dart';
import 'screens/read_mode/services/tts_notification_service.dart';
import 'screens/read_mode/services/tts_service.dart';
import 'screens/read_mode/services/tts_service_impl.dart';
import 'services/reader_display_settings.dart';
import 'services/whisper_service.dart';

bool isFirebaseAvailable = false;

/// Handover SECTION 1 — Fix HttpException: Connection closed
/// Rule 2: Disable Auto-Download hoàn toàn để tránh HuggingFace CDN timeout
/// trên Android Tablet do Battery Saver.
/// Trước đây sai filePath -> fallback tự động gọi HTTP GET -> HttpException
/// Giờ ép app chỉ nạp file đã chép sẵn tại absolute path (Rule 1).
/// Nếu model chưa có, SttModelManager sẽ báo lỗi thân thiện thay vì tải.
final Map<WhisperModelLevel, List<String>> _sttModelUrls = {
  WhisperModelLevel.tiny: [],
  WhisperModelLevel.base: [],
  WhisperModelLevel.small: [],
  WhisperModelLevel.medium: [],
  WhisperModelLevel.large: [],
};

/// Tên file được chấp nhận khi:
/// - build có sẵn trong assets
/// - bạn copy/import file .bin từ nguồn khác
final Map<WhisperModelLevel, List<String>> _acceptedModelNames = {
  WhisperModelLevel.tiny: [
    'ggml-tiny.bin',
  ],
  WhisperModelLevel.base: [
    'ggml-base.bin',
  ],
  WhisperModelLevel.small: [
    'ggml-small.bin',
  ],
  WhisperModelLevel.medium: [
    'ggml-medium.bin',
  ],
  WhisperModelLevel.large: [
    'ggml-large-v2.bin',
  ],
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ★ Chỉ Firebase là bắt buộc trước runApp
  await _initializeFirebaseSafely();

  // Khởi tạo StorageService quản lý Hive
  final storage = StorageService();
  await storage.initialize();

  // Mở box chứa hàng đợi các tác vụ đồng bộ dở dang khi mất mạng
  if (!Hive.isBoxOpen('vocab_sync_pending')) {
    await Hive.openBox<String>('vocab_sync_pending');
  }

  // ★ runApp ngay - không block
  const bool useDevicePreview = false; // Thay đổi giá trị này thành true khi cần DevicePreview

  runApp(
    useDevicePreview
        ? DevicePreview(
            enabled: true,
            builder: (context) => const MyApp(),
          )
        : const MyApp(),
  );

  // ★ STT init chạy background sau khi UI đã show
  _bootstrapSttInBackground();
}

void _bootstrapSttInBackground() {
  SttServiceFacade()
      .initialize(
    config: SttConfig.balanced,
    modelUrls: _sttModelUrls,
    acceptedModelNames: _acceptedModelNames,
  )
      .catchError((e) {
    debugPrint('⚠️ STT background init error: $e');
  });

  // Initialize Native FFI Whisper if on Windows
  WhisperService().initNativeContext().catchError((e) {
    debugPrint('⚠️ STT background init error: $e');
  });
}

Future<FirebaseApp?> _initializeFirebaseSafely() async {
  try {
    if (Firebase.apps.isNotEmpty) {
      isFirebaseAvailable = true;
      return Firebase.app();
    }

    late final FirebaseApp app;
    if (kIsWeb) {
      app = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else if (Platform.isAndroid) {
      // Android: dùng google-services.json native để hỗ trợ flavors
      // File này đã chứa nhiều clients cho com.in4up, com.in4up.dev, com.in4up.beta...
      // Nếu dùng DefaultFirebaseOptions, chỉ có 1 appId và sẽ fail cho beta/dev
      // nên để Firebase tự đọc google-services.json
      try {
        app = await Firebase.initializeApp();
      } catch (e) {
        debugPrint('⚠️ Android native init failed, fallback to options: $e');
        // Fallback: dùng options theo flavor (androidForFlavor nằm trong
        // currentPlatform của bản đầy đủ). Lưu ý: CI workflow GHI ĐÈ
        // lib/firebase_options.dart bằng bản tối giản chỉ có currentPlatform
        // nên KHÔNG được gọi androidForFlavor trực tiếp ở đây — sẽ lỗi
        // "Member not found" và đỏ cả 3 nền tảng build.
        app = await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } else if (Platform.isIOS || Platform.isMacOS) {
      // iOS/macOS: dùng GoogleService-Info.plist (native)
      app = await Firebase.initializeApp();
    } else {
      // Windows / Linux: bắt buộc dùng options
      app = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    isFirebaseAvailable = true;
    debugPrint(
        '✅ Firebase initialized: ${app.options.projectId} flavor=${const String.fromEnvironment('FLAVOR', defaultValue: 'stable')}');
    return app;
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      isFirebaseAvailable = true;
      return Firebase.app();
    }

    isFirebaseAvailable = false;
    debugPrint('⚠️ Firebase init failed: ${e.code} - ${e.message}');
    // Thử fallback không options cho Android
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final fallback = await Firebase.initializeApp();
        isFirebaseAvailable = true;
        return fallback;
      } catch (e2) {
        debugPrint('⚠️ Firebase fallback also failed: $e2');
      }
    }
    return null;
  } catch (e, st) {
    isFirebaseAvailable = false;
    debugPrint('⚠️ Firebase init failed: $e\n$st');
    return null;
  }
}

class _AppLocalServices {
  final SharedPreferences prefs;

  const _AppLocalServices({
    required this.prefs,
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Future<_AppLocalServices> _localInitFuture;

  @override
  void initState() {
    super.initState();
    _localInitFuture = _initializeLocalServices();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppLocalServices>(
      future: _localInitFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AppLoadingScreen();
        }

        if (snapshot.hasError) {
          return _AppErrorScreen(error: snapshot.error);
        }

        final localServices = snapshot.data!;
        return _buildApp(localServices);
      },
    );
  }

  Future<_AppLocalServices> _initializeLocalServices() async {
    final prefs = await SharedPreferences.getInstance();

    return _AppLocalServices(prefs: prefs);
  }

  Widget _buildApp(_AppLocalServices localServices) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => LocaleProvider(localServices.prefs)),
        ChangeNotifierProvider(create: (_) => UnderstandProvider()),
        ChangeNotifierProvider(
          create: (context) => PlayerProvider(
            understandProvider: context.read<UnderstandProvider>(),
          ),
        ),
        // Âm mục (Soundlist): điểm, mục lục, đoạn âm thanh + theo dõi thói quen lặp
        ChangeNotifierProvider(
          create: (ctx) => SoundlistProvider()
            ..load()
            ..attachPlayer(ctx.read<PlayerProvider>()),
        ),
        // Thư viện âm thanh (P1): quét MediaStore, chỉ mục Hive
        ChangeNotifierProvider(create: (_) => AudioLibraryProvider()),
        ChangeNotifierProvider(create: (_) => TextProvider()),
        ChangeNotifierProvider(create: (_) => WaveformProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final prov = VocabularyProvider();
            prov.loadData(); // Nạp danh sách từ cục bộ từ Hive
            unawaited(ReaderDisplaySettings().init()); // READ-630-03

            // Tự động kích hoạt sync khi có User đăng nhập - chỉ khi Firebase sẵn sàng (fix Linux no-app)
            if (isFirebaseAvailable) {
              try {
                FirebaseAuth.instance.authStateChanges().listen((user) {
                  if (user != null) {
                    debugPrint('☁️ Sync Enabled for user: ${user.uid}');
                    unawaited(prov.enableSync(user.uid));
                  } else {
                    prov.disableSync();
                  }
                });
              } catch (e) {
                debugPrint('⚠️ FirebaseAuth listener failed (Linux no-app expected): $e');
              }
            } else {
              debugPrint('ℹ️ Firebase not available (Linux), skip auth sync listener');
            }

            return prov;
          },
        ),
        ChangeNotifierProvider(create: (_) => ShadowingProvider()),
        ChangeNotifierProvider(create: (_) => FocusProvider()),
        ChangeNotifierProvider(
            create: (_) => KaraokeSettingsProvider()..load()),
        ChangeNotifierProvider(
            create: (_) => LearnByHeartProvider()..loadData()),

        // Nếu đây là singleton/global controller thì dùng .value an toàn hơn
        ChangeNotifierProvider<MemoryController>.value(
          value: MemoryProvider.controller,
        ),

        Provider<SharedPreferences>.value(
          value: localServices.prefs,
        ),

        Provider<TtsService>(
          create: (_) => FlutterTtsServiceImpl(),
          dispose: (_, service) => service.dispose(),
        ),

        Provider<TtsNotificationService>(
          create: (_) => TtsNotificationService(),
        ),

        Provider<PlaybackEngine>(
          create: (ctx) => PlaybackEngine(ctx.read<TtsService>()),
          dispose: (_, engine) => engine.stop(),
        ),

        ChangeNotifierProvider<PlaybackController>(
          create: (ctx) => PlaybackController(
            ctx.read<PlaybackEngine>(),
            ctx.read<SharedPreferences>(),
            ctx.read<TtsNotificationService>(),
            () => ctx.read<LocaleProvider>().locale?.toLanguageTag() ??
                WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
          ),
        ),

        ChangeNotifierProvider<AiServiceFacade>(
          create: (_) {
            final facade = AiServiceFacade();
            facade.initializeAsync();
            return facade;
          },
        ),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, child) {
          return MaterialApp(
            title: 'In4Up',
            debugShowCheckedModeBanner: false,
            locale: localeProvider.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            localeResolutionCallback: (deviceLocale, supportedLocales) {
              if (deviceLocale != null) {
                for (var locale in supportedLocales) {
                  if (locale.languageCode == deviceLocale.languageCode) {
                    return deviceLocale;
                  }
                }
              }
              // Fallback to English if device locale is not supported
              return const Locale('en', '');
            },
            supportedLocales: AppLocalizations.supportedLocales,
            theme: _buildTheme(),
            builder: (context, child) => _appBuilder(context, child),
            home: const MainShell(),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6C63FF),
        brightness: Brightness.dark,
        surface: const Color(0xFF080B1A),
        surfaceTint: const Color(0xFF6C63FF).withValues(alpha: 0.1),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: Color(0xFF1A1A2E),
      ),
    );
  }
}

Widget _appBuilder(BuildContext context, Widget? child) {
  return _clampedMediaQuery(context, child!);
}

Widget _clampedMediaQuery(BuildContext context, Widget? child) {
  final mediaQuery = MediaQuery.maybeOf(context);
  if (mediaQuery == null) return child ?? const SizedBox.shrink();

  return MediaQuery(
    data: mediaQuery.copyWith(
      textScaler: AppResponsive.clampTextScaler(mediaQuery.textScaler),
    ),
    child: child ?? const SizedBox.shrink(),
  );
}

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'In4Up',
      debugShowCheckedModeBanner: false,
      builder: (context, child) => _appBuilder(context, child),
      home: Scaffold(
        backgroundColor: const Color(0xFF080B1A),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Brand mark
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/icons/app_icon.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    semanticLabel: 'In4Up logo',
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'In4Up',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Đang khởi động...',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 40),
                const SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF53D6BD),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppErrorScreen extends StatelessWidget {
  final Object? error;

  const _AppErrorScreen({this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'In4Up',
      debugShowCheckedModeBanner: false,
      builder: (context, child) => _appBuilder(context, child),
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 64),
                  const SizedBox(height: 20),
                  Text(
                    'Initialization Error:\n$error',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
