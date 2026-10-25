import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Переключатель в стиле macOS System Settings: капсула-трек, белый бегунок.
///
/// Нарисован собственными контейнерами вместо Material `Switch`, у которого
/// в web-сборке бегунок не прорисовывался (визуально «сплошная капсула»).
class MacSwitch extends StatelessWidget {
  const MacSwitch({
    super.key,
    required this.value,
    this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const double _trackWidth = 44;
  static const double _trackHeight = 26;

  bool get _enabled => onChanged != null;

  @override
  Widget build(BuildContext context) {
    final onColor = Theme.of(context).colorScheme.primary;
    final trackColor = !_enabled
        ? (value ? accentSoftOf(onColor) : const Color(0xFFE5E5EA))
        : (value ? onColor : const Color(0xFFD2D2D7));

    return Semantics(
      toggled: value,
      enabled: _enabled,
      label: value ? 'Отключить' : 'Включить',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _enabled ? () => onChanged!(!value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: _trackWidth,
          height: _trackHeight,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(_trackHeight / 2),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Container(
                width: _trackHeight - 4,
                height: _trackHeight - 4,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 2,
                      offset: Offset(0, 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
