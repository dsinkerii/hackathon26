import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Preferable content width on wide screens; shrinks to the available
/// viewport width on phones so dialogs and cards never overflow.
double adaptiveWidth(BuildContext context, double preferred) {
  final double available = MediaQuery.sizeOf(context).width - 32;
  return available <= 0 ? 0 : math.min(preferred, available);
}
