// lib/main.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'features/shadowing/providers/shadowing_provider.dart';
import 'firebase_options.dart';
import 'providers/player_provider.dart';
import 'providers/text_provider.dart';
import 'providers/vocabulary_bridge.dart'; // ★ THÊM
import 'providers/vocabulary_provider.dart'; // ★ THÊM
import 'providers/waveform_provider.dart';
import 'screens/main_shell.dart';
import 'screens/memory_mode/memory_provider.dart';
import 'services/storage_service.dart'; // ★ THÊM
import 'services/google_drive_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ★ THÊM: Khởi tạo StorageService trước
  await StorageService().initialize();
  await VocabularyProvider.ensureBoxOpen();
  // Mở Hive box cho pending sync queue
  if (!Hive.isBoxOpen('vocab_sync_pending')) {
    await Hive.openBox<String>('vocab_sync_pending');
  }

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

  runApp(const VipSoundApp());
}

class VipSoundApp extends StatelessWidget {
  const VipSoundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ★ THÊM drive:
        ChangeNotifierProvider(
          create: (_) => GoogleDriveService(),
        ),
        // Khi tạo VocabularyProvider:
        ChangeNotifierProvider<VocabularyProvider>(
          lazy:
              false, // ★ FIX: Khởi tạo ngay lập tức để VocabularyBridge sẵn sàng nhận từ
          create: (_) {
            final vp = VocabularyProvider();
            VocabularyBridge.init(vp);
            vp.loadData();
            return vp;
          },
        ),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(create: (_) => TextProvider()),
        ChangeNotifierProvider(create: (_) => WaveformProvider()),
        ChangeNotifierProvider(create: (_) => ShadowingProvider()),
        ChangeNotifierProvider.value(value: MemoryProvider.controller),
      ],
      child: MaterialApp(
        title: 'VipSound Player',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6C63FF),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF0F0F23),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
          ),
          sliderTheme: SliderThemeData(
            activeTrackColor: const Color(0xFF6C63FF),
            inactiveTrackColor: Colors.white24,
            thumbColor: const Color(0xFF6C63FF),
            overlayColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        home: const PermissionWrapper(),
      ),
    );
  }
}

class PermissionWrapper extends StatefulWidget {
  const PermissionWrapper({super.key});

  @override
  State<PermissionWrapper> createState() => _PermissionWrapperState();
}

class _PermissionWrapperState extends State<PermissionWrapper> {
  bool _hasPermission = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();

    // ★ FIX: Lắng nghe đăng nhập để bật/tắt cloud sync
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      final vp = context.read<VocabularyProvider>();
      if (user != null && !user.isAnonymous) {
        debugPrint('☁️ Auto-enabling sync for user: ${user.uid}');
        vp.enableSync(user.uid);
      } else {
        vp.disableSync();
      }
    });
  }

  Future<void> _checkPermissions() async {
    try {
      var status = await Permission.storage.status;
      if (status.isDenied) {
        status = await Permission.storage.request();
      }
      var audioStatus = await Permission.audio.status;
      if (audioStatus.isDenied) {
        audioStatus = await Permission.audio.request();
      }
      var micStatus = await Permission.microphone.status;
      if (micStatus.isDenied) {
        micStatus = await Permission.microphone.request();
      }
      setState(() {
        _hasPermission = status.isGranted || audioStatus.isGranted;
        _isChecking = false;
      });
    } catch (e) {
      setState(() {
        _hasPermission = true;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F23),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6C63FF).withValues(alpha: 0.3),
                      const Color(0xFF6C63FF).withValues(alpha: 0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.music_note,
                    size: 48, color: Color(0xFF6C63FF)),
              ),
              const SizedBox(height: 24),
              const Text('VipSound',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 8),
              Text('Đang khởi động...',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500])),
              const SizedBox(height: 32),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasPermission) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F23),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.folder_off,
                      size: 64, color: Colors.orange),
                ),
                const SizedBox(height: 24),
                const Text('Cần quyền truy cập',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 12),
                Text(
                  'VipSound cần quyền truy cập bộ nhớ để phát file audio và lưu tiến trình học tập của bạn.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.grey[400], fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _checkPermissions,
                  icon: const Icon(Icons.security),
                  label: const Text('Cấp quyền'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _hasPermission = true),
                  child: Text('Bỏ qua (một số tính năng sẽ bị hạn chế)',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const MainShell();
  }
}
