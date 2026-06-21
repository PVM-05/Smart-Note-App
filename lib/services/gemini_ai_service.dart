import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';

class GeminiAiService {
  GenerativeModel? _model;

  Future<String> transcribeAudio(Uint8List bytes, String mimeType) async {
    try {
      final response = await model.generateContent([
        Content.inlineData(mimeType, bytes),
        Content.text('Hãy chuyển toàn bộ âm thanh trong file ghi âm này thành văn bản thuần túy (thường là tiếng Việt). Chỉ trả về phần văn bản nói được nhận dạng, không được thêm bất kỳ lời giải thích, ghi chú hay ký tự nào khác ngoài nội dung lời nói.'),
      ]);
      return response.text?.trim() ?? '';
    } catch (e) {
      return '';
    }
  }

  GenerativeModel get model {
    _model ??= FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash-lite',
    );
    return _model!;
  }

  Future<String> generateText(String prompt) async {
    final response = await model.generateContent([
      Content.text(prompt),
    ]);

    return response.text?.trim() ?? '';
  }

  Future<String> summarizeNote({
    required String title,
    required String content,
  }) {
    return generateText('''
Bạn là trợ lý ghi chú thông minh.

Hãy tóm tắt ghi chú sau bằng tiếng Việt, ngắn gọn, dễ hiểu.
Không thêm thông tin không có trong ghi chú.

Tiêu đề:
$title

Nội dung:
$content
''');
  }

  Future<String> suggestTitle(String content) {
    return generateText('''
Hãy tạo một tiêu đề ngắn bằng tiếng Việt cho ghi chú sau.
Chỉ trả về 1 tiêu đề, không giải thích.

Nội dung:
$content
''');
  }

  Future<String> makeChecklist(String content) {
    return generateText('''
Chuyển nội dung sau thành checklist tiếng Việt.
Mỗi dòng bắt đầu bằng "- ".
Không thêm giải thích.

Nội dung:
$content
''');
  }

  Future<String> suggestTags({
    required String title,
    required String content,
  }) {
    return generateText('''
Bạn là trợ lý ghi chú thông minh.
Hãy gợi ý từ 3 đến 5 nhãn ngắn gọn, liên quan đến ghi chú dưới đây bằng tiếng Việt.
Trả về các nhãn phân tách nhau bằng dấu phẩy, ví dụ: "Học tập, Công việc, Kế hoạch".
Không thêm bất kỳ giải thích, tiêu đề, số thứ tự hay ký tự đặc biệt nào khác ngoài dấu phẩy.

Tiêu đề:
$title

Nội dung:
$content
''');
  }
}
