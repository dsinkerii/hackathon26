import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_playground_operator/main.dart';
import 'package:safe_playground_operator/models/admin_account.dart';
import 'package:safe_playground_operator/models/camera.dart';
import 'package:safe_playground_operator/models/incident.dart';
import 'package:safe_playground_operator/models/video_recording.dart';
import 'package:safe_playground_operator/models/visitor.dart';
import 'package:safe_playground_operator/services/admin_repository.dart';
import 'package:safe_playground_operator/services/operator_repository.dart';

void main() {
  testWidgets('desktop opens in a macOS-style app window', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(SafePlaygroundApp(repository: _FakeRepository()));
    await tester.pumpAndSettle();

    expect(find.text('РАЗДЕЛЫ'), findsOneWidget);
    expect(find.text('Все разделы'), findsOneWidget);
    expect(find.text('Уведомления'), findsOneWidget);
    expect(find.text('Видеопоток не подключён'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Уведомления'));
    await tester.pumpAndSettle();
    expect(find.text('VEHICLE_IN_ZONE').last, findsOneWidget);
    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Инциденты').first);
    await tester.pumpAndSettle();
    expect(find.text('Журнал инцидентов'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('recording catalog opens from monitoring', (tester) async {
    await tester.pumpWidget(SafePlaygroundApp(repository: _FakeRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Записи видео'));
    await tester.pumpAndSettle();

    expect(find.text('Видеоархив'), findsOneWidget);
    expect(find.text('Архив с камеры'), findsOneWidget);
    expect(find.text('Все камеры'), findsOneWidget);
  });

  testWidgets('recording date filter can be reset', (tester) async {
    await tester.pumpWidget(SafePlaygroundApp(repository: _FakeRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Записи видео'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Весь период'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Сбросить'), findsOneWidget);
    await tester.tap(find.text('Сбросить'));
    await tester.pumpAndSettle();

    expect(find.text('Сбросить'), findsNothing);
    expect(find.text('Весь период'), findsOneWidget);
    expect(find.text('Архив с камеры'), findsOneWidget);
  });

  testWidgets('notification button opens recent events', (tester) async {
    await tester.pumpWidget(SafePlaygroundApp(repository: _FakeRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Уведомления'));
    await tester.pumpAndSettle();

    expect(find.text('Уведомления'), findsOneWidget);
    expect(find.text('VEHICLE_IN_ZONE').last, findsOneWidget);
  });

  testWidgets('profile dialog shows the signed-in account details',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(SafePlaygroundApp(repository: _FakeRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Профиль'));
    await tester.pumpAndSettle();

    expect(find.text('Профиль'), findsOneWidget);
    expect(find.text('Логин'), findsOneWidget);
    expect(find.text('Роль'), findsOneWidget);
    expect(find.text('Статус'), findsOneWidget);
    expect(find.text('Активна'), findsOneWidget);
    expect(find.text('ID'), findsOneWidget);
    expect(find.text('Режим просмотра'), findsWidgets);

    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.text('Логин'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone layout uses bottom navigation and compact dialogs',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(SafePlaygroundApp(repository: _FakeRepository()));
    await tester.pumpAndSettle();

    expect(find.text('РАЗДЕЛЫ'), findsNothing);
    expect(find.byTooltip('Профиль'), findsOneWidget);
    expect(find.byTooltip('Уведомления'), findsOneWidget);

    await tester.tap(find.byTooltip('Профиль'));
    await tester.pumpAndSettle();
    expect(find.text('Профиль'), findsOneWidget);
    expect(find.text('Логин'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Уведомления'));
    await tester.pumpAndSettle();
    expect(find.text('VEHICLE_IN_ZONE').last, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeRepository implements OperatorRepository, AdminRepository {
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

  @override
  Future<List<Camera>> fetchCameras() async => const [
        Camera(
          id: 'camera-1',
          name: 'Главный вход',
          location: 'Вход',
          enabled: true,
        ),
      ];

  @override
  Future<List<VideoRecording>> fetchRecordings({
    String? cameraId,
    bool? withoutCamera,
    DateTime? from,
    DateTime? to,
  }) async =>
      [
        VideoRecording(
          id: 'recording-1',
          cameraId: 'camera-1',
          cameraName: 'Главный вход',
          title: 'Архив с камеры',
          eventType: 'Проверка',
          recordedAt: DateTime.utc(2026, 1, 1, 10),
          durationSeconds: 30,
          videoUrl: 'https://example.test/recording.mp4',
        ),
      ].where((recording) {
        if (withoutCamera != null &&
            withoutCamera &&
            recording.cameraId != null) {
          return false;
        }
        if (cameraId != null && recording.cameraId != cameraId) return false;
        if (from != null && recording.recordedAt.isBefore(from)) return false;
        if (to != null && !recording.recordedAt.isBefore(to)) return false;
        return true;
      }).toList();

  @override
  Future<Camera> createCamera({
    required String name,
    String? location,
    String? streamUrl,
  }) async =>
      Camera(
        id: 'camera-new',
        name: name,
        location: location,
        streamUrl: streamUrl,
        enabled: true,
      );

  @override
  Future<Camera> updateCamera(
    String id, {
    required String name,
    String? location,
    String? streamUrl,
    required bool enabled,
  }) async =>
      Camera(
        id: id,
        name: name,
        location: location,
        streamUrl: streamUrl,
        enabled: enabled,
      );

  @override
  Future<void> deleteCamera(String id) async {}

  @override
  Future<VideoRecording> createRecording({
    String? cameraId,
    required String title,
    String? eventType,
    required DateTime recordedAt,
    int? durationSeconds,
    required String videoUrl,
  }) async =>
      VideoRecording(
        id: 'recording-new',
        cameraId: cameraId,
        cameraName: cameraId == null ? null : 'Главный вход',
        title: title,
        eventType: eventType,
        recordedAt: recordedAt,
        durationSeconds: durationSeconds,
        videoUrl: videoUrl,
      );

  @override
  Future<VideoRecording> updateRecording(
    String id, {
    String? cameraId,
    required String title,
    String? eventType,
    required DateTime recordedAt,
    int? durationSeconds,
    required String videoUrl,
  }) async =>
      VideoRecording(
        id: id,
        cameraId: cameraId,
        cameraName: cameraId == null ? null : 'Главный вход',
        title: title,
        eventType: eventType,
        recordedAt: recordedAt,
        durationSeconds: durationSeconds,
        videoUrl: videoUrl,
      );

  @override
  Future<void> deleteRecording(String id) async {}

  @override
  Future<List<AdminAccount>> fetchAccounts() async => const [];

  @override
  Future<AdminAccount> fetchProfile() async => AdminAccount(
        id: 'profile-1',
        username: 'admin',
        role: 'ADMIN',
        enabled: true,
        createdAt: DateTime.utc(2026, 1, 1),
      );

  @override
  Future<AdminAccount> createAccount({
    required String username,
    required String password,
    required String role,
  }) async =>
      AdminAccount(
        id: 'user-new',
        username: username,
        role: role,
        enabled: true,
        createdAt: DateTime.utc(2026),
      );

  @override
  Future<AdminAccount> setAccountEnabled(String id, bool enabled) async =>
      AdminAccount(
        id: id,
        username: 'operator',
        role: 'OPERATOR',
        enabled: enabled,
        createdAt: DateTime.utc(2026),
      );
}
