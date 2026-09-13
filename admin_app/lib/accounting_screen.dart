import 'package:flutter/material.dart';

import 'admin_analytics.dart';
import 'admin_api.dart';
import 'admin_models.dart';

const _expenseCategories = {
  'rent': 'إيجار',
  'shipping': 'شحن وتوصيل',
  'marketing': 'إعلانات وتسويق',
  'salary': 'رواتب',
  'utilities': 'كهرباء وخدمات',
  'supplies': 'تجهيزات ومستلزمات',
  'other': 'مصروف آخر',
};

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  AccountingSummary? _summary;
  List<AdminExpense> _expenses = [];
  bool _loading = true;
  Object? _error;
  String _period = 'all';

  (int, int) get _range {
    final now = DateTime.now();
    final end = now.millisecondsSinceEpoch;
    return switch (_period) {
      'today' => (DateTime(now.year, now.month, now.day).millisecondsSinceEpoch, end),
      'week' => (now.subtract(Duration(days: now.weekday - 1)).copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0).millisecondsSinceEpoch, end),
      'month' => (DateTime(now.year, now.month).millisecondsSinceEpoch, end),
      'quarter' => (DateTime(now.year, now.month - 2).millisecondsSinceEpoch, end),
      _ => (0, 0),
    };
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final range = _range;
      final results = await Future.wait([
        AdminApi.instance.accountingSummary(fromMs: range.$1, toMs: range.$2),
        AdminApi.instance.expenses(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as AccountingSummary;
        _expenses = results[1] as List<AdminExpense>;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addExpense() async {
    final expense = await showModalBottomSheet<_ExpenseDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ExpenseSheet(),
    );
    if (expense == null) return;
    try {
      await AdminApi.instance.addExpense(
        amount: expense.amount,
        category: expense.category,
        description: expense.description,
        expenseAtMs: expense.date.millisecondsSinceEpoch,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل المصروف وتحديث صافي الربح')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر حفظ المصروف: $error')));
      }
    }
  }

  Future<void> _deleteExpense(AdminExpense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المصروف؟'),
        content: Text(
          '${expense.description}\n${expense.amount.toStringAsFixed(2)} د.ل',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AdminApi.instance.deleteExpense(expense.id);
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر حذف المصروف: $error')));
      }
    }
  }

  String _money(double value) => '${value.toStringAsFixed(2)} د.ل';

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null || _summary == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 52),
              const SizedBox(height: 12),
              Text('$_error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    final summary = _summary!;
    final range = _range;
    final visibleExpenses = _expenses.where((item) {
      if (range.$1 > 0 && item.expenseAtMs < range.$1) return false;
      if (range.$2 > 0 && item.expenseAtMs > range.$2) return false;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('كل المدة')),
              ButtonSegment(value: 'today', label: Text('اليوم')),
              ButtonSegment(value: 'week', label: Text('الأسبوع')),
              ButtonSegment(value: 'month', label: Text('هذا الشهر')),
              ButtonSegment(value: 'quarter', label: Text('3 أشهر')),
            ],
            selected: {_period},
            onSelectionChanged: (values) {
              setState(() => _period = values.first);
              _load();
            },
          ),
          const SizedBox(height: 14),
          _ProfitHero(summary: summary),
          const SizedBox(height: 10),
          _AccountingHighlights(summary: summary),
          const SizedBox(height: 10),
          _SmartInsightsCard(summary: summary),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 700;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: wide ? 4 : 2,
                childAspectRatio: wide ? 1.25 : 0.98,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _MetricCard(
                    icon: Icons.payments_outlined,
                    label: 'المبيعات الموصلة',
                    value: _money(summary.revenue),
                    note:
                        '${summary.deliveredOrders} طلب • ${summary.soldPieces} قطعة',
                  ),
                  _MetricCard(
                    icon: Icons.shopping_cart_checkout,
                    label: 'تكلفة القطع المباعة',
                    value: _money(summary.costOfGoods),
                    note: 'حسب سعر الشراء وقت البيع',
                  ),
                  _MetricCard(
                    icon: Icons.campaign_outlined,
                    label: 'عمولات المندوبات',
                    value: _money(summary.ambassadorCommissions),
                    note: 'التزام محاسبي للطلبات الموصلة',
                  ),
                  _MetricCard(
                    icon: Icons.receipt_long_outlined,
                    label: 'المصاريف',
                    value: _money(summary.expenses),
                    note: '${visibleExpenses.length} قيدًا ضمن المدة',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _AmbassadorBreakdownCard(summary: summary),
          const SizedBox(height: 12),
          _FormulaCard(summary: summary),
          const SizedBox(height: 12),
          _InventoryCard(summary: summary),
          if (summary.missingCostProducts > 0 ||
              summary.missingCostSoldPieces > 0) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'أكملي سعر الشراء لـ ${summary.missingCostProducts} منتج في المخزون. توجد ${summary.missingCostSoldPieces} قطعة مباعة بدون تكلفة محفوظة؛ صافي الربح قد يكون أعلى من الحقيقي حتى تُستكمل الأسعار.',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.bar_chart_rounded),
              title: const Text(
                'أداء المنتجات',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text('عرض أهم المنتجات فقط لتبسيط القراءة'),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                if (summary.topProducts.isEmpty)
                  const _EmptyCard(text: 'لا توجد مبيعات موصلة ضمن هذه المدة')
                else
                  for (final product in summary.topProducts.take(5))
                    _ProductProfitCard(product: product),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.groups_2_outlined),
              title: const Text(
                'أفضل المندوبات ماليًا',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text('للمدة المحددة مع توضيح المعتمد والمعلّق والجاري'),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                if (summary.topAmbassadors.isEmpty)
                  const _EmptyCard(text: 'لا توجد بيانات مندوبات ضمن هذه المدة')
                else
                  for (final ambassador in summary.topAmbassadors)
                    _TopAmbassadorTile(profile: ambassador),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionTitle(
            title: 'سجل المصاريف',
            subtitle: 'كل مصروف يُخصم مباشرة من صافي الربح',
            icon: Icons.account_balance_wallet_outlined,
            action: FilledButton.tonalIcon(
              onPressed: _addExpense,
              icon: const Icon(Icons.add),
              label: const Text('إضافة'),
            ),
          ),
          if (visibleExpenses.isEmpty)
            const _EmptyCard(text: 'لا توجد مصاريف مسجلة ضمن هذه المدة')
          else
            for (final expense in visibleExpenses)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: const CircleAvatar(
                    child: Icon(Icons.receipt_outlined),
                  ),
                  title: Text(
                    expense.description,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${_expenseCategories[expense.category] ?? 'مصروف آخر'} • ${formatDateTime(expense.expenseAtMs).split(' • ').first}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _money(expense.amount),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      InkWell(
                        onTap: () => _deleteExpense(expense),
                        child: const Text(
                          'حذف',
                          style: TextStyle(fontSize: 11, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }
}

class _ProfitHero extends StatelessWidget {
  const _ProfitHero({required this.summary});
  final AccountingSummary summary;

  @override
  Widget build(BuildContext context) {
    final positive = summary.netProfit >= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: positive
              ? const [Color(0xFF193C2B), Color(0xFF3F745A)]
              : const [Color(0xFF582525), Color(0xFF934848)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                positive ? Icons.trending_up_rounded : Icons.trending_down,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              const Text(
                'صافي الربح الفعلي',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${summary.netProfit.toStringAsFixed(2)} د.ل',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'بعد تكلفة الشراء وعمولات المندوبات والمصاريف المسجلة',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
  });
  final IconData icon;
  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              note,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}

class _AccountingHighlights extends StatelessWidget {
  const _AccountingHighlights({required this.summary});
  final AccountingSummary summary;

  String _money(double value) => '${value.toStringAsFixed(2)} د.ل';

  @override
  Widget build(BuildContext context) {
    final avgOrder = summary.deliveredOrders == 0
        ? 0.0
        : summary.revenue / summary.deliveredOrders;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _HighlightChip(
          icon: Icons.insights_rounded,
          label: 'الربح الإجمالي',
          value: _money(summary.grossProfit),
        ),
        _HighlightChip(
          icon: Icons.local_shipping_outlined,
          label: 'طلبات موصلة',
          value: '${summary.deliveredOrders}',
        ),
        _HighlightChip(
          icon: Icons.request_quote_outlined,
          label: 'متوسط الطلب',
          value: _money(avgOrder),
        ),
        _HighlightChip(
          icon: Icons.groups_2_outlined,
          label: 'المندوبات النشطات',
          value: '${summary.ambassadorCount}',
        ),
      ],
    );
  }
}

class _AmbassadorBreakdownCard extends StatelessWidget {
  const _AmbassadorBreakdownCard({required this.summary});

  final AccountingSummary summary;

  String _money(double value) => '${value.toStringAsFixed(2)} د.ل';

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.manage_accounts_outlined),
              SizedBox(width: 8),
              Text(
                'تفكيك عمولات المندوبات',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'نفصل هنا بين العمولة المحاسبية المستحقة على الطلبات الموصلة وبين ما تم اعتماده فعليًا وما يزال قيد الاعتماد أو في خط الأنابيب.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HighlightChip(
                icon: Icons.verified_outlined,
                label: 'معتمد',
                value: _money(summary.approvedAmbassadorCommissions),
              ),
              _HighlightChip(
                icon: Icons.pending_actions_outlined,
                label: 'بانتظار الاعتماد',
                value: _money(summary.pendingAmbassadorCommissions),
              ),
              _HighlightChip(
                icon: Icons.local_shipping_outlined,
                label: 'جاري',
                value: _money(summary.pipelineAmbassadorCommissions),
              ),
              _HighlightChip(
                icon: Icons.account_balance_wallet_outlined,
                label: 'قابل للسحب',
                value: _money(summary.availableAmbassadorBalance),
              ),
              _HighlightChip(
                icon: Icons.receipt_long_outlined,
                label: 'محجوز للسحب',
                value: _money(summary.reservedWithdrawalBalance),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 7),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    ),
  );
}

