import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vipsound/screens/memory_mode/controllers/memory_controller.dart';
import 'package:vipsound/screens/understand_mode/understand_provider.dart';
import 'package:vipsound/services/storage_service.dart';
import 'package:vipsound_ai/vipsound_ai.dart';
import 'package:vipsound_stt/models/stt_config.dart';
import 'package:vipsound_stt/models/stt_model_info.dart';
import 'package:vipsound_stt/stt_service_facade.dart';

import 'features/shadowing/providers/shadowing_provider.dart';
import 'firebase_options.dart';
import 'providers/focus_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/player_provider.dart';
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
import 'services/whisper_service.dart';

bool isFirebaseAvailable = false;

/// Thay 5 link này bằng nguồn thật của bạn.
/// Nếu model đã có sẵn trong assets/local thì app sẽ dùng luôn, không tải lại.
final Map<WhisperModelLevel, List<String>> _sttModelUrls = {
  WhisperModelLevel.tiny: [
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin?download=true',
  ],
  WhisperModelLevel.base: [
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin?download=true',
  ],
  WhisperModelLevel.small: [
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin?download=true',
  ],
  WhisperModelLevel.medium: [
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin?download=true',
  ],
  WhisperModelLevel.large: [
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v2.bin?download=true',
  ],
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
  runApp(const MyApp());

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

    final FirebaseApp app;
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      // iOS/macOS: dùng GoogleService-Info.plist (native)
      // KHÔNG truyền options để Firebase tự đọc plist được nhúng trong bundle.
      app = await Firebase.initializeApp();
    } else {
      // Android / Windows / Web / Linux: dùng DefaultFirebaseOptions
      app = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    isFirebaseAvailable = true;
    return app;
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      isFirebaseAvailable = true;
      return Firebase.app();
    }

    isFirebaseAvailable = false;
    debugPrint('⚠️ Firebase init failed: ${e.code} - ${e.message}');
    return null;
  } catch (e) {
    isFirebaseAvailable = false;
    debugPrint('⚠️ Firebase init failed: $e');
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
        ChangeNotifierProvider(create: (_) => LocaleProvider(localServices.prefs)),
        ChangeNotifierProvider(create: (_) => UnderstandProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(create: (_) => TextProvider()),
        ChangeNotifierProvider(create: (_) => WaveformProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final prov = VocabularyProvider();
            prov.loadData(); // Nạp danh sách từ cục bộ từ Hive

            // Tự động kích hoạt sync khi có User đăng nhập
            FirebaseAuth.instance.authStateChanges().listen((user) {
              if (user != null) {
                debugPrint('☁️ Sync Enabled for user: ${user.uid}');
                unawaited(prov.enableSync(user.uid));
              } else {
                prov.disableSync();
              }
            });

            return prov;
          },
        ),
        ChangeNotifierProvider(create: (_) => ShadowingProvider()),
        ChangeNotifierProvider(create: (_) => FocusProvider()),

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

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF080B1A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF9C27B0)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.headphones,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'VipSound',
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
                    Color(0xFF6C63FF),
                  ),
                ),
              ),
            ],
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
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: Center(
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
    );
  }
}