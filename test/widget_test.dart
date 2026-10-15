import 'package:flutter_test/flutter_test.dart';
import 'package:hoang_cong_duc/main.dart';
import 'package:hoang_cong_duc/screens/home_screen.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Application opens login before home', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Đăng nhập và gửi OTP'), findsOneWidget);
    expect(find.text('Nhiệt độ'), findsNothing);
  });
  testWidgets('Navigation exposes each assignment screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    for (final label in ['Báo thức', 'Dịch thuật', 'Cá nhân', 'Nhóm']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      switch (label) {
        case 'Báo thức':
          expect(find.text('Đặt trong Đồng hồ điện thoại'), findsOneWidget);
        case 'Dịch thuật':
          expect(find.text('Text / Giọng nói'), findsOneWidget);
        case 'Cá nhân':
          expect(find.text('Mở Ứng Dụng YouTube'), findsOneWidget);
        case 'Nhóm':
          expect(find.text('Hoàng Công Đức'), findsOneWidget);
          await tester.drag(find.text('Hoàng Công Đức'), const Offset(-700, 0));
          await tester.pumpAndSettle();
          expect(find.text('Nguyễn Minh Anh (mẫu)'), findsOneWidget);
      }
    }
  });
}
