import 'package:flutter/material.dart';
import '../services/gemini_ai_service.dart';

class AiTestScreen extends StatefulWidget {
  const AiTestScreen({super.key});

  @override
  State<AiTestScreen> createState() => _AiTestScreenState();
}

class _AiTestScreenState extends State<AiTestScreen> {
  final _ai = GeminiAiService();
  bool _loading = false;
  String _result = '';

  Future<void> _testGemini() async {
    setState(() {
      _loading = true;
      _result = '';
    });

    try {
      final text = await _ai.generateText(
        'Hãy trả lời ngắn gọn bằng tiếng Việt: Smart Note App là gì?',
      );

      setState(() {
        _result = text;
      });
    } catch (e) {
      setState(() {
        _result = 'Lỗi: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Gemini AI'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _loading ? null : _testGemini,
              child: Text(_loading ? 'Đang gọi AI...' : 'Test Gemini'),
            ),
            const SizedBox(height: 16),
            if (_loading) const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_result),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
