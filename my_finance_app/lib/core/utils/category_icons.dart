import 'package:flutter/material.dart';

/// Maps Firestore-stored iconCodePoints to const [IconData] from [Icons].
/// Using a lookup instead of constructing [IconData] at runtime so that
/// Flutter's icon tree-shaking works in release builds.
const Map<int, IconData> kCategoryIconMap = {
  // ── Work & Business ──────────────────────────────────────────────────────
  0xe8f8: Icons.work,
  0xe30a: Icons.computer,
  0xe0af: Icons.business,
  0xe8e5: Icons.trending_up,
  0xe26b: Icons.bar_chart,
  0xeadc: Icons.task_alt,
  0xe7f6: Icons.engineering,
  0xeb4e: Icons.workspace_premium,
  // ── Finance ──────────────────────────────────────────────────────────────
  0xe4c9: Icons.account_balance_wallet,
  0xe84f: Icons.account_balance,
  0xe227: Icons.attach_money,
  0xe870: Icons.credit_card,
  0xef63: Icons.savings,
  0xef68: Icons.account_balance_outlined,
  0xea9e: Icons.percent,
  0xe04b: Icons.currency_exchange,
  // ── Food & Drink ─────────────────────────────────────────────────────────
  0xeb6e: Icons.restaurant,
  0xe541: Icons.local_cafe,
  0xe547: Icons.local_grocery_store,
  0xeef2: Icons.lunch_dining,
  0xef6e: Icons.ramen_dining,
  0xeb5e: Icons.icecream,
  0xea62: Icons.local_pizza,
  // ── Home & Living ────────────────────────────────────────────────────────
  0xe88a: Icons.home,
  0xe325: Icons.phone,
  0xe8d1: Icons.wifi,
  0xe1cb: Icons.electric_bolt,
  0xeb55: Icons.plumbing,
  0xe7d0: Icons.thermostat,
  0xea9d: Icons.water_drop,
  0xe14e: Icons.lightbulb,
  // ── Transport ────────────────────────────────────────────────────────────
  0xe52f: Icons.directions_car,
  0xe539: Icons.flight,
  0xe546: Icons.local_gas_station,
  0xeab3: Icons.two_wheeler,
  0xe6b1: Icons.train,
  0xea6f: Icons.directions_bus,
  0xeae4: Icons.anchor,
  // ── Health ───────────────────────────────────────────────────────────────
  0xe548: Icons.local_hospital,
  0xeb43: Icons.fitness_center,
  0xe190: Icons.favorite,
  0xeae0: Icons.health_and_safety,
  0xf04a: Icons.medical_services,
  0xeb22: Icons.sports_gymnastics,
  // ── Education & Culture ──────────────────────────────────────────────────
  0xe80c: Icons.school,
  0xf100: Icons.library_books,
  0xea2d: Icons.psychology,
  0xe879: Icons.language,
  0xea50: Icons.palette,
  // ── Entertainment ────────────────────────────────────────────────────────
  0xe021: Icons.games,
  0xe02c: Icons.movie,
  0xe405: Icons.music_note,
  0xea35: Icons.sports_soccer,
  0xeaa4: Icons.theaters,
  0xeb5c: Icons.sports_baseball,
  0xea48: Icons.sports_basketball,
  // ── Shopping & Others ────────────────────────────────────────────────────
  0xf19e: Icons.checkroom,
  0xe8cc: Icons.shopping_cart,
  0xe91d: Icons.pets,
  0xe574: Icons.category,
  0xe92d: Icons.shopping_bag,
  0xe8cb: Icons.shopping_basket,
  0xeb4c: Icons.diamond,
  0xeae8: Icons.watch,
  // ── Additional Categories ────────────────────────────────────────────────
  0xeb27: Icons.travel_explore,
  0xe30f: Icons.card_giftcard,
  0xe05d: Icons.volunteer_activism,
  0xea51: Icons.event,
  0xeb6c: Icons.cake,
};

/// Returns the [IconData] for [codePoint], falling back to [Icons.category].
IconData categoryIcon(int codePoint) =>
    kCategoryIconMap[codePoint] ?? Icons.category;
