import 'package:flutter/material.dart';

import 'models/admin_account.dart';
import 'models/incident.dart';
import 'models/admin_session.dart';
import 'screens/admin_accounts_screen.dart';
import 'screens/cameras_screen.dart';
import 'screens/incidents_screen.dart';
import 'screens/login_screen.dart';
import 'screens/monitoring_screen.dart';
import 'screens/recordings_screen.dart';
import 'screens/visitors_screen.dart';
import 'screens/whitelist_screen.dart';
import 'services/admin_repository.dart';
import 'services/auth_service.dart';
import 'services/api_operator_repository.dart';
import 'services/operator_repository.dart';
import 'theme/app_theme.dart';
import 'widgets/account_profile_details.dart';
import 'widgets/adaptivity.dart';

void main() {
  runApp(const SafePlaygroundApp());
}

class SafePlaygroundApp extends StatefulWidget {
  const SafePlaygroundApp({super.key, this.repository});

  final OperatorRepository? repository;

  @override
  State<SafePlaygroundApp> createState() => _SafePlaygroundAppState();
}

class _SafePlaygroundAppState extends State<SafePlaygroundApp> {
  @override
  void initState() {
    super.initState();
    ThemeController.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.active,
      builder: (context, _) {
        final operatorRepository =
            widget.repository ?? ApiOperatorRepository.fromEnvironment();

        return MaterialApp(
          title: 'PlayGuard AI',
          debugShowCheckedModeBanner: false,
          theme: buildPlaygroundTheme(ThemeController.active.value),
          home: widget.repository == null
              ? const AuthGate()
              : OperatorShell(repository: operatorRepository),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _authService;
  late Future<AdminSession?> _restoredSession;
  AdminSession? _session;

  @override
  void initState() {
    super.initState();
    _authService = AuthService(
      baseUri: ApiOperatorRepository.baseUriFromEnvironment(),
    );
    _restoredSession = _authService.restoreSession();
  }

  void _login(AdminSession session) {
    setState(() => _session = session);
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session != null && session.expiresAt.isAfter(DateTime.now())) {
      final repository = ApiOperatorRepository.fromEnvironment(
        tokenProvider: () async => session.accessToken,
      );
      return OperatorShell(
        repository: repository,
        session: session,
        onLogout: _logout,
      );
    }
    return FutureBuilder<AdminSession?>(
      future: _restoredSession,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StartupError(
            message: snapshot.error.toString(),
            onRetry: () => setState(
              () {
                _restoredSession = _authService.restoreSession();
              },
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final restored = snapshot.data;
        if (restored != null && restored.expiresAt.isAfter(DateTime.now())) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _session == null) _login(restored);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return LoginScreen(
          authService: _authService,
          onLogin: _login,
        );
      },
    );
  }
}

class OperatorShell extends StatefulWidget {
  const OperatorShell({
    super.key,
    required this.repository,
    this.session,
    this.onLogout,
  });

  final OperatorRepository repository;
  final AdminSession? session;
  final Future<void> Function()? onLogout;

  @override
  State<OperatorShell> createState() => _OperatorShellState();
}

class _OperatorShellState extends State<OperatorShell> {
  int _selectedIndex = 0;

  /// Полный перечень вкладок нижней навигации (индекс = позиция раздела).
  List<NavigationDestination> get _destinations {
    final adminRepository = widget.repository is AdminRepository
        ? widget.repository as AdminRepository
        : null;
    final isAdmin = widget.session?.isAdmin ?? adminRepository != null;
    return <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.videocam_outlined),
        selectedIcon: Icon(Icons.videocam),
        label: 'Мониторинг',
      ),
      const NavigationDestination(
        icon: Icon(Icons.warning_amber_outlined),
        selectedIcon: Icon(Icons.warning_amber),
        label: 'Инциденты',
      ),
      const NavigationDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: 'Посетители',
      ),
      const NavigationDestination(
        icon: Icon(Icons.how_to_reg_outlined),
        selectedIcon: Icon(Icons.how_to_reg),
        label: 'Белый список',
      ),
      if (adminRepository != null) ...[
        const NavigationDestination(
          icon: Icon(Icons.video_library_outlined),
          selectedIcon: Icon(Icons.video_library),
          label: 'Записи',
        ),
        const NavigationDestination(
          icon: Icon(Icons.camera_alt_outlined),
          selectedIcon: Icon(Icons.camera_alt),
          label: 'Камеры',
        ),
      ],
      if (adminRepository != null && isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.manage_accounts_outlined),
          selectedIcon: Icon(Icons.manage_accounts),
          label: 'Доступ',
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 960;
    final adminRepository = widget.repository is AdminRepository
        ? widget.repository as AdminRepository
        : null;
    final isAdmin = widget.session?.isAdmin ?? adminRepository != null;
    final destinations = _destinations;    final currentPage = switch (_selectedIndex) {
      0 => MonitoringScreen(
          repository: widget.repository,
          onOpenRecordings:
              adminRepository == null ? null : () => _selectTab(4),
        ),
      1 => IncidentsScreen(repository: widget.repository),
      2 => VisitorsScreen(repository: widget.repository),
      3 => WhitelistScreen(repository: widget.repository),
      4 when adminRepository != null =>
        RecordingsScreen(repository: adminRepository, isAdmin: isAdmin),
      5 when adminRepository != null =>
        CamerasScreen(repository: adminRepository, isAdmin: isAdmin),
      6 when adminRepository != null && isAdmin => AdminAccountsScreen(
          repository: adminRepository,
          currentUsername: widget.session?.username,
        ),
      _ => const SizedBox.shrink(),
    };

