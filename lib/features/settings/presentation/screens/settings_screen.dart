import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/referral_service.dart';
import '../../../../core/utils/platform_store.dart';
import '../../../../core/utils/animated_dialog.dart';
import '../../../../core/providers/app_settings_provider.dart';
import '../../../../core/widgets/help_hint.dart';
import '../../../../core/services/notification_listener_service.dart';
import '../../../../core/services/notification_providers.dart';
import '../../../../core/providers/effective_user_provider.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../app_lock/presentation/providers/app_lock_provider.dart';
import '../../../app_lock/presentation/screens/setup_pin_screen.dart';
import '../../../data_io/presentation/screens/export_screen.dart';
import '../../../data_io/presentation/screens/import_screen.dart';
import '../../../financial_health/presentation/providers/financial_health_provider.dart';
import '../../../financial_health/presentation/screens/financial_health_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../../category_rules/presentation/screens/category_rules_screen.dart';
import '../../../bills/presentation/screens/bills_screen.dart';
import '../../../subscriptions/presentation/screens/subscriptions_screen.dart';
import '../../../wallets/presentation/screens/credit_card_screen.dart';
import '../../../../core/utils/money_input_formatter.dart';
import 'currency_converter_screen.dart';
import '../../../sharing/presentation/providers/sharing_provider.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../../subscription/presentation/screens/pro_screen.dart';
import '../../../subscription/presentation/widgets/pro_badge_widget.dart';
import '../../../subscription/presentation/widgets/pro_gate_widget.dart';
import '../../../notification_backlog/presentation/providers/backlog_provider.dart';
import '../../../../core/services/bank_filter_provider.dart';
import '../../../notification_backlog/presentation/screens/backlog_screen.dart';
import 'bank_filter_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_use_screen.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../../../wallets/presentation/providers/wallets_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared palette & helpers
// ─────────────────────────────────────────────────────────────────────────────

const _kColorPalette = [
  0xFF1976D2, // blue
  0xFF303F9F, // indigo
  0xFF00796B, // teal
  0xFF388E3C, // green
  0xFF558B2F, // light green
  0xFFE64A19, // deep orange
  0xFFC62828, // red
  0xFFAD1457, // pink
  0xFF6A1B9A, // purple
  0xFF5D4037, // brown
  0xFF0288D1, // light blue
  0xFF616161, // grey
];

