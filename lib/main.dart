import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/note_provider.dart';
import 'providers/sync_provider.dart';
import 'repositories/note_repository.dart';
import 'repositories/sync_repository.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 🌟 Tiến hành nạp file .env vào hệ thống
    await dotenv.load(fileName: ".env");
    print("✅ Đã tải file .env thành công");
  } catch (e) {
    print("❌ Lỗi tải file .env: $e. Hãy kiểm tra xem đã tạo file chưa.");
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
      child: MaterialApp(
        title: 'Smart Note App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E75B6)),
          useMaterial3: true,
        ),
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
      ),
    );
  }
}
