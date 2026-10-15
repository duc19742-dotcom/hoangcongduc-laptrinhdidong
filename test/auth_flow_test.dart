import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hoang_cong_duc/screens/auth_screen.dart';
import 'package:hoang_cong_duc/services/auth_service.dart';

void main() {
  testWidgets(
    'Password step cannot authenticate; wrong OTP stays on OTP screen',
    (tester) async {
      final client = MockClient((request) async {
        if (request.url.path == '/auth/login') {
          return http.Response(
            jsonEncode({
              'challengeId': 'challenge',
              'maskedPhone': '+84******678',
              'expiresIn': 300,
              'resendAfter': 60,
            }),
            200,
          );
        }
        final code = (jsonDecode(request.body) as Map)['code'];
        return code == '654321'
            ? http.Response(
                jsonEncode({
                  'token': 'session',
                  'user': {'name': 'Demo'},
                }),
                200,
              )
            : http.Response(
                jsonEncode({'message': 'Mã OTP không đúng.'}),
                400,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
      });
      final auth = AuthService(client: client, baseUrl: 'http://localhost');
      addTearDown(auth.dispose);
      await tester.pumpWidget(MaterialApp(home: AuthScreen(auth: auth)));
      await tester.enterText(find.byType(TextFormField).at(0), 'demo_user');
      await tester.enterText(find.byType(TextFormField).at(1), 'Password123');
      await tester.tap(find.text('Đăng nhập và gửi OTP'));
      await tester.pumpAndSettle();
      expect(auth.isAuthenticated, isFalse);
      expect(find.text('Xác minh OTP'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '000000');
      await tester.tap(find.text('Xác minh và đăng nhập'));
      await tester.pumpAndSettle();
      expect(auth.isAuthenticated, isFalse);
      expect(
        find.text('Mã OTP không đúng.'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '),
      );
      await tester.enterText(find.byType(TextFormField), '654321');
      await tester.tap(find.text('Xác minh và đăng nhập'));
      await tester.pumpAndSettle();
      expect(auth.isAuthenticated, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