class _ColorDots extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;

  const _ColorDots({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _kColorPalette.map((c) {
        final isSelected = c == selected;
        return GestureDetector(
          onTap: () => onSelected(c),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color(c),
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.onSurface,
                      width: 2.5)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: Color(c).withValues(alpha: 0.5), blurRadius: 6)
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _IconPickerGrid extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;

  const _IconPickerGrid({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final entries = kCategoryIconMap.entries.toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final codePoint = entries[i].key;
        final iconData = entries[i].value;
        final isSelected = codePoint == selected;
        return GestureDetector(
          onTap: () => onSelected(codePoint),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary, width: 2)
                  : null,
            ),
            child: Icon(iconData,
                size: 22,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout helpers
// ─────────────────────────────────────────────────────────────────────────────

const _kBlue = Color(0xFF1E88E5);
const _kDarkBlue = Color(0xFF0D47A1);

class _AppVersionLabel extends StatelessWidget {
  const _AppVersionLabel();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final info = snapshot.data!;
        return Center(
          child: Text(
            'v${info.version}+${info.buildNumber}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _MobileSectionLabel extends StatelessWidget {
  final String label;
  const _MobileSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBadge(this.icon, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile info card (top of settings content)
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileInfoCard extends StatelessWidget {
  final String? photoUrl;
  final String initials;
  final String displayName;
  final String email;
  final AppLocalizations l10n;
  final VoidCallback onEdit;

  const _ProfileInfoCard({
    required this.photoUrl,
    required this.initials,
    required this.displayName,
    required this.email,
    required this.l10n,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _SettingsCard(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            UserAvatar(
              photoUrl: photoUrl,
              initials: initials,
              radius: 28,
              backgroundColor: cs.primaryContainer,
              textStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName.isNotEmpty ? displayName : l10n.noName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style:
                          TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit_outlined, color: cs.primary, size: 20),
              tooltip: l10n.editProfile,
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SettingsScreen
// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _scrollController = ScrollController();

  // Section anchor keys (web only)
  final _keyAccount = GlobalKey();
  final _keyPreferences = GlobalKey();
  final _keyData = GlobalKey();
  final _keySharing = GlobalKey();
  final _keyNotifications = GlobalKey();
  final _keyLogout = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authStateProvider).value;
    final settings = ref.watch(appSettingsProvider);
    final incomeCategories = ref.watch(incomeCategoriesProvider);
    final expenseCategories = ref.watch(expenseCategoriesProvider);
    final hasPasswordProvider = ref.watch(hasPasswordProviderProvider);

    final displayName = user?.displayName ?? '';
    final email = user?.email ?? '';
    final initials = _initials(user?.displayName ?? user?.email ?? '?');

    final sliverAppBar = SliverAppBar(
      pinned: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: Text(
        l10n.settings,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );

    final settingsContent = [
      // ── Perfil ─────────────────────────────────────────────────────────
      _ProfileInfoCard(
        photoUrl: user?.photoUrl,
        initials: initials,
        displayName: displayName,
        email: email,
        l10n: l10n,
        onEdit: () => showAnimatedDialog(
          context: context,
          builder: (_) => _EditProfileDialog(currentName: displayName),
        ),
      ),
      const SizedBox(height: 16),

      // ── Banner Pro ─────────────────────────────────────────────────────
      const _ProBannerCard(),
      const SizedBox(height: 24),

      // ── CONTA ──────────────────────────────────────────────────────────
      const _MobileSectionLabel('Conta'),
      const SizedBox(height: 8),
      KeyedSubtree(
        key: _keyAccount,
        child: _SettingsCard(children: [
          if (hasPasswordProvider)
            ListTile(
              leading: const _IconBadge(Icons.lock_outline,
                  color: Color(0xFF5C6BC0)),
              title: Text(l10n.changePassword),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => _showChangePasswordDialog(context),
            )
          else
            ListTile(
              leading: const _IconBadge(Icons.password_outlined,
                  color: Color(0xFF7B68EE)),
              title: Text(l10n.setPassword),
              subtitle: Text(l10n.setPasswordSubtitle,
                  style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => _showSetPasswordDialog(context),
            ),
        ]),
      ),
      const SizedBox(height: 20),

      // ── SEGURANÇA ──────────────────────────────────────────────────────
      _MobileSectionLabel(l10n.security),
      const SizedBox(height: 8),
      const _AppLockCard(),
      const SizedBox(height: 20),

      // ── PREFERÊNCIAS ──────────────────────────────────────────────────
      const _MobileSectionLabel('Preferências'),
      const SizedBox(height: 8),
      KeyedSubtree(
        key: _keyPreferences,
        child: _SettingsCard(children: [
          ListTile(
            leading: const _IconBadge(Icons.currency_exchange_outlined,
                color: Color(0xFF26A69A)),
            title: Text(l10n.currency),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(settings.currency.label,
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            onTap: () => _showCurrencyDialog(context, l10n),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const _IconBadge(Icons.language_outlined,
                color: Color(0xFF42A5F5)),
            title: Text(l10n.language),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(settings.language.nativeLabel,
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            onTap: () => _showLanguageDialog(context, l10n),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const _IconBadge(Icons.brightness_6_outlined,
                color: Color(0xFFFFA726)),
            title: Text(l10n.appearance),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_themeModeLabel(settings.themeMode, l10n),
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            onTap: () => _showAppearanceDialog(context, l10n),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const _IconBadge(Icons.school_outlined,
                color: Color(0xFF8E24AA)),
            title: Text(l10n.literacyLevelSettingsTitle),
            subtitle: Text(l10n.literacyLevelSettingsSubtitle,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_literacyLevelLabel(settings.literacyLevel, l10n),
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            onTap: () => _showLiteracyLevelDialog(context, l10n),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const _IconBadge(Icons.sort_rounded,
                color: Color(0xFF26C6DA)),
            title: Text(l10n.categorySortSettingsTitle),
            subtitle: Text(l10n.categorySortSettingsSubtitle,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_categorySortLabel(settings.categorySortMode, l10n),
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            onTap: () => _showCategorySortDialog(context, l10n),
          ),
        ]),
      ),
      const SizedBox(height: 20),

      // ── DADOS ──────────────────────────────────────────────────────────
      _MobileSectionLabel(l10n.dataSection),
      const SizedBox(height: 8),
      KeyedSubtree(
        key: _keyData,
        child: _SettingsCard(children: [
          const _WalletSection(),
          const Divider(height: 1, indent: 16),
          _CategorySection(
            title: l10n.expenseCategories,
            type: CategoryType.expense,
            categories: expenseCategories,
          ),
          const Divider(height: 1, indent: 16),
          _CategorySection(
            title: l10n.incomeCategories,
            type: CategoryType.income,
            categories: incomeCategories,
          ),
        ]),
      ),
      const SizedBox(height: 12),
      const _DataIoCard(),
      const SizedBox(height: 12),
      const _FinancialHealthCard(),
      const SizedBox(height: 20),

      // ── COMPARTILHAMENTO ───────────────────────────────────────────────
      const _MobileSectionLabel('Compartilhamento'),
      const SizedBox(height: 8),
      KeyedSubtree(
        key: _keySharing,
        child: const _SharingSection(),
      ),
      const SizedBox(height: 20),

      // ── NOTIFICAÇÕES ───────────────────────────────────────────────────
      const _MobileSectionLabel('Notificações'),
      const SizedBox(height: 8),
      KeyedSubtree(
        key: _keyNotifications,
        child: const _NotificationDetectionSection(),
      ),
      const SizedBox(height: 12),
      _SettingsCard(children: [
        ListTile(
          leading: const _IconBadge(Icons.rule_folder_outlined,
              color: Color(0xFF00B894)),
          title: const Text('Regras de categorização'),
          subtitle: const Text(
            'Categorize automaticamente por palavra-chave',
            style: TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CategoryRulesScreen()),
          ),
        ),
        const Divider(height: 1, indent: 56),
        ListTile(
          leading: const _IconBadge(Icons.event_note_outlined,
              color: Color(0xFF00B894)),
          title: Text(l10n.bills),
          subtitle: Text(
            l10n.billsDesc,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BillsScreen()),
          ),
        ),
        const Divider(height: 1, indent: 56),
        ListTile(
          leading: const _IconBadge(Icons.autorenew_rounded,
              color: Color(0xFF6C5CE7)),
          title: Text(l10n.subscriptions),
          subtitle: Text(
            l10n.subscriptionsDesc,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SubscriptionsScreen()),
          ),
        ),
        const Divider(height: 1, indent: 56),
        ListTile(
          leading: const _IconBadge(Icons.currency_exchange_rounded,
              color: Color(0xFF0EA5A5)),
          title: Row(
            children: [
              Flexible(child: Text(l10n.currencyConverter)),
              if (!ref.watch(isProProvider)) ...[
                const SizedBox(width: 6),
                const ProBadgeWidget(),
              ],
            ],
          ),
          subtitle: Text(
            l10n.currencyConverterDesc,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () {
            if (!ref.read(isProProvider)) {
              showProGateBottomSheet(
                context,
                featureName: l10n.currencyConverter,
                featureDescription: l10n.currencyConverterDesc,
                featureIcon: Icons.currency_exchange_rounded,
              );
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const CurrencyConverterScreen()),
            );
          },
        ),
      ]),
      const SizedBox(height: 20),

      // ── SOBRE ──────────────────────────────────────────────────────────
      const _MobileSectionLabel('Sobre'),
      const SizedBox(height: 8),
      _SettingsCard(children: [
        ListTile(
          leading: const _IconBadge(Icons.privacy_tip_outlined,
              color: Color(0xFF5C6BC0)),
          title: const Text('Política de Privacidade'),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
          ),
        ),
        const Divider(height: 1, indent: 56),
        ListTile(
          leading: const _IconBadge(Icons.description_outlined,
              color: Color(0xFF5C6BC0)),
          title: const Text('Termos de Uso'),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TermsOfUseScreen()),
          ),
        ),
      ]),
      const SizedBox(height: 20),

      // ── SAIR ───────────────────────────────────────────────────────────
      const _MobileSectionLabel('Sair'),
      const SizedBox(height: 8),
      KeyedSubtree(
        key: _keyLogout,
        child: _SettingsCard(children: [
          ListTile(
            leading: _IconBadge(Icons.logout, color: Colors.red.shade400),
            title:
                Text(l10n.logout, style: TextStyle(color: Colors.red.shade600)),
            onTap: () => ref.read(authNotifierProvider.notifier).signOut(),
          ),
          const Divider(height: 1),
          ListTile(
            leading: _IconBadge(Icons.delete_forever_outlined,
                color: Colors.red.shade900),
            title: Text('Excluir conta',
                style: TextStyle(color: Colors.red.shade900)),
            onTap: () => showAnimatedDialog(
              context: context,
              builder: (_) => const _DeleteAccountDialog(),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 16),

      // App version
      const _AppVersionLabel(),
    ];

    if (kIsWeb) {
      return Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Fixed left sidebar ──────────────────────────────────
            SizedBox(
              width: 260,
              child: _WebFullSidebar(
                photoUrl: user?.photoUrl,
                displayName: displayName,
                email: email,
                initials: initials,
                l10n: l10n,
                onAccount: () => _scrollTo(_keyAccount),
                onPreferences: () => _scrollTo(_keyPreferences),
                onData: () => _scrollTo(_keyData),
                onSharing: () => _scrollTo(_keySharing),
                onNotifications: () => _scrollTo(_keyNotifications),
                onLogout: () =>
                    ref.read(authNotifierProvider.notifier).signOut(),
                onEditProfile: () => showAnimatedDialog(
                  context: context,
                  builder: (_) => _EditProfileDialog(currentName: displayName),
                ),
                onBack: () => ref.read(mainTabIndexProvider.notifier).state = 0,
              ),
            ),
            // ── Scrollable main content ─────────────────────────────
            Expanded(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 48),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: settingsContent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          sliverAppBar,
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
            sliver: SliverList.list(children: settingsContent),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  void _showChangePasswordDialog(BuildContext context) {
    showAnimatedDialog(
        context: context, builder: (_) => const _ChangePasswordDialog());
  }

  void _showSetPasswordDialog(BuildContext context) {
    showAnimatedDialog(
        context: context, builder: (_) => const _SetPasswordDialog());
  }

  void _showCurrencyDialog(BuildContext context, AppLocalizations l10n) {
    showAnimatedDialog(
        context: context, builder: (ctx) => _CurrencyDialog(l10n: l10n));
  }

  void _showLanguageDialog(BuildContext context, AppLocalizations l10n) {
    showAnimatedDialog(
        context: context, builder: (ctx) => _LanguageDialog(l10n: l10n));
  }

  void _showAppearanceDialog(BuildContext context, AppLocalizations l10n) {
    showAnimatedDialog(
        context: context, builder: (ctx) => _AppearanceDialog(l10n: l10n));
  }

  void _showLiteracyLevelDialog(BuildContext context, AppLocalizations l10n) {
    showAnimatedDialog(
        context: context, builder: (ctx) => _LiteracyLevelDialog(l10n: l10n));
  }

  void _showCategorySortDialog(BuildContext context, AppLocalizations l10n) {
    showAnimatedDialog(
        context: context, builder: (ctx) => _CategorySortDialog(l10n: l10n));
  }

  String _categorySortLabel(CategorySortMode mode, AppLocalizations l10n) {
    switch (mode) {
      case CategorySortMode.mostUsed:
        return l10n.categorySortMostUsed;
      case CategorySortMode.alphabetical:
        return l10n.categorySortAlphabetical;
    }
  }

  String _themeModeLabel(AppThemeMode mode, AppLocalizations l10n) {
    switch (mode) {
      case AppThemeMode.system:
        return l10n.themeModeSystem;
      case AppThemeMode.light:
        return l10n.themeModeLight;
      case AppThemeMode.dark:
        return l10n.themeModeDark;
    }
  }

  String _literacyLevelLabel(
      FinancialLiteracyLevel level, AppLocalizations l10n) {
    switch (level) {
      case FinancialLiteracyLevel.beginner:
        return l10n.literacyLevelBeginner;
      case FinancialLiteracyLevel.intermediate:
        return l10n.literacyLevelIntermediate;
      case FinancialLiteracyLevel.advanced:
        return l10n.literacyLevelAdvanced;
      case FinancialLiteracyLevel.unset:
        return '—';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Currency Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _CurrencyDialog extends ConsumerWidget {
  final AppLocalizations l10n;
  const _CurrencyDialog({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appSettingsProvider).currency;
    return AlertDialog(
      title: Text(l10n.currencyTitle),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: SizedBox(
        width: 320,
        height: 360,
        child: RadioGroup<AppCurrency>(
          groupValue: current,
          onChanged: (v) {
            if (v != null) {
              ref.read(appSettingsProvider.notifier).setCurrency(v);
              Navigator.of(context).pop();
            }
          },
          child: ListView(
            children: AppCurrency.values
                .map((currency) => RadioListTile<AppCurrency>(
                      value: currency,
                      title: Text(currency.label),
                      subtitle: Text(currency.symbol,
                          style: TextStyle(color: Colors.grey.shade600)),
                    ))
                .toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Language Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _LanguageDialog extends ConsumerWidget {
  final AppLocalizations l10n;
  const _LanguageDialog({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appSettingsProvider).language;
    return AlertDialog(
      title: Text(l10n.languageTitle),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: SizedBox(
        width: 320,
        child: RadioGroup<AppLanguage>(
          groupValue: current,
          onChanged: (v) {
            if (v != null) {
              ref.read(appSettingsProvider.notifier).setLanguage(v);
              Navigator.of(context).pop();
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppLanguage.values
                .map((lang) => RadioListTile<AppLanguage>(
                      value: lang,
                      title: Text(lang.nativeLabel),
                      subtitle: Text(lang.label,
                          style: TextStyle(color: Colors.grey.shade600)),
                    ))
                .toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Profile Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _EditProfileDialog extends ConsumerStatefulWidget {
  final String currentName;
  const _EditProfileDialog({required this.currentName});

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final success = await ref
        .read(authNotifierProvider.notifier)
        .updateProfile(displayName: name);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      final err = ref.read(authNotifierProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err ?? 'Erro ao atualizar perfil.'),
          backgroundColor: Colors.red.shade700));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    return AlertDialog(
      title: Text(l10n.editProfile),
      content: TextField(
        controller: _nameController,
        decoration: InputDecoration(
            labelText: l10n.nameField, border: const OutlineInputBorder()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel)),
        FilledButton(
          onPressed: isLoading ? null : _submit,
          child: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Change Password Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPwController = TextEditingController();
  final _newPwController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  @override
  void dispose() {
    _currentPwController.dispose();
    _newPwController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref
        .read(authNotifierProvider.notifier)
        .updatePassword(_currentPwController.text, _newPwController.text);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).passwordChanged)));
    } else {
      final err = ref.read(authNotifierProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err ?? 'Erro ao alterar senha.'),
          backgroundColor: Colors.red.shade700));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    return AlertDialog(
      title: Text(l10n.changePassword),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _currentPwController,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: l10n.currentPassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? l10n.enterCurrentPassword : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPwController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: l10n.newPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscureNew ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return l10n.enterNewPassword;
                  if (v.length < 6) return l10n.minChars;
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel)),
        FilledButton(
          onPressed: isLoading ? null : _submit,
          child: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delete Account Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final hasPassword = ref.read(hasPasswordProviderProvider);
    final password = hasPassword ? _passwordController.text.trim() : null;

    if (hasPassword && (password == null || password.isEmpty)) return;

    final success = await ref
        .read(authNotifierProvider.notifier)
        .deleteAccount(password: password);

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      final err = ref.read(authNotifierProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err ?? 'Erro ao excluir conta.'),
          backgroundColor: Colors.red.shade700));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    final hasPassword = ref.watch(hasPasswordProviderProvider);

    return AlertDialog(
      title: const Text('Excluir conta'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta ação é permanente e não pode ser desfeita. '
              'Todos os seus dados serão excluídos.',
            ),
            if (hasPassword) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Confirme sua senha',
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Text(
                'Você será redirecionado para confirmar com o Google.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: isLoading ? null : _confirm,
          child: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Excluir conta'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Set Password Dialog (for Google-only users who want to add email/password)
// ─────────────────────────────────────────────────────────────────────────────

class _SetPasswordDialog extends ConsumerStatefulWidget {
  const _SetPasswordDialog();

  @override
  ConsumerState<_SetPasswordDialog> createState() => _SetPasswordDialogState();
}

class _SetPasswordDialogState extends ConsumerState<_SetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pwController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _pwController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref
        .read(authNotifierProvider.notifier)
        .linkEmailPassword(_pwController.text);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordSet)),
      );
    } else {
      final err = ref.read(authNotifierProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Erro ao definir senha.'),
        backgroundColor: Colors.red.shade700,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    return AlertDialog(
      title: Text(l10n.setPassword),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _pwController,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.newPassword,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.enterNewPassword;
              if (v.length < 6) return l10n.minChars;
              return null;
            },
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel)),
        FilledButton(
          onPressed: isLoading ? null : _submit,
          child: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category Section
// ─────────────────────────────────────────────────────────────────────────────

class _CategorySection extends ConsumerWidget {
  final String title;
  final CategoryType type;
  final List<CategoryEntity> categories;

  const _CategorySection({
    required this.title,
    required this.type,
    required this.categories,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isPro = ref.watch(isProProvider);
    return ExpansionTile(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          HelpHint(
            title: l10n.hintCategoryTitle,
            body: l10n.hintCategoryBody,
          ),
        ],
      ),
      children: [
        ...categories.map(
          (cat) => ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(cat.colorValue).withValues(alpha: 0.15),
              child: Icon(categoryIcon(cat.iconCodePoint),
                  color: Color(cat.colorValue), size: 20),
            ),
            title: Text(cat.name),
            trailing: (cat.isDefault && !isPro)
                ? GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProScreen()),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.lock_outline,
                          size: 16, color: Colors.grey),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit_outlined,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20),
                        onPressed: () => showAnimatedDialog(
                          context: context,
                          builder: (_) => _EditCategoryDialog(category: cat),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: Colors.red.shade400, size: 20),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Excluir categoria'),
                              content: Text(
                                  'Deseja excluir a categoria "${cat.name}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                      backgroundColor:
                                          Theme.of(ctx).colorScheme.error),
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Excluir'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            ref
                                .read(categoriesNotifierProvider.notifier)
                                .delete(cat.id);
                          }
                        },
                      ),
                    ],
                  ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.add),
          title: Text(type == CategoryType.expense
              ? l10n.addExpenseCategory
              : l10n.addIncomeCategory),
          onTap: () => showAnimatedDialog(
            context: context,
            builder: (_) => _AddCategoryDialog(type: type),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Category Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _AddCategoryDialog extends ConsumerStatefulWidget {
  final CategoryType type;
  const _AddCategoryDialog({required this.type});

  @override
  ConsumerState<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends ConsumerState<_AddCategoryDialog> {
  final _nameController = TextEditingController();
  int _iconCodePoint = 0xe574; // Icons.category
  int _colorValue = 0xFF616161;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final effectiveUserId = ref.read(effectiveUserIdProvider);
    if (effectiveUserId.isEmpty) return;
    final success = await ref.read(categoriesNotifierProvider.notifier).add(
          userId: effectiveUserId,
          name: name,
          type: widget.type,
          iconCodePoint: _iconCodePoint,
          colorValue: _colorValue,
        );
    if (!mounted) return;
    if (success) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLoading = ref.watch(categoriesNotifierProvider).isLoading;
    final typeLabel =
        widget.type == CategoryType.expense ? l10n.expense : l10n.incomeType;
    return AlertDialog(
      title: Text('${l10n.newCategoryTitle} – $typeLabel'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.categoryName,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.selectIcon,
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              _IconPickerGrid(
                  selected: _iconCodePoint,
                  onSelected: (v) => setState(() => _iconCodePoint = v)),
              const SizedBox(height: 16),
              Text(l10n.selectColor,
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              _ColorDots(
                  selected: _colorValue,
                  onSelected: (v) => setState(() => _colorValue = v)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel)),
        FilledButton(
          onPressed: isLoading ? null : _submit,
          child: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Category Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _EditCategoryDialog extends ConsumerStatefulWidget {
  final CategoryEntity category;
  const _EditCategoryDialog({required this.category});

  @override
  ConsumerState<_EditCategoryDialog> createState() =>
      _EditCategoryDialogState();
}

class _EditCategoryDialogState extends ConsumerState<_EditCategoryDialog> {
  late final TextEditingController _nameController;
  late int _iconCodePoint;
  late int _colorValue;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category.name);
    _iconCodePoint = widget.category.iconCodePoint;
    _colorValue = widget.category.colorValue;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final updated = CategoryEntity(
      id: widget.category.id,
      userId: widget.category.userId,
      name: name,
      type: widget.category.type,
      iconCodePoint: _iconCodePoint,
      colorValue: _colorValue,
      isDefault: widget.category.isDefault,
    );
    final success =
        await ref.read(categoriesNotifierProvider.notifier).update(updated);
    if (!mounted) return;
    if (success) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLoading = ref.watch(categoriesNotifierProvider).isLoading;
    return AlertDialog(
      title: Text(l10n.editCategory),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.categoryName,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.selectIcon,
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              _IconPickerGrid(
                  selected: _iconCodePoint,
                  onSelected: (v) => setState(() => _iconCodePoint = v)),
              const SizedBox(height: 16),
              Text(l10n.selectColor,
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              _ColorDots(
                  selected: _colorValue,
                  onSelected: (v) => setState(() => _colorValue = v)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel)),
        FilledButton(
          onPressed: isLoading ? null : _submit,
          child: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sharing Section
// ─────────────────────────────────────────────────────────────────────────────

class _SharingSection extends ConsumerStatefulWidget {
  const _SharingSection();

  @override
  ConsumerState<_SharingSection> createState() => _SharingSectionState();
}

class _SharingSectionState extends ConsumerState<_SharingSection> {
  final _emailCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() => _sending = true);
    final error =
        await ref.read(sharingNotifierProvider.notifier).sendInvitation(email);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error == null) {
      _emailCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Convite enviado com sucesso!'),
          action: SnackBarAction(
            label: 'Compartilhar',
            onPressed: () => Share.share(
              'Te convidei pra organizar nossas finanças juntos no Fintab! '
              'Baixe o app, cadastre-se com este e-mail ($email) e aceite o '
              'convite: $storeUrl',
            ),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  /// Word-of-mouth referral: shares the app via the native share sheet
  /// (WhatsApp, SMS, etc.) with a ready message + the store link. Available to
  /// everyone (not Pro-gated) since it's how the app grows.
  Future<void> _shareReferral() async {
    final uid = ref.read(authStateProvider).value?.id;
    var codeLine = '';
    if (uid != null) {
      final code = await ReferralService.instance.ensureReferralCode(uid);
      codeLine = '\n\nUse meu código de indicação no app (Configurações → '
          'Compartilhamento → "Tenho um código"): $code';
    }
    await Share.share(
      'Tô usando o Fintab pra organizar minhas finanças e queria te convidar '
      'a usar também. Baixe aqui: $storeUrl$codeLine',
      subject: 'Conheça o Fintab',
    );
    AnalyticsService.instance.logEvent('invite_shared', {'origin': 'referral'});
  }

  Future<void> _redeemReferral() async {
    final controller = TextEditingController();
    final code = await showAnimatedDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tenho um código de indicação'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Código de indicação',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(ctx).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Resgatar'),
          ),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty) return;
    final uid = ref.read(authStateProvider).value?.id;
    if (uid == null) return;
    final error = await ReferralService.instance.redeemCode(uid, code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ??
            'Código aplicado! Ao usar o app, quem te indicou ganha 1 mês de '
                'Pro grátis.'),
        backgroundColor: error != null ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> _confirmLeave() async {
    final confirmed = await showAnimatedDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair da conta compartilhada'),
        content: const Text(
            'Você perderá acesso aos dados desta conta. Deseja continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppLocalizations.of(context).cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error =
        await ref.read(sharingNotifierProvider.notifier).leaveSharedAccount();
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMaster = ref.watch(isMasterProvider);
    final pendingAsync = ref.watch(pendingInvitationsProvider);
    final collaboratorsAsync = ref.watch(myCollaboratorsProvider);
    final pendingInvites = pendingAsync.value ?? [];
    final collaborators = collaboratorsAsync.value ?? [];
    final profileAsync = ref.watch(userProfileStreamProvider);
    final profile = profileAsync.value;

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Convidar amigos (indicação — disponível para todos) ──────────
        OutlinedButton.icon(
          onPressed: _shareReferral,
          icon: const Icon(Icons.ios_share, size: 18),
          label: const Text('Convidar amigos para o Fintab'),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 10),
          child: Text(
            'Quando alguém usa seu código e começa a usar o app, '
            'você ganha 1 mês de Pro grátis.',
            style: TextStyle(
              fontSize: 11.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextButton.icon(
            onPressed: _redeemReferral,
            icon: const Icon(Icons.redeem_outlined, size: 18),
            label: const Text('Tenho um código de indicação'),
          ),
        ),
        // ── Pending received invitations (amber banner) ──────────────────
        if (pendingInvites.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.amber.shade600.withValues(alpha: 0.6),
                  width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Row(
                    children: [
                      Icon(Icons.mail_outline,
                          color: Colors.amber.shade700, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Convites recebidos',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                ...pendingInvites.map((inv) => ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          (inv.masterName.isNotEmpty
                                  ? inv.masterName[0]
                                  : inv.masterEmail[0])
                              .toUpperCase(),
                          style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(inv.masterName.isNotEmpty
                          ? inv.masterName
                          : inv.masterEmail),
                      subtitle: Text(inv.masterEmail,
                          style: const TextStyle(fontSize: 11)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.red.shade600),
                            onPressed: () => ref
                                .read(sharingNotifierProvider.notifier)
                                .declineInvitation(inv.id),
                            child: Text(AppLocalizations.of(context).decline),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact),
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final error = await ref
                                  .read(sharingNotifierProvider.notifier)
                                  .acceptInvitation(inv);
                              if (error != null) {
                                messenger.showSnackBar(
                                    SnackBar(content: Text(error)));
                              }
                            },
                            child: Text(AppLocalizations.of(context).accept),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Collaborator view: "you are on someone else's account" ───────
        if (!isMaster) ...[
          _SettingsCard(children: [
            ListTile(
              leading: const _IconBadge(Icons.people_alt_outlined,
                  color: Color(0xFF7E57C2)),
              title: const Text('Conta compartilhada'),
              subtitle: Text(
                profile?['masterUserId'] != null
                    ? 'Você está usando uma conta compartilhada'
                    : 'Conta compartilhada',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade700,
                ),
                onPressed: _confirmLeave,
                child: const Text('Sair da conta compartilhada'),
              ),
            ),
          ]),
        ],

        // ── Master view: invite + collaborator list ───────────────────────
        if (isMaster) ...[
          _SettingsCard(children: [
            ExpansionTile(
              leading: const _IconBadge(Icons.people_outline,
                  color: Color(0xFF7E57C2)),
              title: Row(
                children: [
                  const Text('Compartilhamento',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  if (!ref.watch(isProProvider)) const ProBadgeWidget(),
                ],
              ),
              children: [
                // Invite field (bloqueado para usuários free)
                if (!ref.watch(isProProvider))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => showProGateBottomSheet(
                          context,
                          featureName: 'Compartilhamento',
                          featureDescription:
                              'Convide colaboradores para gerenciar suas finanças juntos.',
                          featureIcon: Icons.people_rounded,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF00D887),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.lock_outline, size: 18),
                        label: const Text('Disponível no plano Pro',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email do colaborador',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _sendInvite(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _sending ? null : _sendInvite,
                          child: _sending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Convidar'),
                        ),
                      ],
                    ),
                  ),

                // Active collaborators
                if (collaborators.isNotEmpty) ...[
                  const Divider(height: 1, indent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Text('Colaboradores ativos',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant)),
                  ),
                  ...collaborators.map((inv) => ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              const Color(0xFF7E57C2).withValues(alpha: 0.15),
                          child: Text(
                            inv.inviteeEmail[0].toUpperCase(),
                            style: const TextStyle(
                                color: Color(0xFF7E57C2),
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                        title: Text(inv.inviteeEmail,
                            style: const TextStyle(fontSize: 13)),
                        trailing: IconButton(
                          icon: Icon(Icons.person_remove_outlined,
                              color: Colors.red.shade400, size: 20),
                          tooltip: 'Remover colaborador',
                          onPressed: inv.collaboratorUserId == null
                              ? null
                              : () => ref
                                  .read(sharingNotifierProvider.notifier)
                                  .removeCollaborator(
                                    invitationId: inv.id,
                                    collaboratorUserId: inv.collaboratorUserId!,
                                  ),
                        ),
                      )),
                ],

                const SizedBox(height: 8),
              ],
            ),
          ]),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wallet Section
// ─────────────────────────────────────────────────────────────────────────────

class _WalletSection extends ConsumerWidget {
  const _WalletSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final walletsAsync = ref.watch(walletsStreamProvider);
    final hiddenWalletIds = ref.watch(appSettingsProvider).hiddenWalletIds;
    final isPro = ref.watch(isProProvider);

    final walletTiles = walletsAsync.when(
      data: (wallets) => wallets.map((w) {
        final isVisible = !hiddenWalletIds.contains(w.id);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor:
                Color(w.colorValue).withValues(alpha: isVisible ? 0.15 : 0.06),
            child: Icon(
              categoryIcon(w.iconCodePoint),
              color:
                  Color(w.colorValue).withValues(alpha: isVisible ? 1.0 : 0.35),
              size: 20,
            ),
          ),
          title: Text(
            w.name,
            style: TextStyle(
              color: isVisible
                  ? null
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
            ),
          ),
          subtitle: w.isCreditCard
              ? Text(l10n.viewInvoices,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary))
              : null,
          onTap: w.isCreditCard
              ? () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreditCardScreen(walletId: w.id),
                    ),
                  )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: isVisible,
                onChanged: (_) => ref
                    .read(appSettingsProvider.notifier)
                    .toggleWalletVisibility(w.id),
              ),
              if (w.isDefault && !isPro)
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProScreen()),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child:
                        Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                  ),
                )
              else ...[
                IconButton(
                  icon: Icon(Icons.edit_outlined,
                      color: Theme.of(context).colorScheme.primary, size: 20),
                  onPressed: () => showAnimatedDialog(
                    context: context,
                    builder: (_) => _EditWalletDialog(wallet: w),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: Colors.red.shade400, size: 20),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Excluir carteira'),
                        content: Text('Deseja excluir a carteira "${w.name}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor:
                                    Theme.of(ctx).colorScheme.error),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Excluir'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      ref.read(walletsNotifierProvider.notifier).delete(w.id);
                    }
                  },
                ),
              ],
            ],
          ),
        );
      }).toList(),
      loading: () =>
          [const ListTile(title: Center(child: CircularProgressIndicator()))],
      error: (e, _) => [ListTile(title: Text('Erro: $e'))],
    );

    return ExpansionTile(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(l10n.wallets,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          HelpHint(
            title: l10n.hintWalletTitle,
            body: l10n.hintWalletBody,
          ),
        ],
      ),
      children: [
        ...walletTiles,
        // Gate: free users só podem ter 1 carteira
        Builder(builder: (context) {
          final canAdd = ref.watch(canAddWalletProvider);
          return ListTile(
            leading: Icon(canAdd ? Icons.add : Icons.lock_outline,
                color: canAdd ? null : const Color(0xFF00D887)),
            title: Text(l10n.newWallet),
            onTap: () {
              if (!canAdd) {
                showProGateBottomSheet(
                  context,
                  featureName: 'Múltiplas Carteiras',
                  featureDescription:
                      'Crie quantas carteiras quiser para organizar seu dinheiro.',
                  featureIcon: Icons.account_balance_wallet_rounded,
                );
                return;
              }
              showAnimatedDialog(
                context: context,
                builder: (_) => const _AddWalletDialog(),
              );
            },
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Wallet Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _AddWalletDialog extends ConsumerStatefulWidget {
  const _AddWalletDialog();

  @override
  ConsumerState<_AddWalletDialog> createState() => _AddWalletDialogState();
}

class _AddWalletDialogState extends ConsumerState<_AddWalletDialog> {
  final _nameController = TextEditingController();
  final _limitController = TextEditingController();
  int _iconCodePoint = 0xe4c9; // account_balance_wallet
  int _colorValue = 0xFF1976D2;
  AppCurrency _currency = AppCurrency.brl;
  WalletType _type = WalletType.regular;
  int _closingDay = 1;
  int _dueDay = 10;
  bool _isLoading = false;

  bool get _isCard => _type == WalletType.creditCard;

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final effectiveUserId = ref.read(effectiveUserIdProvider);
    if (effectiveUserId.isEmpty) return;
    setState(() => _isLoading = true);
    final success = await ref.read(walletsNotifierProvider.notifier).add(
          userId: effectiveUserId,
          name: name,
          iconCodePoint: _isCard ? 0xe19f : _iconCodePoint,
          colorValue: _colorValue,
          currencyCode: _currency.code,
          type: _type,
          creditLimit: _isCard ? moneyTextToDouble(_limitController.text) : 0,
          closingDay: _isCard ? _closingDay : 1,
          dueDay: _isCard ? _dueDay : 10,
        );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      Navigator.of(context).pop();
    } else {
      final err = ref.read(walletsNotifierProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err?.toString() ?? 'Erro ao criar carteira'),
        backgroundColor: Colors.red.shade700,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.newWallet),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.walletName,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<WalletType>(
                segments: [
                  ButtonSegment(
                    value: WalletType.regular,
                    icon: const Icon(Icons.account_balance_wallet_outlined,
                        size: 18),
                    label: Text(l10n.wallet),
                  ),
                  ButtonSegment(
                    value: WalletType.creditCard,
                    icon: const Icon(Icons.credit_card_rounded, size: 18),
                    label: Text(l10n.creditCard),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              if (_isCard) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _limitController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [MoneyInputFormatter()],
                  decoration: InputDecoration(
                    labelText: l10n.creditLimit,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DayDropdown(
                        label: l10n.closingDay,
                        value: _closingDay,
                        onChanged: (v) => setState(() => _closingDay = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DayDropdown(
                        label: l10n.dueDay,
                        value: _dueDay,
                        onChanged: (v) => setState(() => _dueDay = v),
                      ),
                    ),
                  ],
                ),
              ],
              if (!_isCard) ...[
                const SizedBox(height: 16),
                Text(l10n.selectIcon,
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 8),
                _IconPickerGrid(
                    selected: _iconCodePoint,
                    onSelected: (v) => setState(() => _iconCodePoint = v)),
              ],
              const SizedBox(height: 16),
              Text(l10n.selectColor,
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              _ColorDots(
                  selected: _colorValue,
                  onSelected: (v) => setState(() => _colorValue = v)),
              const SizedBox(height: 16),
              Text('Moeda', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<AppCurrency>(
                initialValue: _currency,
                isExpanded: true,
                decoration: const InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(),
                ),
                items: AppCurrency.values
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text('${c.symbol}  ${c.label}',
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (c) {
                  if (c != null) setState(() => _currency = c);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Wallet Dialog
// ─────────────────────────────────────────────────────────────────────────────

/// Dropdown to pick a day-of-month (1–31) — used for credit-card closing/due.
class _DayDropdown extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _DayDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value.clamp(1, 31),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: List.generate(31, (i) => i + 1)
          .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _EditWalletDialog extends ConsumerStatefulWidget {
  final WalletEntity wallet;
  const _EditWalletDialog({required this.wallet});

  @override
  ConsumerState<_EditWalletDialog> createState() => _EditWalletDialogState();
}

class _EditWalletDialogState extends ConsumerState<_EditWalletDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _limitController;
  late int _iconCodePoint;
  late int _colorValue;
  late AppCurrency _currency;
  late int _closingDay;
  late int _dueDay;
  bool _isLoading = false;

  bool get _isCard => widget.wallet.isCreditCard;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.wallet.name);
    _limitController = TextEditingController(
        text: widget.wallet.creditLimit > 0
            ? doubleToMoneyText(widget.wallet.creditLimit)
            : '');
    _iconCodePoint = widget.wallet.iconCodePoint;
    _colorValue = widget.wallet.colorValue;
    _closingDay = widget.wallet.closingDay;
    _dueDay = widget.wallet.dueDay;
    _currency = AppCurrency.fromCode(widget.wallet.currencyCode.isEmpty
        ? 'BRL'
        : widget.wallet.currencyCode);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final updated = widget.wallet.copyWith(
      name: name,
      iconCodePoint: _iconCodePoint,
      colorValue: _colorValue,
      currencyCode: _currency.code,
      creditLimit:
          _isCard ? moneyTextToDouble(_limitController.text) : null,
      closingDay: _isCard ? _closingDay : null,
      dueDay: _isCard ? _dueDay : null,
    );
    setState(() => _isLoading = true);
    final success =
        await ref.read(walletsNotifierProvider.notifier).update(updated);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      Navigator.of(context).pop();
    } else {
      final err = ref.read(walletsNotifierProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err?.toString() ?? 'Erro ao editar carteira'),
        backgroundColor: Colors.red.shade700,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.editWallet),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.walletName,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_isCard) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _limitController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [MoneyInputFormatter()],
                  decoration: InputDecoration(
                    labelText: l10n.creditLimit,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DayDropdown(
                        label: l10n.closingDay,
                        value: _closingDay,
                        onChanged: (v) => setState(() => _closingDay = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DayDropdown(
                        label: l10n.dueDay,
                        value: _dueDay,
                        onChanged: (v) => setState(() => _dueDay = v),
                      ),
                    ),
                  ],
                ),
              ],
              if (!_isCard) ...[
                const SizedBox(height: 16),
                Text(l10n.selectIcon,
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 8),
                _IconPickerGrid(
                    selected: _iconCodePoint,
                    onSelected: (v) => setState(() => _iconCodePoint = v)),
              ],
              const SizedBox(height: 16),
              Text(l10n.selectColor,
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              _ColorDots(
                  selected: _colorValue,
                  onSelected: (v) => setState(() => _colorValue = v)),
              const SizedBox(height: 16),
              Text('Moeda', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<AppCurrency>(
                initialValue: _currency,
                isExpanded: true,
                decoration: const InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(),
                ),
                items: AppCurrency.values
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text('${c.symbol}  ${c.label}',
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (c) {
                  if (c != null) setState(() => _currency = c);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Appearance Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _AppearanceDialog extends ConsumerWidget {
  final AppLocalizations l10n;
  const _AppearanceDialog({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appSettingsProvider).themeMode;
    return AlertDialog(
      title: Text(l10n.appearance),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: SizedBox(
        width: 320,
        child: RadioGroup<AppThemeMode>(
          groupValue: current,
          onChanged: (v) {
            if (v != null) {
              ref.read(appSettingsProvider.notifier).setThemeMode(v);
              Navigator.of(context).pop();
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<AppThemeMode>(
                  value: AppThemeMode.system,
                  title: Text(l10n.themeModeSystem)),
              RadioListTile<AppThemeMode>(
                  value: AppThemeMode.light, title: Text(l10n.themeModeLight)),
              RadioListTile<AppThemeMode>(
                  value: AppThemeMode.dark, title: Text(l10n.themeModeDark)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Literacy Level Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _LiteracyLevelDialog extends ConsumerWidget {
  final AppLocalizations l10n;
  const _LiteracyLevelDialog({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appSettingsProvider).literacyLevel;
    return AlertDialog(
      title: Text(l10n.literacyLevelSettingsTitle),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: SizedBox(
        width: 360,
        child: RadioGroup<FinancialLiteracyLevel>(
          groupValue: current == FinancialLiteracyLevel.unset
              ? FinancialLiteracyLevel.beginner
              : current,
          onChanged: (v) {
            if (v != null) {
              ref.read(appSettingsProvider.notifier).setLiteracyLevel(v);
              Navigator.of(context).pop();
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<FinancialLiteracyLevel>(
                value: FinancialLiteracyLevel.beginner,
                title: Text(l10n.literacyLevelBeginner),
                subtitle: Text(l10n.literacyLevelBeginnerDesc,
                    style: const TextStyle(fontSize: 12)),
              ),
              RadioListTile<FinancialLiteracyLevel>(
                value: FinancialLiteracyLevel.intermediate,
                title: Text(l10n.literacyLevelIntermediate),
                subtitle: Text(l10n.literacyLevelIntermediateDesc,
                    style: const TextStyle(fontSize: 12)),
              ),
              RadioListTile<FinancialLiteracyLevel>(
                value: FinancialLiteracyLevel.advanced,
                title: Text(l10n.literacyLevelAdvanced),
                subtitle: Text(l10n.literacyLevelAdvancedDesc,
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category Sort Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _CategorySortDialog extends ConsumerWidget {
  final AppLocalizations l10n;
  const _CategorySortDialog({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appSettingsProvider).categorySortMode;
    return AlertDialog(
      title: Text(l10n.categorySortTitle),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: SizedBox(
        width: 360,
        child: RadioGroup<CategorySortMode>(
          groupValue: current,
          onChanged: (v) {
            if (v != null) {
              ref.read(appSettingsProvider.notifier).setCategorySortMode(v);
              Navigator.of(context).pop();
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<CategorySortMode>(
                value: CategorySortMode.mostUsed,
                title: Text(l10n.categorySortMostUsed),
                subtitle: Text(l10n.categorySortMostUsedDesc,
                    style: const TextStyle(fontSize: 12)),
              ),
              RadioListTile<CategorySortMode>(
                value: CategorySortMode.alphabetical,
                title: Text(l10n.categorySortAlphabetical),
                subtitle: Text(l10n.categorySortAlphabeticalDesc,
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pro Banner Card
// ─────────────────────────────────────────────────────────────────────────────

const _kGreen = Color(0xFF00D887);
const _kGreenDark = Color(0xFF00A86B);

class _ProBannerCard extends ConsumerWidget {
  const _ProBannerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(isProProvider);
    final subscription = ref.watch(subscriptionStreamProvider).value;

    if (isPro) {
      return GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kGreen, _kGreenDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Plano Pro Ativo',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subscription?.expiryDate != null
                          ? 'Renova em ${_formatDate(subscription!.expiryDate!)}'
                          : 'Acesso vitalício',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ver meus benefícios',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white, size: 22),
            ],
          ),
        ),
      );
    }

    // Não é Pro — card de upgrade
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kGreen, _kGreenDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Upgrade para Pro',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '✓ Múltiplas carteiras  ✓ Categorias  ✓ Visão anual  ✓ Compartilhamento',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProScreen()),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Ver Planos',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification Detection Section
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationDetectionSection extends ConsumerStatefulWidget {
  const _NotificationDetectionSection();

  @override
  ConsumerState<_NotificationDetectionSection> createState() =>
      _NotificationDetectionSectionState();
}

class _NotificationDetectionSectionState
    extends ConsumerState<_NotificationDetectionSection>
    with WidgetsBindingObserver {
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check permission when user returns from system Settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  Future<void> _checkPermission() async {
    final granted = await NotificationListenerBridge.isPermissionGranted();
    if (mounted) setState(() => _permissionGranted = granted);
  }

  @override
  Widget build(BuildContext context) {
    // A detecção lê notificações de outros apps via NotificationListenerService
    // — API exclusiva do Android. O iOS não permite ler notificações de
    // terceiros, então lá exibimos apenas o histórico (sincronizado do
    // Firestore, útil em contas compartilhadas com um Android).
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final enabled =
        isAndroid ? ref.watch(notificationDetectionEnabledProvider) : false;
    final autoSave =
        isAndroid ? ref.watch(notificationAutoSaveProvider) : false;
    final clipboardCapture = ref.watch(clipboardCaptureEnabledProvider);
    final cs = Theme.of(context).colorScheme;

    return _SettingsCard(children: [
      if (isAndroid) ...[
        // ── Toggle principal ──
        SwitchListTile(
          secondary: const _IconBadge(
            Icons.notifications_active_outlined,
            color: Color(0xFF29B6F6),
          ),
          title: Text(AppLocalizations.of(context).detectTransactions),
          subtitle: Text(
            AppLocalizations.of(context).detectTransactionsDesc,
            style: const TextStyle(fontSize: 12),
          ),
          value: enabled,
          onChanged: (v) => ref
              .read(notificationDetectionEnabledProvider.notifier)
              .setValue(v),
        ),
        if (enabled) ...[
          const Divider(height: 1, indent: 56),
          // ── Permission status ──
          ListTile(
            leading: _IconBadge(
              _permissionGranted
                  ? Icons.verified_outlined
                  : Icons.warning_amber_outlined,
              color: _permissionGranted
                  ? Colors.green.shade600
                  : Colors.orange.shade700,
            ),
            title: Text(
              _permissionGranted
                  ? 'Acesso a notificações ativo'
                  : 'Acesso a notificações necessário',
            ),
            subtitle: Text(
              _permissionGranted
                  ? 'O app está monitorando notificações'
                  : 'Toque para abrir as configurações do sistema',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: _permissionGranted
                ? Icon(Icons.check_circle_outline,
                    color: Colors.green.shade600, size: 20)
                : Icon(Icons.open_in_new_outlined, color: cs.primary, size: 20),
            onTap: _permissionGranted
                ? null
                : () async {
                    await NotificationListenerBridge.openPermissionSettings();
                  },
          ),
          const Divider(height: 1, indent: 56),
          // ── Bank filter ──
          Consumer(
            builder: (ctx, r, _) {
              final allowed = r.watch(allowedAppPackagesProvider);
              final count = allowed.length;
              return ListTile(
                leading: const _IconBadge(
                  Icons.account_balance_outlined,
                  color: Color(0xFF7E57C2),
                ),
                title: const Text('Apps monitorados'),
                subtitle: Text(
                  count > 0
                      ? '$count ${count == 1 ? 'app ativo' : 'apps ativos'}'
                      : 'Nenhum app monitorado',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.of(ctx).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BankFilterScreen(),
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          // ── Auto-save toggle ──
          SwitchListTile(
            secondary: const _IconBadge(
              Icons.flash_on_outlined,
              color: Color(0xFFFFA726),
            ),
            title: const Text('Pré-lançamento automático'),
            subtitle: const Text(
              'Salva a transação automaticamente para categorizar depois',
              style: TextStyle(fontSize: 12),
            ),
            value: autoSave,
            onChanged: (v) =>
                ref.read(notificationAutoSaveProvider.notifier).setValue(v),
          ),
        ],
        const Divider(height: 1, indent: 56),
      ],

      // ── Captura do texto copiado (iOS e Android) ──────────────────────────
      if (!kIsWeb) ...[
        SwitchListTile(
          secondary: const _IconBadge(
            Icons.content_paste_outlined,
            color: Color(0xFF66BB6A),
          ),
          title: const Text('Captura do texto copiado'),
          subtitle: const Text(
            'Ao copiar um valor (ex.: do app do banco) e voltar ao Fintab, '
            'oferecemos lançar a transação já preenchida',
            style: TextStyle(fontSize: 12),
          ),
          value: clipboardCapture,
          onChanged: (v) =>
              ref.read(clipboardCaptureEnabledProvider.notifier).setValue(v),
        ),
        const Divider(height: 1, indent: 56),
      ],

      // ── Backlog tile — sempre visível (Android e iOS) ─────────────────────
      Consumer(
        builder: (ctx, r, _) {
          final count = r.watch(unimportedBacklogCountProvider);
          return ListTile(
            leading: const _IconBadge(
              Icons.inbox_outlined,
              color: Color(0xFF26C6DA),
            ),
            title: const Text('Histórico de notificações'),
            subtitle: Text(
              count > 0
                  ? '$count ${count == 1 ? 'notificação pendente' : 'notificações pendentes'}'
                  : 'Todas revisadas',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: count > 0
                ? Badge(
                    label: Text('$count'),
                    child: const Icon(Icons.chevron_right, size: 20),
                  )
                : const Icon(Icons.chevron_right, size: 20),
            onTap: () => Navigator.of(ctx).push(
              MaterialPageRoute<void>(
                builder: (_) => const BacklogScreen(),
              ),
            ),
          );
        },
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Web sidebar navigation (visible only on web)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Full left sidebar for web layout
// ─────────────────────────────────────────────────────────────────────────────

class _WebFullSidebar extends StatelessWidget {
  final String? photoUrl;
  final String displayName;
  final String email;
  final String initials;
  final AppLocalizations l10n;
  final VoidCallback onAccount;
  final VoidCallback onPreferences;
  final VoidCallback onData;
  final VoidCallback onSharing;
  final VoidCallback onNotifications;
  final VoidCallback onLogout;
  final VoidCallback onEditProfile;
  final VoidCallback onBack;

  const _WebFullSidebar({
    required this.photoUrl,
    required this.displayName,
    required this.email,
    required this.initials,
    required this.l10n,
    required this.onAccount,
    required this.onPreferences,
    required this.onData,
    required this.onSharing,
    required this.onNotifications,
    required this.onLogout,
    required this.onEditProfile,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kDarkBlue, _kBlue],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Back to home ─────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 14, color: Colors.white70),
                label: const Text('Início',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
              ),
            ),
          ),

          // ── User profile header ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    UserAvatar(
                      photoUrl: photoUrl,
                      initials: initials,
                      radius: 40,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      textStyle: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Positioned(
                      right: 60,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: onEditProfile,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit,
                              size: 13, color: _kDarkBlue),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  displayName.isNotEmpty ? displayName : l10n.noName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
          const SizedBox(height: 8),

          // ── Nav label ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'NAVEGAÇÃO',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.4),
                letterSpacing: 1.2,
              ),
            ),
          ),

          // ── Nav items ─────────────────────────────────────────────
          _SidebarItem(
            icon: Icons.person_outline,
            label: 'Conta',
            onTap: onAccount,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          _SidebarItem(
            icon: Icons.tune_rounded,
            label: 'Preferências',
            onTap: onPreferences,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          _SidebarItem(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Dados',
            onTap: onData,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          _SidebarItem(
            icon: Icons.people_outline,
            label: 'Compartilhamento',
            onTap: onSharing,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          _SidebarItem(
            icon: Icons.notifications_none_rounded,
            label: 'Notificações',
            onTap: onNotifications,
            color: Colors.white.withValues(alpha: 0.85),
          ),

          const Spacer(),
          Divider(
              color: Colors.white.withValues(alpha: 0.15),
              height: 1,
              indent: 16,
              endIndent: 16),
          _SidebarItem(
            icon: Icons.logout_rounded,
            label: 'Sair',
            onTap: onLogout,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = color ?? cs.onSurface.withValues(alpha: 0.75);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 17, color: effectiveColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: effectiveColor,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App lock card (PIN + biometrics)
// ─────────────────────────────────────────────────────────────────────────────

class _AppLockCard extends ConsumerWidget {
  const _AppLockCard();

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final notifier = ref.read(appLockProvider.notifier);
    if (enable) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const SetupPinScreen()),
      );
    } else {
      final l10n = AppLocalizations.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.disableAppLockTitle),
          content: Text(l10n.disableAppLockMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
      if (confirmed == true) await notifier.disable();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(appLockProvider);
    final service = ref.read(appLockServiceProvider);

    if (!service.isPlatformSupported) {
      return _SettingsCard(children: [
        ListTile(
          leading:
              const _IconBadge(Icons.lock_outline, color: Color(0xFF7E57C2)),
          title: Text(l10n.appLockTitle),
          subtitle: Text(l10n.appLockUnavailableWeb,
              style: const TextStyle(fontSize: 12)),
          enabled: false,
        ),
      ]);
    }

    return _SettingsCard(children: [
      SwitchListTile(
        secondary:
            const _IconBadge(Icons.lock_outline, color: Color(0xFF7E57C2)),
        title: Text(l10n.appLockTitle),
        subtitle:
            Text(l10n.appLockSubtitle, style: const TextStyle(fontSize: 12)),
        value: state.enabled,
        onChanged: (v) => _toggle(context, ref, v),
      ),
      if (state.enabled) ...[
        const Divider(height: 1, indent: 56),
        if (state.biometricAvailable)
          SwitchListTile(
            secondary:
                const _IconBadge(Icons.fingerprint, color: Color(0xFF26A69A)),
            title: Text(l10n.useBiometrics),
            subtitle: Text(l10n.useBiometricsDesc,
                style: const TextStyle(fontSize: 12)),
            value: state.biometricEnabled,
            onChanged: (v) =>
                ref.read(appLockProvider.notifier).setBiometricEnabled(v),
          ),
        if (state.biometricAvailable) const Divider(height: 1, indent: 56),
        ListTile(
          leading:
              const _IconBadge(Icons.pin_outlined, color: Color(0xFF42A5F5)),
          title: Text(l10n.changePin),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SetupPinScreen()),
          ),
        ),
      ],
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Import / Export card (OFX, CSV → Excel, PDF) — Pro feature
// ─────────────────────────────────────────────────────────────────────────────

class _DataIoCard extends ConsumerWidget {
  const _DataIoCard();

  void _openImport(BuildContext context, WidgetRef ref) {
    if (!ref.read(isProProvider)) {
      showProGateBottomSheet(
        context,
        featureName: 'Importação de extratos',
        featureDescription:
            'Importe arquivos OFX ou CSV do seu banco e traga suas transações em segundos.',
        featureIcon: Icons.file_download_rounded,
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ImportScreen(),
    ));
  }

  void _openExport(BuildContext context, WidgetRef ref) {
    if (!ref.read(isProProvider)) {
      showProGateBottomSheet(
        context,
        featureName: 'Exportação de relatórios',
        featureDescription:
            'Gere PDF ou Excel das suas transações para compartilhar ou arquivar.',
        featureIcon: Icons.ios_share_rounded,
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ExportScreen(),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isPro = ref.watch(isProProvider);
    return _SettingsCard(children: [
      ListTile(
        leading: const _IconBadge(Icons.file_download_outlined,
            color: Color(0xFF26A69A)),
        title: Row(
          children: [
            Text(l10n.importTitle),
            const SizedBox(width: 8),
            if (!isPro) const ProBadgeWidget(),
          ],
        ),
        subtitle:
            Text(l10n.importSubtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => _openImport(context, ref),
      ),
      const Divider(height: 1, indent: 56),
      ListTile(
        leading: const _IconBadge(Icons.ios_share_outlined,
            color: Color(0xFFAB47BC)),
        title: Row(
          children: [
            Text(l10n.exportTitle),
            const SizedBox(width: 8),
            if (!isPro) const ProBadgeWidget(),
          ],
        ),
        subtitle:
            Text(l10n.exportSubtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => _openExport(context, ref),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Financial Health card (score + insights) — Pro feature
// ─────────────────────────────────────────────────────────────────────────────

class _FinancialHealthCard extends ConsumerWidget {
  const _FinancialHealthCard();

  void _open(BuildContext context, WidgetRef ref) {
    if (!ref.read(isProProvider)) {
      showProGateBottomSheet(
        context,
        featureName: 'Saúde financeira',
        featureDescription:
            'Veja seu score de 0 a 100 e descubra como melhorar suas finanças.',
        featureIcon: Icons.monitor_heart_rounded,
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const FinancialHealthScreen(),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isPro = ref.watch(isProProvider);
    final score = isPro ? ref.watch(financialScoreProvider).scoreRounded : null;
    return _SettingsCard(children: [
      ListTile(
        leading: const _IconBadge(Icons.monitor_heart_outlined,
            color: Color(0xFFEC407A)),
        title: Row(
          children: [
            Text(l10n.financialHealthTitle),
            const SizedBox(width: 6),
            HelpHint(
              title: l10n.hintFinancialHealthTitle,
              body: l10n.hintFinancialHealthBody,
              showForIntermediate: true,
            ),
            const SizedBox(width: 6),
            if (!isPro) const ProBadgeWidget(),
          ],
        ),
        subtitle: Text(l10n.financialHealthSubtitle,
            style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (score != null)
              Text('$score / 100',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
        onTap: () => _open(context, ref),
      ),
    ]);
  }
}
