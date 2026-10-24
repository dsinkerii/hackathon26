import 'package:flutter_test/flutter_test.dart';
import 'package:safe_playground_operator/main.dart';
import 'package:safe_playground_operator/models/incident.dart';
import 'package:safe_playground_operator/models/visitor.dart';
import 'package:safe_playground_operator/services/operator_repository.dart';

void main() {
  testWidgets('operator tabs display incidents and visitors', (tester) async {
    final repository = _FakeRepository();
    await tester.pumpWidget(SafePlaygroundApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Видеопоток не подключён'), findsOneWidget);
    expect(find.text('Сервис подключён'), findsOneWidget);

    await tester.tap(find.text('Инциденты'));
    await tester.pumpAndSettle();
    expect(find.text('Журнал инцидентов'), findsOneWidget);
    expect(find.text('Машина в зоне'), findsOneWidget);

    await tester.tap(find.text('Посетители'));
    await tester.pumpAndSettle();
    expect(find.text('Посетители').first, findsOneWidget);
    expect(find.text('Добавить в белый список'), findsOneWidget);
  });

  testWidgets('visitor can be confirmed into the allow list', (tester) async {
    final repository = _FakeRepository();
    await tester.pumpWidget(SafePlaygroundApp(repository: repository));
    await tester.tap(find.text('Посетители'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Добавить в белый список'));
    await tester.pumpAndSettle();

    expect(repository.confirmedIds, ['visitor-1']);
    expect(find.text('В белом списке'), findsOneWidget);
  });

  testWidgets('recordings open as a separate page', (tester) async {
    await tester.pumpWidget(SafePlaygroundApp(repository: _FakeRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Записи видео'));
    await tester.pumpAndSettle();

    expect(find.text('Тестовая запись'), findsOneWidget);
    expect(find.textContaining('Демо, CC0'), findsOneWidget);
    expect(find.text('Период'), findsOneWidget);

    await tester.tap(find.byTooltip('Воспроизвести запись'));
    await tester.pump();
    expect(find.text('Тестовая запись').last, findsOneWidget);
  });

  testWidgets('recording date filter can be reset', (tester) async {
    await tester.pumpWidget(SafePlaygroundApp(repository: _FakeRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Записи видео'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Период'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Сбросить период'), findsOneWidget);
    await tester.tap(find.byTooltip('Сбросить период'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Сбросить период'), findsNothing);
    expect(find.text('Период'), findsOneWidget);
    expect(find.text('Тестовая запись'), findsOneWidget);
  });

  testWidgets('notification button opens recent events', (tester) async {
    await tester.pumpWidget(SafePlaygroundApp(repository: _FakeRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Уведомления'));
    await tester.pumpAndSettle();

    expect(find.text('Уведомления'), findsOneWidget);
    expect(find.text('VEHICLE_IN_ZONE').last, findsOneWidget);
  });
}

class _FakeRepository implements OperatorRepository {
  final List<String> confirmedIds = [];
  bool _confirmed = false;

  @override
  Future<void> confirmVisitor(String id) async {
    confirmedIds.add(id);
    _confirmed = true;
  }

  @override
  Future<List<Incident>> fetchIncidents() async => [
        Incident(
          id: 'incident-1',
          type: 'VEHICLE_IN_ZONE',
          occurredAt: DateTime.utc(2026, 1, 1),
          description: 'Автомобиль обнаружен',
        ),
      ];

  @override
  Future<List<Visitor>> fetchVisitors() async => [
        Visitor(
          id: 'visitor-1',
          status: _confirmed ? 'СВОЙ' : 'НА_РАССМОТРЕНИИ',
          firstSeenAt: DateTime.utc(2026, 1, 1),
          displayName: 'Посетитель 1',
          visitCount: 2,
        ),
      ];
}
