import 'package:flutter/material.dart';

/// Строка сведений профиля: иконка, подпись, значение.
/// Используется в диалоге «Мой профиль» и в карточках профилей
/// других пользователей из раздела «Доступ».
class AccountDetailRow extends StatelessWidget {
  const AccountDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6E6E73)),
          const SizedBox(width: 8),
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6E6E73)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? const Color(0xFF1D1D1F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Формат времени для карточек профиля: `дд.мм.гггг чч:мм`.
String formatAccountTimestamp(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
