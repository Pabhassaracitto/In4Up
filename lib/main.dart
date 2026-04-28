// lib/main.dart

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'; // Để dùng kIsWeb và defaultTargetPlatform
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vipsound_ai/vipsound_ai.dart';

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
import 'services/storage_service.dart';

// Biến toàn cục để kiểm tra trạng thái Firebase
bool isFirebaseAvailable = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Khởi tạo Firebase với Try-Catch để không chặn App nếu lỗi
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      isFirebaseAvailable = true;
      debugPrint("✅ Firebase initialized successfully.");
    } else {
      // Firebase đã được khởi tạo (thường là do Hot Restart)
      isFirebaseAvailable = true; // Giả định là có sẵn
      debugPrint(
          "ℹ️ Firebase [DEFAULT] app already initialized (likely hot restart).");
    }
  } catch (e) {
    isFirebaseAvailable = false;
    debugPrint("❌ Firebase initialization failed: $e");
  }

  // 2. Cấu hình hướng màn hình (Chỉ dành cho Mobile)
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // 3. Cấu hình giao diện hệ thống
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1A1A2E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<void> _initFuture;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    // Khởi tạo các dịch vụ local (Hive, Storage...)
    _initFuture = _initializeServices();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        // Màn hình Loading khi đang khởi tạo Hive/Storage
        if (snapshot.connectionState != ConnectionState.done) {
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

        // Màn hình lỗi nếu khởi tạo Local Services thất bại
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: const Color(0xFF1A1A2E),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 64),
                    const SizedBox(height: 20),
                    Text(
                      'Initialization Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Khi mọi thứ đã sẵn sàng
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => PlayerProvider()),
            ChangeNotifierProvider(create: (_) => TextProvider()),
            ChangeNotifierProvider(create: (_) => WaveformProvider()),
            ChangeNotifierProvider(create: (_) => VocabularyProvider()),
            ChangeNotifierProvider(create: (_) => ShadowingProvider()),
            ChangeNotifierProvider(create: (_) => FocusProvider()),
            ChangeNotifierProvider(create: (_) => MemoryProvider.controller),

            // Cấu hình DI cho Playback & TTS System
            // Thứ tự QUAN TRỌNG — phải đúng dependency order
            Provider<SharedPreferences>.value(value: _prefs),

            Provider<TtsService>(
              create: (_) => FlutterTtsServiceImpl(),
              dispose: (_, s) => s.dispose(),
            ),

            Provider<TtsNotificationService>(
              create: (_) => TtsNotificationService(),
            ),

            // PlaybackEngine — không phải ChangeNotifier nên dùng Provider thường
            ProxyProvider<TtsService, PlaybackEngine>(
              update: (_, tts, prev) => prev ?? PlaybackEngine(tts),
            ),

            // ★ FIX: PlaybackController LÀ ChangeNotifier
            // → PHẢI dùng ChangeNotifierProxyProvider
            // PlaybackEngine
            Provider<PlaybackEngine>(
              create: (ctx) => PlaybackEngine(ctx.read<TtsService>()),
              dispose: (_, e) => e.stop(),
            ),
/*// PlaybackEngine — không phải ChangeNotifier nên dùng Provider thường
ProxyProvider<TtsService, PlaybackEngine>(
  update: (_, tts, prev) => prev ?? PlaybackEngine(tts),
),

// ★ FIX: PlaybackController LÀ ChangeNotifier
// → PHẢI dùng ChangeNotifierProxyProvider
ChangeNotifierProxyProvider3<PlaybackEngine, SharedPreferences,
    TtsNotificationService, PlaybackController>(
  create: (_) => PlaybackController._placeholder(),
  update: (_, engine, prefs, notif, prev) {
    if (prev != null && prev._initialized) return prev;
    return PlaybackController(engine, prefs, notif);
  },
),
Nhưng vì PlaybackController không có _placeholder() constructor, cách đơn giản hơn là dùng pattern lazy init:
 */
// ★ FIX CHÍNH: ChangeNotifierProvider thay vì ProxyProvider
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
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor:
                    const Color(0xFF6C63FF), // Indigo làm gốc cho "Studio"
                brightness: Brightness.dark,
                surface: const Color(0xFF080B1A),
                surfaceTint: Color(0xFF6C63FF).withValues(alpha: 0.1),
              ),
              appBarTheme: const AppBarTheme(
                elevation: 0,
                scrolledUnderElevation: 0,
                centerTitle: true,
                backgroundColor: Color(0xFF1A1A2E),
              ),
            ),
            home: const MainShell(),
          ),
        );
      },
    );
  }

  Future<void> _initializeServices() async {
    // Khởi tạo Hive cho Flutter
    await Hive.initFlutter();

    // Chạy song song các khởi tạo local
    final results = await Future.wait([
      StorageService().initialize(),
      VocabularyProvider.ensureBoxOpen(),
      _openSyncBox(),
      SharedPreferences.getInstance(),
    ]);
    _prefs = results[3] as SharedPreferences;
  }

  Future<void> _openSyncBox() async {
    if (!Hive.isBoxOpen('vocab_sync_pending')) {
      await Hive.openBox<String>('vocab_sync_pending');
    }
  }
}