    // В сайдбаре белый список заменяет кнопку «Все разделы»,
    // поэтому из перечня РАЗДЕЛЫ он исключается (доступен по кнопке выше).
    final sidebarDestinations = <MapEntry<int, NavigationDestination>>[
      for (var i = 0; i < destinations.length; i++)
        if (i != 3) MapEntry(i, destinations[i]),
    ];

    if (desktop) {
      return _MacDesktopWorkspace(
        selectedIndex: _selectedIndex,
        destinations: sidebarDestinations,
        currentPage: currentPage,
        session: widget.session,
        adminRepository: adminRepository,
        onSelect: _selectTab,
        onWhitelistTap: () => _selectTab(3),
        onNotifications: () => _showNotifications(context),
        onLogout: widget.onLogout,
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final showSessionPill = width >= 600;
    // Горизонтальные минимумы нижней навигации: подписи требуют ~102px
    // на раздел, только иконки — 90px (индикатор 64px + внутренние
    // отступы 12×2). На узких телефонах и в узких окнах бар собирается
    // из компактных иконных кнопок (см. _compactBottomBar).
    final showLabels = width >= destinations.length * 102;
    final barFits = width >= destinations.length * 90;

    final bottomBar = NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _selectTab,
      labelBehavior: showLabels
          ? NavigationDestinationLabelBehavior.alwaysShow
          : NavigationDestinationLabelBehavior.alwaysHide,
      destinations: destinations,
    );
    final bottomNavigationBar = barFits
        ? bottomBar
        : _compactBottomBar();

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: accentSoftOf(scheme.primary),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.shield_outlined,
                    color: scheme.primary, size: 21),
              ),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text('PlayGuard AI',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          if (showSessionPill && widget.session != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: accentSoftOf(scheme.primary),
                        child: Text(
                          widget.session!.username.characters.first
                              .toUpperCase(),
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.session!.username} · '
                        '${widget.session!.isAdmin ? 'администратор' : 'оператор'}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Профиль',
            onPressed: () => _showProfile(context),
            icon: const Icon(Icons.person_outline),
          ),
          IconButton(
            tooltip: 'Уведомления',
            onPressed: () => _showNotifications(context),
            icon: const Icon(Icons.notifications_outlined),
          ),
          if (widget.onLogout != null)
            IconButton(
              tooltip: 'Выйти',
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: currentPage),
      bottomNavigationBar: bottomNavigationBar,
    );
  }

  /// Компактная нижняя навигация для узких экранов: иконки вместо вкладок.
  Widget _compactBottomBar() {
    final scheme = Theme.of(context).colorScheme;
    final destinations = _destinations;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: IconButton(
                  tooltip: destinations[i].label,
                  isSelected: _selectedIndex == i,
                  icon: destinations[i].icon,
                  selectedIcon:
                      destinations[i].selectedIcon ?? destinations[i].icon,
                  color: _selectedIndex == i
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _selectTab(i),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _selectTab(int index) => setState(() => _selectedIndex = index);

  Future<void> _showNotifications(BuildContext context) async {
    final incidents = widget.repository.fetchIncidents();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Уведомления'),
        content: SizedBox(
          width: adaptiveWidth(context, 420),
          child: FutureBuilder<List<Incident>>(
            future: incidents,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Не удалось загрузить уведомления: ${snapshot.error}',
                );
              }

              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 72,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.data!.isEmpty) {
                return const Text('Новых уведомлений нет.');
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: snapshot.data!
                      .take(5)
                      .map(
                        (incident) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.warning_amber_outlined),
                          title: Text(incident.type),
                          subtitle: Text(
                            incident.description ??
                                incident.occurredAt.toLocal().toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
  Future<void> _showProfile(BuildContext context) async {
    final adminRepository = widget.repository is AdminRepository
        ? widget.repository as AdminRepository
        : null;
    await showDialog<void>(
      context: context,
      builder: (_) => _ProfileDialog(
        session: widget.session,
        repository: adminRepository,
        onLogout: widget.onLogout,
      ),
    );
  }
}

class _MacDesktopWorkspace extends StatelessWidget {
  const _MacDesktopWorkspace({
    required this.selectedIndex,
    required this.destinations,
    required this.currentPage,
    required this.session,
    this.adminRepository,
    required this.onSelect,
    required this.onWhitelistTap,
    required this.onNotifications,
    required this.onLogout,
  });

  final int selectedIndex;
  final List<MapEntry<int, NavigationDestination>> destinations;
  final Widget currentPage;
  final AdminSession? session;
  final AdminRepository? adminRepository;
  final ValueChanged<int> onSelect;
  final VoidCallback onWhitelistTap;
  final VoidCallback onNotifications;
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          _MacSidebar(
            selectedIndex: selectedIndex,
            destinations: destinations,
            onSelect: onSelect,
            onWhitelistTap: onWhitelistTap,
            onNotifications: onNotifications,
            onLogout: onLogout,
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: currentPage,
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 1080)
            _MacInspector(
              session: session,
              repository: adminRepository,
              onLogout: onLogout,
            ),
        ],
      ),
    );
  }
}

