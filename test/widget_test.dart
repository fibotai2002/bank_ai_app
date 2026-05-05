import 'package:flutter_test/flutter_test.dart';
import 'package:bank_ai_app/main.dart';

void main() {
  testWidgets('App starts', (tester) async {
    await tester.pumpWidget(const BankAIApp());
  });
}
