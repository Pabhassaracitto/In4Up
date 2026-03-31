// lib/main.dart

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'features/shadowing/providers/shadowing_provider.dart';
import 'firebase_options.dart';
import 'providers/player_provider.dart';
import 'providers/text_provider.dart';
import 'providers/vocabulary_provider.dart';
import 'providers/waveform_provider.dart';
import 'screens/main_shell.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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

  @override
  void initState() {
    super.initState();
    // ✅ CHỈ KHỞI TẠO 1 LẦN DUY NHẤT
    _initFuture = _initializeServices();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
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
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // ✅ Chỉ dùng ChangeNotifierProvider cho classes THẬT SỰ extend ChangeNotifier
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => PlayerProvider()),
            ChangeNotifierProvider(create: (_) => TextProvider()),
            ChangeNotifierProvider(create: (_) => WaveformProvider()),
            ChangeNotifierProvider(create: (_) => VocabularyProvider()),
            ChangeNotifierProvider(create: (_) => ShadowingProvider()),
            // ❌ XÓA: VocabularyBridge - là static utility class, không cần Provider
            // ❌ XÓA: MemoryProvider - là static utility class, không cần Provider
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: Brightness.dark,
              primaryColor: const Color(0xFF0F3460),
              scaffoldBackgroundColor: const Color(0xFF1A1A2E),
            ),
            home: const MainShell(),
          ),
        );
      },
    );
  }

  Future<void> _initializeServices() async {
    // ✅ PHẢI CÓ: Khởi tạo Hive cho Flutter trước khi mở bất kỳ Box nào
    await Hive.initFlutter();

    await Future.wait([
      StorageService().initialize(),
      VocabularyProvider.ensureBoxOpen(),
      _openSyncBox(),
    ]);

    // ✅ THÊM: Init VocabularyBridge sau khi VocabularyProvider sẵn sàng
    // (Sẽ được gọi trong widget khi có context)
  }

  Future<void> _openSyncBox() async {
    if (!Hive.isBoxOpen('vocab_sync_pending')) {
      await Hive.openBox<String>('vocab_sync_pending');
    }
  }
}