class _MacSidebar extends StatelessWidget {
  const _MacSidebar({
    required this.selectedIndex,
    required this.destinations,
    required this.onSelect,
    required this.onWhitelistTap,
    required this.onNotifications,
    required this.onLogout,
  });

  final int selectedIndex;
  final List<MapEntry<int, NavigationDestination>> destinations;
  final ValueChanged<int> onSelect;
  final VoidCallback onWhitelistTap;
  final VoidCallback onNotifications;
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 208,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF292B30), Color(0xFF202226)],
        ),
        border: Border(right: BorderSide(color: Color(0x22000000))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF514B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    size: 17,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Панель управления',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: _MacSidebarRow(
              icon: Icons.how_to_reg_outlined,
              label: 'Белый список',
              onTap: onWhitelistTap,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 12, 8),
            child: Row(
              children: [
                const Text(
                  'РАЗДЕЛЫ',
                  style: TextStyle(
                    color: Color(0xFF9699A0),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8,
                  ),
                ),
                const Spacer(),
                Text(
                  '${destinations.length}',
                  style: const TextStyle(color: Color(0xFF9699A0), fontSize: 9),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final entry = destinations[index];
                return _MacSidebarRow(
                  icon: _sidebarIconFor(entry.value),
                  label: entry.value.label,
                  selected: selectedIndex == entry.key,
                  onTap: () => onSelect(entry.key),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x24FFFFFF))),
            ),
            child: Column(
              children: [
                _MacSidebarRow(
                  icon: Icons.notifications_none,
                  label: 'Уведомления',
                  onTap: onNotifications,
                ),
                if (onLogout != null)
                  _MacSidebarRow(
                    icon: Icons.logout,
                    label: 'Выйти',
                    onTap: onLogout,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _sidebarIconFor(NavigationDestination destination) =>
    destination.selectedIcon is Icon
        ? ((destination.selectedIcon as Icon).icon ?? Icons.circle_outlined)
        : Icons.circle_outlined;

class _MacSidebarRow extends StatelessWidget {
  const _MacSidebarRow({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? const Color(0xFF41444B) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 32,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Row(
                children: [
                  Icon(icon,
                      size: 15,
                      color: selected
                          ? const Color(0xFF75B7FF)
                          : const Color(0xFFB7B9BF)),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            selected ? Colors.white : const Color(0xFFD2D3D7),
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MacInspector extends StatelessWidget {
  const _MacInspector({
    required this.session,
    this.repository,
    this.onLogout,
  });

  final AdminSession? session;
  final AdminRepository? repository;
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    final username = session?.username ?? 'Оператор';
    final role = session?.isAdmin == true ? 'Администратор' : 'Оператор';
    final hasSession = session != null;
    final initial =
        username.isEmpty ? 'О' : username.characters.first.toUpperCase();
    return Container(
      width: 190,
      decoration: const BoxDecoration(
        color: Color(0xFFE9EAEC),
        border: Border(left: BorderSide(color: Color(0xFFD8D9DC))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 104,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFB8C8DD), Color(0xFFE6D8CC)],
              ),
            ),
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: IconButton(
                  tooltip: 'Профиль',
                  onPressed: () => _openProfile(context),
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xAAFFFFFF),
                    hoverColor: const Color(0x24FFFFFF),
                    focusColor: const Color(0x24FFFFFF),
                    highlightColor: const Color(0x33FFFFFF),
                  ),
                  icon: const Icon(Icons.person_outline, size: 24),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor:
                          Theme.of(context).colorScheme.primary,
                      child: Text(
                        initial,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF222328),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  role,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF66686E),
                  ),
                ),
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 14),
                const Text(
                  'СТАТУС',
                  style: TextStyle(
                    color: Color(0xFF85878D),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      color: hasSession
                          ? const Color(0xFF34C759)
                          : const Color(0xFF8E8E93),
                      size: 8,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        hasSession ? 'Сеанс активен' : 'Режим просмотра',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF34353A)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                const Text(
                  'РАБОЧЕЕ МЕСТО',
                  style: TextStyle(
                    color: Color(0xFF85878D),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 8),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.videocam_outlined,
                        size: 14, color: Color(0xFF64666C)),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'PlayGuard AI',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.35,
                          color: Color(0xFF45464B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 14, color: Color(0xFF777980)),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Панель оператора',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Color(0xFF62646A)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openProfile(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ProfileDialog(
        session: session,
        repository: repository,
        onLogout: onLogout,
      ),
    );
  }
}

