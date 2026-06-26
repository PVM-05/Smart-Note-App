// lib/utils/math_parser.dart

class _ParserState {
  final String str;
  int pos = -1;
  int ch = -1;

  _ParserState(this.str) {
    nextChar();
  }

  void nextChar() {
    pos++;
    ch = (pos < str.length) ? str.codeUnitAt(pos) : -1;
  }

  bool eat(int charToEat) {
    while (ch == 32) { // khoảng trắng
      nextChar();
    }
    if (ch == charToEat) {
      nextChar();
      return true;
    }
    return false;
  }
}

class MathParser {
  /// Hàm evaluate: Kiểm tra xem văn bản trước con trỏ có phải là phép tính không.
  /// Nếu có, trả về kết quả dưới dạng chuỗi (String). Nếu không, trả về null.
  /// Hỗ trợ các phép tính phức tạp nhiều toán tử, độ ưu tiên toán tử và đóng mở ngoặc.
  static String? evaluate(String text) {
    if (text.isEmpty) return null;

    // Tìm kiếm biểu thức toán học kết thúc bằng dấu '=' ở cuối chuỗi văn bản.
    // Hỗ trợ số, toán tử (+ - * / % x X :), khoảng trắng và dấu ngoặc.
    final regex = RegExp(r'([\d\.\+\-\*\/\(\)\s:xX%]+)\s*=$');
    final match = regex.firstMatch(text.trimRight());
    if (match == null) return null;

    String expression = match.group(1) ?? '';
    if (expression.isEmpty) return null;

    // Làm sạch biểu thức
    String sanitized = expression.replaceAll(' ', '');
    sanitized = sanitized.replaceAll('x', '*').replaceAll('X', '*');
    sanitized = sanitized.replaceAll(':', '/');

    // Đảm bảo chứa ít nhất một toán tử để không tính toán các số đơn lẻ như "123 ="
    final hasOperator = RegExp(r'[\+\-\*\/%]').hasMatch(sanitized);
    if (!hasOperator) return null;

    try {
      final state = _ParserState(sanitized);
      double val = _parseExpression(state);
      if (state.pos < sanitized.length) {
        return null; // Có ký tự không hợp lệ sau biểu thức
      }

      // Xử lý hiển thị số nguyên hoặc số thập phân
      if (val == val.truncateToDouble()) {
        return val.toInt().toString();
      } else {
        // Cắt bớt phần thập phân dài
        String resStr = val.toStringAsFixed(4);
        // Loại bỏ các số 0 thừa ở cuối
        while (resStr.contains('.') && (resStr.endsWith('0') || resStr.endsWith('.'))) {
          resStr = resStr.substring(0, resStr.length - 1);
        }
        return resStr;
      }
    } catch (_) {
      return null;
    }
  }

  // Biểu thức: Phép cộng (+) và trừ (-)
  static double _parseExpression(_ParserState state) {
    double x = _parseTerm(state);
    for (;;) {
      if (state.eat(43)) { // '+'
        x += _parseTerm(state);
      } else if (state.eat(45)) { // '-'
        x -= _parseTerm(state);
      } else {
        return x;
      }
    }
  }

  // Số hạng: Phép nhân (*), chia (/) và chia lấy dư (%)
  static double _parseTerm(_ParserState state) {
    double x = _parseFactor(state);
    for (;;) {
      if (state.eat(42)) { // '*'
        x *= _parseFactor(state);
      } else if (state.eat(47)) { // '/'
        double divisor = _parseFactor(state);
        if (divisor == 0) throw Exception("Division by zero");
        x /= divisor;
      } else if (state.eat(37)) { // '%'
        double divisor = _parseFactor(state);
        if (divisor == 0) throw Exception("Division by zero");
        x %= divisor;
      } else {
        return x;
      }
    }
  }

  // Nhân tử: Số dương/âm đơn vị, Dấu ngoặc () hoặc Số
  static double _parseFactor(_ParserState state) {
    if (state.eat(43)) return _parseFactor(state); // cộng đơn vị (+)
    if (state.eat(45)) return -_parseFactor(state); // trừ đơn vị (-)

    double x;
    int startPos = state.pos;
    if (state.eat(40)) { // '('
      x = _parseExpression(state);
      state.eat(41); // ')'
    } else if ((state.ch >= 48 && state.ch <= 57) || state.ch == 46) { // các chữ số hoặc dấu chấm thập phân
      while ((state.ch >= 48 && state.ch <= 57) || state.ch == 46) {
        state.nextChar();
      }
      x = double.parse(state.str.substring(startPos, state.pos));
    } else {
      throw Exception("Unexpected character: ${String.fromCharCode(state.ch)}");
    }

    return x;
  }
}
