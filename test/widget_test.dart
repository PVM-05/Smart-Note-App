import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_note_app/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyStateWidget renders properly and triggers action', (WidgetTester tester) async {
    bool clicked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyStateWidget(
            icon: Icons.note_alt_outlined,
            title: 'Chưa có ghi chú nào',
            subtitle: 'Hãy nhấn nút "+" bên dưới để tạo ghi chú đầu tiên của bạn.',
            actionLabel: 'Thêm ngay',
            onAction: () {
              clicked = true;
            },
          ),
        ),
      ),
    );

    // Let the animation finish
    await tester.pumpAndSettle();

    // Verify icons, title and subtitle render correctly
    expect(find.byIcon(Icons.note_alt_outlined), findsOneWidget);
    expect(find.text('Chưa có ghi chú nào'), findsOneWidget);
    expect(find.text('Hãy nhấn nút "+" bên dưới để tạo ghi chú đầu tiên của bạn.'), findsOneWidget);

    // Verify button renders and triggers action
    expect(find.text('Thêm ngay'), findsOneWidget);
    await tester.tap(find.text('Thêm ngay'));
    expect(clicked, isTrue);
  });
}
