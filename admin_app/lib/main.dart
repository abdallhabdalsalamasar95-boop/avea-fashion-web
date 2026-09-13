import 'package:flutter/material.dart';

import 'admin_screens.dart';
import 'accounting_screen.dart';
import 'product_editor.dart';
import 'professional_screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (details) => Material(
    color: const Color(0xFFF8F4EF),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 10),
            const Text(
              'حصل خطأ أثناء فتح الصفحة',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              details.exceptionAsString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    ),
  );
  runApp(const CarmenKarlaAdminApp());
}

class CarmenKarlaAdminApp extends StatelessWidget {
  const CarmenKarlaAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8B5E3C),
      brightness: Brightness.light,
      surface: const Color(0xFFFFFBF7),
    );
    return MaterialApp(
      title: 'CARMEN KARLA Admin',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF8F4EF),
        fontFamilyFallback: const ['Arial'],
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF261A16),
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: .6),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
        ),
      ),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.0,
            ),
          ),
          child: Directionality(textDirection: TextDirection.rtl, child: child!),
        );
      },
      home: const NativeAdminShell(),
    );
  }
}

enum AdminSection {
  overview('نظرة عامة', Icons.space_dashboard_rounded),
  products('المنتجات', Icons.inventory_2_rounded),
  orders('الطلبات', Icons.receipt_long_rounded),
  ambassadors('المندوبات', Icons.groups_2_rounded),
  withdrawals('طلبات سحب الأرباح', Icons.account_balance_wallet_rounded),
  accounting('الحسابات والأرباح', Icons.query_stats_rounded),
  marketing('العروض والحملات', Icons.local_offer_rounded),
  connection('اتصال الخادم', Icons.cloud_sync_rounded);

  const AdminSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

class NativeAdminShell extends StatefulWidget {
  const NativeAdminShell({super.key});
  @override
  State<NativeAdminShell> createState() => _NativeAdminShellState();
}

class _NativeAdminShellState extends State<NativeAdminShell> {
  static const _menuSections = AdminSection.values;
  AdminSection _section = AdminSection.overview;
  int _revision = 0;

  Widget _screen() => KeyedSubtree(
    key: ValueKey('${_section.name}-$_revision'),
    child: switch (_section) {
      AdminSection.overview => const OverviewScreen(),
      AdminSection.products => const ProductsScreen(),
      AdminSection.orders => const ProfessionalOrdersScreen(),
      AdminSection.ambassadors => const ProfessionalAmbassadorsScreen(),
      AdminSection.withdrawals => const ProfessionalWithdrawalsScreen(),
      AdminSection.accounting => const AccountingScreen(),
      AdminSection.marketing => const ProfessionalMarketingScreen(),
      AdminSection.connection => const ConnectionScreen(),
    },
  );

  Widget _safeBody() {
    try {
      return _screen();
    } catch (error) {
      return _ScreenFallback(error: error);
    }
  }

  void _select(AdminSection section) {
    Navigator.maybePop(context);
    setState(() => _section = section);
  }

  Future<void> _addProduct() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProductEditorScreen()),
    );
    if (changed == true && mounted)
      setState(() {
        _section = AdminSection.products;
        _revision++;
      });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CARMEN KARLA',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
          Text(
            _section.label,
            style: const TextStyle(fontSize: 11, color: Color(0xFFE0D4CD)),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'تحديث',
          onPressed: () => setState(() => _revision++),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    drawer: NavigationDrawer(
      selectedIndex: _menuSections.indexOf(_section),
      onDestinationSelected: (index) => _select(_menuSections[index]),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 28, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: Color(0xFF2B1D18),
                child: Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Color(0xFFE4B97E),
                  size: 30,
                ),
              ),
              SizedBox(height: 14),
              Text(
                'مركز التحكم',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              Text(
                'تطبيق Android أصلي للإدارة',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
        const Divider(),
        for (final section in _menuSections)
          NavigationDrawerDestination(
            icon: Icon(section.icon),
            selectedIcon: Icon(section.icon),
            label: Text(section.label),
          ),
        const Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'Flutter Native • REST API • لا يوجد WebView',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 11),
          ),
        ),
      ],
    ),
    floatingActionButton:
        _section == AdminSection.products || _section == AdminSection.overview
        ? FloatingActionButton.extended(
            onPressed: _addProduct,
            icon: const Icon(Icons.add),
            label: const Text('منتج جديد'),
          )
        : null,
    body: SafeArea(child: _safeBody()),
  );
}

class _ScreenFallback extends StatelessWidget {
  const _ScreenFallback({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 46),
          const SizedBox(height: 10),
          const Text(
            'تعذر عرض هذه الصفحة',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const NativeAdminShell()),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة التحميل'),
          ),
        ],
      ),
    ),
  );
}
