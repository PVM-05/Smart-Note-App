import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'models/note_model.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('✅ Ghi Firestore thành công');
  print('Firebase connected: ${Firebase.app().name}');
  print('Project ID: ${Firebase.app().options.projectId}');
  // Test convert — xóa sau khi xong
  final note = Note(
    id: 'test-002',
    title: 'Test Timestamp',
    content: 'Kiểm tra Firestore map',
  );

// In ra SQLite map
  print('SQLite map: ${note.toMap()}');
// → {id: test-002, created_at: 1234567890000, is_synced: 0, ...}

// In ra Firestore map
  print('Firestore map: ${note.toFirestoreMap()}');
// → {id: test-002, created_at: Timestamp(seconds=...), ...}

// Test fromFirestoreMap
  final firestoreData = note.toFirestoreMap();
  final noteBack = Note.fromFirestoreMap(firestoreData);
  print('isSynced sau fromFirestoreMap: ${noteBack.isSynced}'); // → true
  print('title: ${noteBack.title}'); // → Test Timestamp



  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Note App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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
    );
  }
}