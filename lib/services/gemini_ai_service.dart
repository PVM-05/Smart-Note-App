import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';

class GeminiAiService {
  GenerativeModel? _model;

  Future<String> transcribeAudio(Uint8List bytes, String mimeType) async {
    try {
      final response = await model.generateContent([
        Content.inlineData(mimeType, bytes),
        Content.text('Hãy chuyển toàn bộ âm thanh trong file ghi âm này thành văn bản thuần túy (thường là tiếng Việt). '
            'Yêu cầu áp dụng Định dạng Thông minh (Smart Formatting) cho văn bản kết quả:\n'
            '1. Tự động viết hoa chữ cái đầu câu và viết hoa các danh từ riêng.\n'
            '2. Thêm các dấu câu phù hợp (dấu chấm, dấu phẩy, dấu chấm hỏi) dựa trên nhịp điệu và quãng ngắt nghỉ.\n'
            '3. Định dạng và chuẩn hóa số điện thoại, ngày tháng, thời gian, số liệu (ví dụ: "chín giờ tối" -> "21:00", "ngày hai mươi hai tháng sáu năm hai nghìn không trăm hai mươi sáu" -> "22/06/2026", "không chín tám bảy sáu năm bốn ba hai một" -> "0987654321").\n'
            'Chỉ trả về duy nhất văn bản lời nói đã được chuyển đổi và định dạng. Tuyệt đối không thêm lời giải thích, tiêu đề phụ, hoặc bất kỳ ký tự dư thừa nào khác.'),
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
