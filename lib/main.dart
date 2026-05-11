import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:smart_note_app/services/firestore_note_service.dart';
import 'firebase_options.dart';
import 'models/note_model.dart';
import 'screens/home_screen.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Test — xóa sau khi kiểm tra xong
  final testService = FirestoreNoteService();
  await testService.saveNote(Note(
    id: 'test-001',
    title: 'Test Firestore',
    content: 'Nếu thấy note này trên Console là thành công',
  ));
  print('✅ Ghi Firestore thành công');
  print('Firebase connected: ${Firebase.app().name}');
  print('Project ID: ${Firebase.app().options.projectId}');
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
      home: const HomeScreen(),
    );
  }
}
