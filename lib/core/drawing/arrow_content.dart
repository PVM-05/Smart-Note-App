import 'dart:math';
import 'package:flutter/painting.dart';
import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:flutter_drawing_board/paint_extension.dart';

/// Lớp vẽ mũi tên kế thừa từ PaintContent của flutter_drawing_board
class Arrow extends PaintContent {
  Arrow();

  Arrow.data({
    required this.startPoint,
    required this.endPoint,
    required Paint paint,
  }) : super.paint(paint);

  factory Arrow.fromJson(Map<String, dynamic> data) {
    return Arrow.data(
      startPoint: jsonToOffset(data['startPoint'] as Map<String, dynamic>),
      endPoint: jsonToOffset(data['endPoint'] as Map<String, dynamic>),
      paint: jsonToPaint(data['paint'] as Map<String, dynamic>),
    );
  }

  Offset? startPoint;
  Offset? endPoint;

  @override
  String get contentType => 'Arrow';

  @override
  void startDraw(Offset startPoint) => this.startPoint = startPoint;

  @override
  void drawing(Offset nowPoint) => endPoint = nowPoint;

  @override
  void draw(Canvas canvas, Size size, bool deeper) {
    if (startPoint == null || endPoint == null) {
      return;
    }

    // Vẽ thân mũi tên (đường thẳng)
    canvas.drawLine(startPoint!, endPoint!, paint);

    // Tính toán góc của mũi tên để vẽ đầu mũi tên
    final double dx = endPoint!.dx - startPoint!.dx;
    final double dy = endPoint!.dy - startPoint!.dy;
    
    if (dx == 0 && dy == 0) return;
    
    final double angle = atan2(dy, dx);

    // Chiều dài cánh mũi tên và góc
    // Chiều dài đầu mũi tên tỉ lệ với độ dày nét vẽ để cân đối, tối thiểu 12.0
    final double arrowHeadLength = max(12.0, paint.strokeWidth * 3.0);
    const double arrowHeadAngle = pi / 6; // 30 độ

    // Tính 2 điểm của cánh mũi tên
    final double x1 = endPoint!.dx - arrowHeadLength * cos(angle - arrowHeadAngle);
    final double y1 = endPoint!.dy - arrowHeadLength * sin(angle - arrowHeadAngle);
    final double x2 = endPoint!.dx - arrowHeadLength * cos(angle + arrowHeadAngle);
    final double y2 = endPoint!.dy - arrowHeadLength * sin(angle + arrowHeadAngle);

    final Path path = Path();
    path.moveTo(endPoint!.dx, endPoint!.dy);
    path.lineTo(x1, y1);
    path.moveTo(endPoint!.dx, endPoint!.dy);
    path.lineTo(x2, y2);

    canvas.drawPath(path, paint);
  }

  @override
  Arrow copy() => Arrow();

  @override
  Map<String, dynamic> toContentJson() {
    return <String, dynamic>{
      'startPoint': startPoint?.toJson(),
      'endPoint': endPoint?.toJson(),
      'paint': paint.toJson(),
    };
  }
}
