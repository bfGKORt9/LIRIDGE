import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liridge/main.dart';

void main() {
  testWidgets('LIRIDGE System Integrity Test', (WidgetTester tester) async {
    // LIRIDGEコアシステムをテスト環境にマウント
    await tester.pumpWidget(const LiridgeApp());

    // UIツリーが正常に構築され、MaterialAppが存在することを確認
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
