import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/note_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/theme_provider.dart';
import 'repositories/note_repository.dart';
import 'repositories/sync_repository.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 🌟 Tiến hành nạp file .env vào hệ thống
    await dotenv.load(fileName: ".env");
    debugPrint("ENV TEST");
    debugPrint("Cloud Name: ${dotenv.env['CLOUDINARY_CLOUD_NAME']}");
    debugPrint("Preset: ${dotenv.env['CLOUDINARY_UPLOAD_PRESET']}");
    debugPrint("✅ Đã tải file .env thành công");
  } catch (e) {
    debugPrint("❌ Lỗi tải file .env: $e. Hãy kiểm tra xem đã tạo file chưa.");
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        Provider<SyncRepository>(create: (_) => SyncRepositoryImpl()),
        ChangeNotifierProxyProvider<AuthProvider, NoteProvider>(
          create: (_) => NoteProvider(NoteRepositoryImpl()),
          update: (context, auth, noteProvider) {
            if (!auth.isAuthenticated || auth.user == null) {
              noteProvider?.clearNotes();
            }
            return noteProvider!;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, SyncProvider>(
          create: (context) => SyncProvider(context.read<SyncRepository>()),
          update: (context, auth, syncProvider) {
            syncProvider?.updateUser(auth.user?.uid);
            return syncProvider!;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Smart Note App',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              FlutterQuillLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('vi', 'VN'),
              Locale('en', 'US'),
            ],
            theme: themeProvider.themeData,
            darkTheme: themeProvider.themeData,
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return snapshot.hasData ? const HomeScreen() : const LoginScreen();
              },
            ),
          );
        },
      ),
    );
  }
}
