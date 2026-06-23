import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance_manager/main.dart';

void main() {
  testWidgets('App builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const FamilyFinanceApp());
    expect(find.byType(FamilyFinanceApp), findsOneWidget);
  });
}
