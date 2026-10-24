import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_playground_operator/main.dart';
import 'package:safe_playground_operator/models/admin_account.dart';
import 'package:safe_playground_operator/models/camera.dart';
import 'package:safe_playground_operator/models/incident.dart';
import 'package:safe_playground_operator/models/video_recording.dart';
import 'package:safe_playground_operator/models/visitor.dart';
import 'package:safe_playground_operator/screens/cameras_screen.dart';
import 'package:safe_playground_operator/services/admin_repository.dart';
import 'package:safe_playground_operator/services/operator_repository.dart';
import 'package:safe_playground_operator/theme/app_theme.dart';
import 'package:safe_playground_operator/widgets/mac_switch.dart';

void main() {
  // Статическое состояние темы не должно перетекать между тестами.
  setUp(() => ThemeController.active.value = AppThemes.blue);

  testWidgets('desktop opens in a macOS-style app window', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(SafePlaygroundApp(repository: _FakeRepository()));
    await tester.pumpAndSettle();

    expect(find.text('РАЗДЕЛЫ'), findsOneWidget);
    expect(find.text('Белый список'), findsOneWidget);
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

    // Подтверждённый посетитель появляется во вкладке «Белый список».
    await tester.tap(find.byIcon(Icons.how_to_reg_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Посетитель 1'), findsOneWidget);
    expect(find.text('Посетитель 2'), findsOneWidget);

    // Исключение возвращает посетителя в статус «на рассмотрении».
    final excludeForVisitor1 = find.descendant(
      of: find.ancestor(
          of: find.text('Посетитель 1'), matching: find.byType(ListTile)),
      matching: find.byTooltip('Исключить из белого списка'),
    );
    await tester.tap(excludeForVisitor1);
    await tester.pumpAndSettle();

    expect(repository.excludedVisitorIds, ['visitor-1']);
    expect(find.text('Посетитель 1'), findsNothing);

    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();
    expect(find.text('Добавить в белый список'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('whitelist visitor can be deleted from the list',
      (tester) async {
    final repository = _FakeRepository();
    await tester.pumpWidget(SafePlaygroundApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.how_to_reg_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Посетитель 2'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Удалить навсегда'));
    await tester.pumpAndSettle();

    expect(find.text('Удалить навсегда'), findsWidgets);
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    expect(find.textContaining('В белом списке пока никого нет'),
        findsOneWidget);
    expect(repository.removedVisitorIds, ['visitor-2']);
    expect(tester.takeException(), isNull);
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

  testWidgets('account profile of another user opens from the access list',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(SafePlaygroundApp(repository: _FakeRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Доступ'));
    await tester.pumpAndSettle();

    expect(find.text('admin'), findsOneWidget);
    expect(find.text('operator2'), findsOneWidget);

    await tester.tap(find.text('operator2'));
    await tester.pumpAndSettle();

    expect(find.text('Профиль'), findsOneWidget);
    expect(find.text('Логин'), findsOneWidget);
    expect(find.text('Отключена'), findsOneWidget);
    expect(find.text('Включить'), findsOneWidget);

    await tester.tap(find.text('Включить'));
    await tester.pumpAndSettle();

    expect(find.text('Активна'), findsOneWidget);
    expect(find.text('Отключить'), findsOneWidget);

    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.text('Профиль'), findsNothing);
    expect(tester.takeException(), isNull);

    // Переключатель включения (macOS-стиль): выключенный аккаунт
    // operator2 включается тапом по тумблеру в списке.
    final toggles = find.byType(MacSwitch);
    expect(toggles, findsNWidgets(2));

    // operator2 был включён из диалога — гасим тумблером в списке…
    final operatorSwitch = find.descendant(
      of: find.ancestor(
        of: find.text('operator2'),
        matching: find.byType(ListTile),
      ),
      matching: find.byType(MacSwitch),
    );
    expect(operatorSwitch, findsOneWidget);
    expect(tester.widget<MacSwitch>(operatorSwitch).value, isTrue);
    await tester.tap(operatorSwitch);
    await tester.pumpAndSettle();
    expect(find.text('Оператор · отключена'), findsOneWidget);
    // …и включаем обратно тумблером.
    await tester.tap(operatorSwitch);
    await tester.pumpAndSettle();
    expect(find.text('Оператор · активна'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('access list allows deleting non-primary accounts',
      (tester) async {
    final repository = _FakeRepository();
    await tester.pumpWidget(SafePlaygroundApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Доступ'));
    await tester.pumpAndSettle();

    // У главного админа кнопки удаления нет, у оператора — есть.
    expect(find.text('Администратор · главная · активна'), findsOneWidget);
    expect(find.byTooltip('Удалить пользователя'), findsOneWidget);

    await tester.tap(find.byTooltip('Удалить пользователя'));
    await tester.pumpAndSettle();

    expect(find.text('Удалить учётную запись?'), findsOneWidget);
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    // Аккаунт удалён из списка и из фейкового репозитория.
    expect(repository.deletedAccountIds, ['account-operator']);
    expect(find.text('operator2'), findsNothing);
    expect(find.text('admin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('color theme can be switched from the profile dialog',
      (tester) async {
    await tester.pumpWidget(SafePlaygroundApp(repository: _FakeRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Профиль'));
    await tester.pumpAndSettle();

    expect(find.text('Цветовая тема'), findsOneWidget);

    await tester.tap(find.byTooltip('Бирюзовая'));
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      materialApp.theme?.colorScheme.primary,
      const Color(0xFF30B0C7),
    );
  });

  testWidgets('narrow window falls back to the compact bottom bar',
      (tester) async {
    // 490px: NavigationBar не помещается (по ~90px на вкладку нужно 630px),
    // должен использоваться компактный бар из иконок.
    tester.view.physicalSize = const Size(490, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(SafePlaygroundApp(repository: _FakeRepository()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('Мониторинг'), findsOneWidget);
    expect(find.byTooltip('Белый список'), findsOneWidget);
    expect(find.byTooltip('Посетители'), findsOneWidget);

    // Переход по компактному бару работает.
    await tester.tap(find.byTooltip('Посетители'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom bar shows labels when the window is wide enough',
      (tester) async {
    // 640px: NavigationBar влезает (7 вкладок по 90px = 630px),
    // но подписи ещё скрыты (порог 102px на вкладку).
    tester.view.physicalSize = const Size(640, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(SafePlaygroundApp(repository: _FakeRepository()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cameras screen allows adding camera with rtsp url',
      (tester) async {
    final repo = _FakeRepository();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CamerasScreen(repository: repo, isAdmin: true),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Добавить камеру'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Название'), 'Тест RTSP');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'URL видеопотока (необязательно)'),
        'rtsp://127.0.0.1:8554/test');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(find.text('Укажите абсолютный URL (HTTP, HTTPS или RTSP)'),
        findsNothing);
  });

  testWidgets('monitoring screen displays live camera indicator for streamed cameras',
      (tester) async {
    final repo = _StreamFakeRepository();
    await tester.pumpWidget(SafePlaygroundApp(repository: repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('В ЭФИРЕ'), findsOneWidget);
    expect(find.text('Уличная камера'), findsOneWidget);
  });
}

class _StreamFakeRepository extends _FakeRepository {
  @override
  Future<List<Camera>> fetchCameras() async => [
        const Camera(
          id: 'camera-stream',
          name: 'Уличная камера',
          location: 'Площадка',
          streamUrl: 'https://example.com/stream.m3u8',
          enabled: true,
        ),
      ];
}

class _FakeRepository implements OperatorRepository, AdminRepository {
  final List<String> confirmedIds = [];
  bool _confirmed = false;
  final List<String> removedVisitorIds = [];
  final List<String> excludedVisitorIds = [];
  bool _visitor2Removed = false;

  @override
  Future<void> confirmVisitor(String id) async {
    confirmedIds.add(id);
    _confirmed = true;
  }

  @override
  Future<void> excludeVisitor(String id) async {
    excludedVisitorIds.add(id);
    if (id == 'visitor-1') _confirmed = false;
  }

  @override
  Future<List<Visitor>> fetchWhitelist() async {
    final all = await fetchVisitors();
    return [
      ...all.where((visitor) => visitor.isWhitelisted),
      if (!_visitor2Removed)
        Visitor(
          id: 'visitor-2',
          status: 'TRUSTED',
          firstSeenAt: DateTime.utc(2026, 1, 2),
          displayName: 'Посетитель 2',
          visitCount: 5,
          photoUrl: 'https://example.test/photo-2.jpg',
        ),
    ];
  }

  @override
  Future<void> removeVisitor(String id) async {
    removedVisitorIds.add(id);
    if (id == 'visitor-2') _visitor2Removed = true;
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

  // Изменяемый статус аккаунтов: setAccountEnabled меняет его,
  // fetchAccounts отдаёт актуальные значения (как настоящий backend).
  final List<String> deletedAccountIds = [];
  final Map<String, ({String username, String role, bool primary})> _accounts = {
    'account-admin': (username: 'admin', role: 'ADMIN', primary: true),
    'account-operator':
        (username: 'operator2', role: 'OPERATOR', primary: false),
  };
  final Map<String, bool> _accountEnabled = {
    'account-admin': true,
    'account-operator': false,
  };

  @override
  Future<List<AdminAccount>> fetchAccounts() async => [
        for (final entry in _accounts.entries)
          AdminAccount(
            id: entry.key,
            username: entry.value.username,
            role: entry.value.role,
            enabled: _accountEnabled[entry.key] ?? false,
            createdAt: DateTime.utc(2026, 1, 1),
            primary: entry.value.primary,
          ),
      ];

  @override
  Future<AdminAccount> fetchProfile() async => AdminAccount(
        id: 'profile-1',
        username: 'admin',
        role: 'ADMIN',
        enabled: true,
        createdAt: DateTime.utc(2026, 1, 1),
        primary: true,
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
  Future<void> deleteAccount(String id) async {
    deletedAccountIds.add(id);
    _accounts.remove(id);
    _accountEnabled.remove(id);
  }

  @override
  Future<AdminAccount> setAccountEnabled(String id, bool enabled) async {
    await Future<void>.value();
    if (_accounts.containsKey(id)) {
      _accountEnabled[id] = enabled;
      final info = _accounts[id]!;
      return AdminAccount(
        id: id,
        username: info.username,
        role: info.role,
        enabled: enabled,
        createdAt: DateTime.utc(2026, 1, 1),
        primary: info.primary,
      );
    }
    return AdminAccount(
      id: id,
      username: 'user',
      role: 'OPERATOR',
      enabled: enabled,
      createdAt: DateTime.utc(2026),
    );
  }
}