class _SmartInsightsCard extends StatelessWidget {
  const _SmartInsightsCard({required this.summary});
  final AccountingSummary summary;

  String _percent(double part, double total) {
    if (total <= 0) return '0%';
    return '${((part / total) * 100).toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    final margin = _percent(summary.netProfit, summary.revenue);
    final expenseRate = _percent(summary.expenses, summary.revenue);
    final commissionRate = _percent(
      summary.ambassadorCommissions,
      summary.revenue,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_graph_rounded),
                SizedBox(width: 8),
                Text(
                  'مؤشرات ذكية سريعة',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HighlightChip(
                  icon: Icons.percent_rounded,
                  label: 'هامش الربح الصافي',
                  value: margin,
                ),
                _HighlightChip(
                  icon: Icons.receipt_long_outlined,
                  label: 'نسبة المصاريف',
                  value: expenseRate,
                ),
                _HighlightChip(
                  icon: Icons.campaign_outlined,
                  label: 'نسبة العمولات',
                  value: commissionRate,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FormulaCard extends StatelessWidget {
  const _FormulaCard({required this.summary});
  final AccountingSummary summary;
  String money(double value) => '${value.toStringAsFixed(2)} د.ل';

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      leading: const Icon(Icons.calculate_outlined),
      title: const Text(
        'معادلة صافي الربح',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: const Text('شرح واضح وبسيط لكيف تم حساب الربح'),
      children: [
        _FormulaRow(label: 'المبيعات الموصلة', value: money(summary.revenue)),
        _FormulaRow(label: '− تكلفة القطع', value: money(summary.costOfGoods)),
        _FormulaRow(
          label: '= الربح الإجمالي',
          value: money(summary.grossProfit),
          strong: true,
        ),
        _FormulaRow(
          label: '− عمولات المندوبات',
          value: money(summary.ambassadorCommissions),
        ),
        _FormulaRow(label: '− المصاريف', value: money(summary.expenses)),
        const Divider(),
        _FormulaRow(
          label: '= صافي الربح',
          value: money(summary.netProfit),
          strong: true,
        ),
      ],
    ),
  );
}

class _FormulaRow extends StatelessWidget {
  const _FormulaRow({
    required this.label,
    required this.value,
    this.strong = false,
  });
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w900 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.summary});
  final AccountingSummary summary;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2_outlined),
              SizedBox(width: 8),
              Text(
                'قيمة المخزون المتبقي',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InventoryValue(
                  label: 'عدد القطع',
                  value: '${summary.inventoryPieces}',
                ),
              ),
              Expanded(
                child: _InventoryValue(
                  label: 'بسعر الشراء',
                  value: '${summary.inventoryCostValue.toStringAsFixed(2)} د.ل',
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _InventoryValue(
                  label: 'بسعر البيع',
                  value: '${summary.inventorySaleValue.toStringAsFixed(2)} د.ل',
                ),
              ),
              Expanded(
                child: _InventoryValue(
                  label: 'ربح متوقع',
                  value:
                      '${summary.inventoryPotentialProfit.toStringAsFixed(2)} د.ل',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _InventoryValue extends StatelessWidget {
  const _InventoryValue({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 3),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.action,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        // ignore: use_null_aware_elements
        if (action case final action?) action,
      ],
    ),
  );
}

class _ProductProfitCard extends StatelessWidget {
  const _ProductProfitCard({required this.product});
  final ProductAccountingSummary product;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.name,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _InventoryValue(
                  label: 'القطع',
                  value: '${product.pieces}',
                ),
              ),
              Expanded(
                child: _InventoryValue(
                  label: 'المبيعات',
                  value: '${product.sales.toStringAsFixed(2)} د.ل',
                ),
              ),
              Expanded(
                child: _InventoryValue(
                  label: 'التكلفة',
                  value: '${product.cost.toStringAsFixed(2)} د.ل',
                ),
              ),
              Expanded(
                child: _InventoryValue(
                  label: 'الربح',
                  value: '${product.profit.toStringAsFixed(2)} د.ل',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _TopAmbassadorTile extends StatelessWidget {
  const _TopAmbassadorTile({required this.profile});

  final AmbassadorFinanceProfile profile;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(12),
      leading: const CircleAvatar(child: Icon(Icons.campaign_outlined)),
      title: Text(
        profile.name,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        'مبيعات ${profile.sales.toStringAsFixed(2)} د.ل • ${profile.ordersCount} طلبات',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${profile.approvedCommission.toStringAsFixed(2)} د.ل',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          Text(
            'معلّق ${profile.pendingApprovalCommission.toStringAsFixed(2)} • جاري ${profile.pipelineCommission.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Center(child: Text(text)),
    ),
  );
}

class _ExpenseDraft {
  const _ExpenseDraft({
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
  });
  final double amount;
  final String category;
  final String description;
  final DateTime date;
}

class _ExpenseSheet extends StatefulWidget {
  const _ExpenseSheet();
  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String _category = 'shipping';
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: _date,
    );
    if (date != null) setState(() => _date = date);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'إضافة مصروف',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'المبلغ',
                suffixText: 'د.ل',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'نوع المصروف'),
              items: _expenseCategories.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'وصف المصروف',
                hintText: 'مثال: تكلفة توصيل طلبات الأسبوع',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('التاريخ: ${_date.day}/${_date.month}/${_date.year}'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                final amount = double.tryParse(_amount.text.trim()) ?? 0;
                if (amount <= 0 || _description.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('أدخلي المبلغ والوصف')),
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  _ExpenseDraft(
                    amount: amount,
                    category: _category,
                    description: _description.text.trim(),
                    date: _date,
                  ),
                );
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('حفظ المصروف'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
