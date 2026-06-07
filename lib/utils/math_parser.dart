// lib/utils/math_parser.dart

class MathParser {
  /// Hàm evaluate: Kiểm tra xem văn bản trước con trỏ có phải là phép tính không.
  /// Nếu có, trả về kết quả dưới dạng chuỗi (String). Nếu không, trả về null.
  /// Hỗ trợ các phép tính cơ bản: +, -, *, /
  static String? evaluate(String text) {
    if (text.isEmpty) return null;

    // Regex nhận diện phép tính dạng: "số (khoảng trắng) toán_tử (khoảng trắng) số ="
    // Hỗ trợ số thập phân. Ở cuối chuỗi văn bản.
    final regex = RegExp(r'([\d\.]+)\s*([\+\-\*\/xX:])\s*([\d\.]+)\s*=$');
    final match = regex.firstMatch(text.trimRight());

    if (match != null) {
      final num1Str = match.group(1);
      final operatorStr = match.group(2);
      final num2Str = match.group(3);

      if (num1Str == null || operatorStr == null || num2Str == null) return null;

      final num1 = double.tryParse(num1Str);
      final num2 = double.tryParse(num2Str);

      if (num1 == null || num2 == null) return null;

      double result;
      switch (operatorStr.toLowerCase()) {
        case '+':
          result = num1 + num2;
          break;
        case '-':
          result = num1 - num2;
          break;
        case '*':
        case 'x':
          result = num1 * num2;
          break;
        case '/':
        case ':':
          if (num2 == 0) return null; // Không chia cho 0
          result = num1 / num2;
          break;
        default:
          return null;
      }

      // Xử lý hiển thị số nguyên hoặc số thập phân
      if (result == result.truncateToDouble()) {
        return result.toInt().toString();
      } else {
        // Cắt bớt phần thập phân dài
        String resStr = result.toStringAsFixed(4);
        // Loại bỏ các số 0 thừa ở cuối
        while (resStr.contains('.') && (resStr.endsWith('0') || resStr.endsWith('.'))) {
          resStr = resStr.substring(0, resStr.length - 1);
        }
        return resStr;
      }
    }
    return null;
  }
}
