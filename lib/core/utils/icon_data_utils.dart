import 'package:flutter/material.dart';

/// Returns a constant [IconData] from the known goal icon set by [codePoint].
/// Falls back to [Icons.savings_rounded] if not found.
IconData goalIconFromCodePoint(int codePoint) {
  const known = <IconData>[
    Icons.savings_rounded,
    Icons.home_rounded,
    Icons.directions_car_rounded,
    Icons.flight_rounded,
    Icons.school_rounded,
    Icons.devices_rounded,
    Icons.favorite_rounded,
    Icons.beach_access_rounded,
    Icons.business_center_rounded,
    Icons.child_care_rounded,
    Icons.fitness_center_rounded,
    Icons.celebration_rounded,
  ];
  for (final icon in known) {
    if (icon.codePoint == codePoint) return icon;
  }
  return Icons.savings_rounded;
}
