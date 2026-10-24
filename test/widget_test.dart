import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/state/app_state.dart';

void main() {
  testWidgets('PlayGuardApp smoke test', (WidgetTester tester) async {
    final state = AppState();
    await tester.pumpWidget(PlayGuardApp(state: state));

    // Verify app starts and shows title/searchbar
    expect(find.text('PlayGuardAI'), findsOneWidget);
    expect(find.text('Подъезд'), findsOneWidget);
    expect(find.text('Чат'), findsOneWidget);
    expect(find.text('Активность'), findsOneWidget);
  });
}
