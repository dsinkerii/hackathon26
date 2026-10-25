import 'package:flutter/material.dart';
import '../../state/app_state.dart';

class SettingsScreen extends StatefulWidget {
  final AppState state;

  const SettingsScreen({super.key, required this.state});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _apartmentController;
  late TextEditingController _addressController;
  late ThemeMode _themeMode;
  late Color _seedColor;

  static const List<Color> _paletteColors = [
    Color(0xFF6750A4), // M3 default baseline purple
    Color(0xFF0061A4), // Blue
    Color(0xFF006A60), // Teal
    Color(0xFF386A20), // Green
    Color(0xFF8B5000), // Amber
    Color(0xFF9C4146), // Terracotta
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.state.settings;
    _nameController = TextEditingController(text: s.userName);
    _apartmentController = TextEditingController(text: s.apartment);
    _addressController = TextEditingController(text: s.address);
    _themeMode = s.themeMode;
    _seedColor = s.seedColor;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _apartmentController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  bool _hasUnsavedChanges() {
    final s = widget.state.settings;
    return _nameController.text.trim() != s.userName ||
        _apartmentController.text.trim() != s.apartment ||
        _addressController.text.trim() != s.address;
  }

  void _save() {
    widget.state.updateSettings(
      widget.state.settings.copyWith(
        userName: _nameController.text.trim(),
        apartment: _apartmentController.text.trim(),
        address: _addressController.text.trim(),
        themeMode: _themeMode,
        seedColor: _seedColor,
      ),
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Настройки сохранены')),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges()) {
      return true;
    }
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Несохранённые изменения'),
        content: const Text(
          'Вы внесли изменения в настройки. Выйти без сохранения?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Остаться'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    return shouldLeave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: !_hasUnsavedChanges(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _onWillPop();
        if (shouldLeave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Настройки'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _save,
          tooltip: 'Сохранить настройки',
          child: const Icon(Icons.save_rounded),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              // Section 1: Профиль
              _buildSectionHeader(context, 'Профиль жильца'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Имя и фамилия',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _apartmentController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Квартира',
                          prefixIcon: Icon(Icons.home_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _addressController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Адрес дома',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Section 2: Тема (just 'Тема', no 'Material You' mention)
              _buildSectionHeader(context, 'Тема'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Режим отображения',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('Светлая'),
                              icon: Icon(Icons.light_mode_outlined),
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('Авто'),
                              icon: Icon(Icons.brightness_auto_outlined),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('Тёмная'),
                              icon: Icon(Icons.dark_mode_outlined),
                            ),
                          ],
                          selected: {_themeMode},
                          onSelectionChanged: (set) {
                            final newMode = set.first;
                            setState(() {
                              _themeMode = newMode;
                            });
                            widget.state.updateSettings(
                              widget.state.settings.copyWith(themeMode: newMode),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Цвет темы',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Row of circular color buttons without text labels
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _paletteColors.map((color) {
                            final isSelected =
                                _seedColor.toARGB32() == color.toARGB32();
                            return Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _seedColor = color;
                                  });
                                  widget.state.updateSettings(
                                    widget.state.settings.copyWith(seedColor: color),
                                  );
                                },
                                borderRadius: BorderRadius.circular(24),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutBack,
                                  width: isSelected ? 48 : 42,
                                  height: isSelected ? 48 : 42,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? colorScheme.onSurface
                                          : Colors.transparent,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      if (isSelected)
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                    ],
                                  ),
                                  child: isSelected
                                      ? const Center(
                                          child: Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
