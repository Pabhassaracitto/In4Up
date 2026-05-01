import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vipsound/screens/memory_mode/controllers/memory_controller.dart';
import 'package:vipsound_ai/vipsound_ai.dart';
import 'package:vipsound_stt/models/stt_config.dart';
import 'package:vipsound_stt/models/stt_model_info.dart';
import 'package:vipsound_stt/stt_service_facade.dart';

import 'features/shadowing/providers/shadowing_provider.dart';
import 'firebase_options.dart';
import 'providers/focus_provider.dart';
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

bool isFirebaseAvailable = false;

/// Thay 5 link này bằng nguồn thật của bạn.
/// Nếu model đã có sẵn trong assets/local thì app sẽ dùng luôn, không tải lại.
final Map<WhisperModelLevel, List<String>> _sttModelUrls = {
  WhisperModelLevel.tiny: [
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny-q8_0.bin?download=true',
  ],
  WhisperModelLevel.base: [
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-q5_1.bin?download=true',
  ],
  WhisperModelLevel.small: [
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q5_1.bin?download=truehttps://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q8_0.bin?download=true',
  ],
  WhisperModelLevel.medium: [
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium-q5_0.bin?download=true',
  ],
  WhisperModelLevel.large: [
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin?download=true',
  ],
};

/// Tên file được chấp nhận khi:
/// - build có sẵn trong assets
/// - bạn copy/import file .bin từ nguồn khác
final Map<WhisperModelLevel, List<String>> _acceptedModelNames = {
  WhisperModelLevel.tiny: [
    'ggml-tiny-q5_1.bin',
    'ggml-tiny-q8_1.bin',
    'ggml-tiny.bin',
    'tiny.bin',
  ],
  WhisperModelLevel.base: [
    'ggml-base.en-q5_1.bin',
    'ggml-base-q5_1.bin',
    'ggml-base-q8_1.bin',
    'ggml-base.en.bin',
    'ggml-base.bin',
    'base.bin',
  ],
  WhisperModelLevel.small: [
    'ggml-small-q5_1.bin',
    'ggml-small-q8_1.bin',
    'ggml-small.bin',
    'small.bin',
  ],
  WhisperModelLevel.medium: [
    'ggml-medium-q5_1.bin',
    'ggml-medium.bin',
    'medium.bin',
  ],
  WhisperModelLevel.large: [
    'ggml-large-v3-turbo-q5_0.bin'
        'ggml-large-v3-q5_1.bin',
    'ggml-large-v3.bin',
    'ggml-large.bin',
    'large.bin',
  ],
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _bootstrapGlobalServices();

  runApp(const MyApp());
}

/// Chỉ init các service cấp app / singleton ở đây.
/// Không init lại trong widget tree.
Future<void> _bootstrapGlobalServices() async {
  await _initializeFirebaseSafely();

  await SttServiceFacade().initialize(
    config: SttConfig.balanced,
    modelUrls: _sttModelUrls,
    acceptedModelNames: _acceptedModelNames,
  );
}

Future<FirebaseApp?> _initializeFirebaseSafely() async {
  try {
    if (Firebase.apps.isNotEmpty) {
      isFirebaseAvailable = true;
      return Firebase.app();
    }

    final app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

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
    await Hive.initFlutter();

    final prefs = await SharedPreferences.getInstance();

    if (!Hive.isBoxOpen('vocab_sync_pending')) {
      await Hive.openBox<String>('vocab_sync_pending');
    }

    return _AppLocalServices(
      prefs: prefs,
    );
  }

  Widget _buildApp(_AppLocalServices localServices) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(create: (_) => TextProvider()),
        ChangeNotifierProvider(create: (_) => WaveformProvider()),
        ChangeNotifierProvider(create: (_) => VocabularyProvider()),
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
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const MainShell(),
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
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text(
                'Loading VipSound...',
                style: TextStyle(color: Colors.white),
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
