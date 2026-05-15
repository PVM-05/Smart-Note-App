import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/note_provider.dart';
import 'providers/sync_provider.dart';
import 'repositories/note_repository.dart';
import 'repositories/sync_repository.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        ChangeNotifierProvider(
          create: (context) => NoteProvider(NoteRepositoryImpl()),
        ),
        ChangeNotifierProvider(
          create: (context) => SyncProvider(context.read<SyncRepository>()),
        ),
        
      ],


      child: MaterialApp(
        title: 'Smart Note App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E75B6)),
          useMaterial3: true,
        ),
        // StreamBuilder lắng nghe trạng thái login
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            // Đã login → HomeScreen, chưa login → LoginScreen
            return snapshot.hasData ? const HomeScreen() : const LoginScreen();
          },
        ),
      ),
    );
  }
}