/// Просмотр профиля текущего пользователя: сведения аккаунта загружаются
/// с сервера (`GET /api/v1/auth/me`); при недоступности показываются
/// только данные сеанса.
class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({
    required this.session,
    this.repository,
    this.onLogout,
  });

  final AdminSession? session;
  final AdminRepository? repository;
  final Future<void> Function()? onLogout;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late Future<AdminAccount?> _profile = _loadProfile();

  Future<AdminAccount?> _loadProfile() async {
    final repository = widget.repository;
    if (repository == null) return null;
    return repository.fetchProfile();
  }

  void _retry() {
    setState(() => _profile = _loadProfile());
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final hasSession = session != null;
    final username = session?.username ?? '';
    final displayName = username.isEmpty ? 'Оператор' : username;
    final role = session?.isAdmin == true ? 'Администратор' : 'Оператор';
    return AlertDialog(
      title: const Text('Профиль'),
      content: SizedBox(
        width: adaptiveWidth(context, 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    displayName.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        role,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6E6E73),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            const _ThemeSwatches(),
            const Divider(height: 24),
            FutureBuilder<AdminAccount?>(
              future: _profile,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 18, color: Color(0xFFFF3B30)),
                        const SizedBox(width: 7),
                        const Expanded(
                          child: Text(
                            'Не удалось загрузить данные аккаунта.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: _retry,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  );
                }
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final account = snapshot.data;
                if (account == null) {
                  return const Text(
                    'Подробные сведения аккаунта доступны только при работе с сервером.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6E6E73)),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AccountDetailRow(
                        icon: Icons.alternate_email,
                        label: 'Логин',
                        value: account.username),
                    AccountDetailRow(
                        icon: Icons.shield_outlined,
                        label: 'Роль',
                        value: account.role == 'ADMIN'
                            ? 'Администратор'
                            : 'Оператор'),
                    AccountDetailRow(
                      icon: Icons.verified_user_outlined,
                      label: 'Статус',
                      value: account.enabled ? 'Активна' : 'Отключена',
                      valueColor: account.enabled
                          ? const Color(0xFF248A3D)
                          : const Color(0xFFFF3B30),
                    ),
                    AccountDetailRow(
                        icon: Icons.tag, label: 'ID', value: account.id),
                    AccountDetailRow(
                        icon: Icons.history,
                        label: 'Создан',
                        value: formatAccountTimestamp(account.createdAt)),
                  ],
                );
              },
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: hasSession
                      ? const Color(0xFF34C759)
                      : const Color(0xFF8E8E93),
                ),
                const SizedBox(width: 7),
                Text(hasSession ? 'Сеанс активен' : 'Режим просмотра'),
              ],
            ),
            if (hasSession) ...[
              const SizedBox(height: 8),
              Text(
                'Сеанс истекает: ${_formatTimestamp(session.expiresAt)}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Рабочее место: PlayGuard AI',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
      actions: [
        if (hasSession && widget.onLogout != null)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF3B30),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              widget.onLogout!();
            },
            child: const Text('Выйти'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40),
                    const SizedBox(height: 12),
                    const Text('Не удалось восстановить сеанс'),
                    const SizedBox(height: 8),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: onRetry,
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// Выбор цветовой темы: кружки акцентов, текущая отмечена галочкой.
class _ThemeSwatches extends StatelessWidget {
  const _ThemeSwatches();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.active,
      builder: (context, _) {
        final active = ThemeController.active.value;
        final scheme = Theme.of(context).colorScheme;
        return Row(
          children: [
            Icon(Icons.palette_outlined,
                size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Цветовая тема',
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
            for (final theme in AppThemes.all)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _ThemeDot(theme: theme, selected: theme == active),
              ),
          ],
        );
      },
    );
  }
}

class _ThemeDot extends StatelessWidget {
  const _ThemeDot({required this.theme, required this.selected});

  final PlayTheme theme;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: theme.label,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => ThemeController.select(theme),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.accent,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 3,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
