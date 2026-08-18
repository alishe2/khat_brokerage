import 'package:flutter_test/flutter_test.dart';
import 'package:khat_brokerage/app.dart';

void main() {
  testWidgets('Khat Brokerage app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const KhatBrokerageApp());

    expect(find.text('Khat Brokerage'), findsOneWidget);
    expect(find.text('Business Management System'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}