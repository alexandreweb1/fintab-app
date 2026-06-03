import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controls the active tab index in the main scaffold.
/// Index 4 (web only) = Settings.
final mainTabIndexProvider = StateProvider<int>((ref) => 0);
