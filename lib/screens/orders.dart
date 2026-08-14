import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_settings.dart';
import '../services/cart_repository.dart';
import '../services/app_shell_nav.dart';
import '../services/firebase_auth_service.dart';
import '../utils/money.dart';
import '../widgets/ad_banner.dart';
import '../widgets/network_or_placeholder_image.dart';
import '../widgets/empty_state.dart';

class OrdersScreen extends StatefulWidget {
  /// When true, shows admin-only tooling (change status + contact shortcuts).
  ///
  /// Customer app should keep this false.
  final bool adminMode;

  const OrdersScreen({
    super.key,
    this.adminMode = false,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;
  bool _usingCloud = false;
  Timer? _refreshTimer;
  int _lastLocalStatusSyncMs = 0;

  bool get _preferServerControl {
    final settings = AppSettings();
    return settings.localCatalogEnabled.value &&
        settings.localCatalogBaseUrl.value.trim().isNotEmpty;
  }

  String _adminStatusFilter = 'all';
  bool _adminOnlyAmbassador = false;
  _OrdersRange _adminRange = _OrdersRange.month;

  int _coerceInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  String _normalizeStatus(dynamic raw) {
    final s = (raw ?? 'pending').toString().trim().toLowerCase();
    switch (s) {
      case 'confirmed':
        return 'confirmed';
      case 'processing':
      case 'in_progress':
      case 'in-progress':
        return 'processing';
      case 'shipped':
        return 'shipped';
      case 'postponed':
        return 'postponed';
      case 'delivered':
        return 'delivered';
      case 'canceled':
      case 'cancelled':
        return 'canceled';
      case 'returning':
        return 'returning';
      case 'returned':
        return 'returned';
      default:
        return 'pending';
    }
  }

  bool _isAmbassadorOrder(Map<String, dynamic> order) {
    final payload = (order['payload'] as Map?) != null
        ? Map<String, dynamic>.from(order['payload'] as Map)
        : <String, dynamic>{};
    final customer = (payload['customer'] as Map?) != null
        ? Map<String, dynamic>.from(payload['customer'] as Map)
        : <String, dynamic>{};
    if (customer['submittedViaShareLink'] == true) return false;
    return customer['placedAsAmbassador'] == true ||
        (customer['accountRole'] ?? '').toString() == 'ambassador';
  }

  bool _matchesAdminFilters(Map<String, dynamic> order) {
    if (!widget.adminMode) return true;

    final status = _normalizeStatus(order['status']);
    if (_adminStatusFilter != 'all' && status != _adminStatusFilter) {
      return false;
    }

    if (_adminOnlyAmbassador && !_isAmbassadorOrder(order)) {
      return false;
    }

    final createdAtMs = _coerceInt(order['createdAt']);
    if (createdAtMs <= 0) return true;

    final created = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
    final now = DateTime.now();
    final from = switch (_adminRange) {
      _OrdersRange.today => DateTime(now.year, now.month, now.day),
      _OrdersRange.week => now.subtract(const Duration(days: 7)),
      _OrdersRange.month => now.subtract(const Duration(days: 30)),
      _OrdersRange.all => DateTime.fromMillisecondsSinceEpoch(0),
    };
    return !created.isBefore(from);
  }

  String _statusLabel(String status) {
    switch (_normalizeStatus(status)) {
      case 'pending':
        return 'قيد الانتظار';
      case 'confirmed':
        return 'تم التأكيد';
      case 'processing':
        return 'قيد المعالجة';
      case 'shipped':
        return 'تم الشحن';
      case 'delivered':
        return 'تم التوصيل';
      case 'canceled':
        return 'ملغي';
      default:
        return 'قيد الانتظار';
    }
  }

  IconData _statusIcon(String status) {
    switch (_normalizeStatus(status)) {
      case 'confirmed':
        return Icons.verified_outlined;
      case 'processing':
        return Icons.handyman_outlined;
      case 'shipped':
        return Icons.local_shipping_outlined;
      case 'delivered':
        return Icons.done_all_rounded;
      case 'canceled':
        return Icons.cancel_outlined;
      default:
        return Icons.hourglass_empty_rounded;
    }
  }

  Map<String, dynamic> _orderAmbassadorSummary(Map<String, dynamic> order) {
    final payload = (order['payload'] as Map?) != null
        ? Map<String, dynamic>.from(order['payload'] as Map)
        : <String, dynamic>{};
    final summary = (order['ambassadorSummary'] as Map?) != null
        ? Map<String, dynamic>.from(order['ambassadorSummary'] as Map)
        : ((payload['ambassadorSummary'] as Map?) != null
            ? Map<String, dynamic>.from(payload['ambassadorSummary'] as Map)
            : <String, dynamic>{});
    return summary;
  }

  bool _canCancel(String status) {
    // Customer can only cancel before shipping starts.
    final normalized = _normalizeStatus(status);
    return normalized == 'pending' ||
        normalized == 'confirmed' ||
        normalized == 'processing';
  }

  Future<void> _confirmCancelAndApply(
    String orderId, {
    required bool asAmbassador,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content:
            const Text('هل تريد إلغاء هذا الطلب؟ لا يمكن التراجع بعد الإلغاء.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('رجوع')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إلغاء الطلب'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CartRepository().cancelCurrentUserOrder(
        orderId,
        asAmbassador: asAmbassador,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم إلغاء الطلب')));
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _showChangeStatus(String orderId) async {
    const options = [
      ('pending', 'قيد المراجعة', Icons.hourglass_empty_rounded),
      ('confirmed', 'تم التأكيد', Icons.verified_outlined),
      ('processing', 'قيد المعالجة', Icons.handyman_outlined),
      ('shipped', 'تم الشحن', Icons.local_shipping_outlined),
      ('delivered', 'تم التوصيل', Icons.done_all_rounded),
      ('canceled', 'ملغي', Icons.cancel_outlined),
    ];
    final picked = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          return ListView.separated(
            itemCount: options.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final s = options[index];
              return ListTile(
                leading: Icon(s.$3),
                title: Text(s.$2),
                subtitle: Text('القيمة البرمجية: ${s.$1}'),
                onTap: () => Navigator.pop(ctx, s.$1),
              );
            },
          );
        });
    if (!mounted) return;
    if (picked != null) {
      if (widget.adminMode && _usingCloud) {
        try {
          await CartRepository().updateAdminOrderStatusInCloud(orderId, picked);
        } catch (_) {
          // fallback to local update below
        }
      }
      await CartRepository().updateOrderStatus(orderId, picked);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تم تغيير الحالة إلى $picked')));
    }
  }

  Future<void> _copyToClipboard(String text) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('تم النسخ')));
  }

  Future<void> _openUri(Uri uri) async {
    final ok = await canLaunchUrl(uri);
    if (ok) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح الرابط على هذا الجهاز')));
  }

  Color _statusColor(BuildContext context, String status) {
    final cs = Theme.of(context).colorScheme;
    switch (_normalizeStatus(status)) {
      case 'confirmed':
        return Colors.amber.shade700;
      case 'processing':
        return Colors.deepOrange;
      case 'shipped':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'canceled':
        return cs.error;
      default:
        return cs.primary;
    }
  }

  String _dateLabel(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} • '
        '${two(value.hour)}:${two(value.minute)}';
  }

  String? _firstItemImage(Map<String, dynamic> payload) {
    final items = (payload['items'] as List?)?.cast<dynamic>() ?? const [];
    for (final it in items) {
      if (it is! Map) continue;
      final url = (it['imageUrl'] ?? '').toString().trim();
      if (url.isNotEmpty) return url;
    }
    return null;
  }

  String _itemsPreview(Map<String, dynamic> payload) {
    final items = (payload['items'] as List?)?.cast<dynamic>() ?? const [];
    if (items.isEmpty) return 'بدون عناصر';
    final names = <String>[];
    for (final it in items.take(2)) {
      if (it is! Map) continue;
      final name = (it['name'] ?? '').toString().trim();
      if (name.isNotEmpty) names.add(name);
    }
    final extra = items.length - names.length;
    final base = names.isEmpty ? '${items.length} عنصر' : names.join(' • ');
    return extra > 0 ? '$base  +$extra' : base;
  }

  Widget _infoPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ordersOverviewCard(
    BuildContext context,
    List<Map<String, dynamic>> orders,
  ) {
    final cs = Theme.of(context).colorScheme;
    final openCount = orders.where((o) {
      final s = _normalizeStatus(o['status']);
      return s == 'pending' || s == 'confirmed' || s == 'processing';
    }).length;
    final deliveredCount = orders
        .where((o) => _normalizeStatus(o['status']) == 'delivered')
        .length;
    final shippedCount =
        orders.where((o) => _normalizeStatus(o['status']) == 'shipped').length;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.06),
            cs.tertiary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.receipt_long_rounded, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.adminMode ? 'إدارة الطلبات' : 'طلباتك السابقة',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.adminMode
                          ? 'تابعي الحالات وعدليها من واجهة أنظف وأوضح.'
                          : 'كل طلب ظاهر هنا مع حالته الحالية، تفاصيله، وخطوات المتابعة بشكل واضح.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.5,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _infoPill(context,
                  icon: Icons.shopping_bag_outlined,
                  label: 'الإجمالي',
                  value: '${orders.length} طلب'),
              _infoPill(context,
                  icon: Icons.hourglass_top_rounded,
                  label: 'المفتوحة',
                  value: '$openCount'),
              _infoPill(context,
                  icon: Icons.local_shipping_outlined,
                  label: 'قيد الشحن',
                  value: '$shippedCount'),
              _infoPill(context,
                  icon: Icons.done_all_rounded,
                  label: 'تم التوصيل',
                  value: '$deliveredCount'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> o) {
    final created =
        DateTime.fromMillisecondsSinceEpoch(_coerceInt(o['createdAt']));
    final payload = o['payload'] as Map<String, dynamic>? ?? {};
    final pricing = (payload['pricing'] as Map?) != null
        ? Map<String, dynamic>.from(payload['pricing'] as Map)
        : <String, dynamic>{};
    String totalText() {
      final raw = (pricing['grandTotal'] ?? payload['total']);
      if (raw is num) return Money.lyd2(raw.toDouble());
      final s = (raw ?? '').toString().trim();
      final n = double.tryParse(s);
      return n == null ? (s.isEmpty ? '—' : '$s د.ل') : Money.lyd2(n);
    }

    final shipping = pricing['shipping'];
    final discount = pricing['discount'];
    final coupon = pricing['couponCode'];
    final customer = (payload['customer'] as Map?) != null
        ? Map<String, dynamic>.from(payload['customer'] as Map)
        : <String, dynamic>{};
    final isAmbassadorOrder = _isAmbassadorOrder(o);

    final shippingVal = shipping is num
        ? shipping.toDouble()
        : double.tryParse((shipping ?? '').toString());
    final discountVal = discount is num
        ? discount.toDouble()
        : double.tryParse((discount ?? '').toString());
    final status = _normalizeStatus(o['status']);
    final canCancel = _canCancel(status);
    final cs = Theme.of(context).colorScheme;
    final statusColor = _statusColor(context, status);
    final heroImage = _firstItemImage(payload);
    final customerName = (customer['name'] ?? '').toString().trim();
    final customerCity = (customer['city'] ?? '').toString().trim();
    final itemsCount = ((payload['items'] as List?)?.length ?? 0);

    Future<void> openDetails() async {
      await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Text('تفاصيل الطلب #${o['orderId']}'),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((payload['customer'] as Map?) != null) ...[
                        Text(
                          widget.adminMode ? 'بيانات العميل' : 'بيانات الشحن',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Builder(builder: (context) {
                          final customer = Map<String, dynamic>.from(
                              payload['customer'] as Map);
                          final name = (customer['name'] ?? '').toString();
                          final phone = (customer['phone'] ?? '').toString();
                          final address =
                              (customer['address'] ?? '').toString();
                          final city = (customer['city'] ?? '').toString();
                          final payment =
                              (customer['paymentMethod'] ?? '').toString();
                          final note = (customer['note'] ?? '').toString();
                          final accountRoleLabel =
                              (customer['accountRoleLabel'] ?? '').toString();
                          final placedAsAmbassador =
                              customer['placedAsAmbassador'] == true;
                          final submitterUid =
                              (customer['submitterUid'] ?? '').toString();
                          final submitterEmail =
                              (customer['submitterEmail'] ?? '').toString();
                          final summary = _formatOrderSummaryText(
                            orderId: (o['orderId'] ?? '').toString(),
                            createdAt: created,
                            status: _statusLabel(status),
                            payload: payload,
                          );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('الاسم: ${name.isEmpty ? '—' : name}'),
                              Text('الهاتف: ${phone.isEmpty ? '—' : phone}'),
                              Text('المدينة: ${city.isEmpty ? '—' : city}'),
                              Text(
                                  'العنوان: ${address.isEmpty ? '—' : address}'),
                              if (payment.trim().isNotEmpty)
                                Text('طريقة الدفع: $payment'),
                              if (accountRoleLabel.trim().isNotEmpty)
                                Text('نوع الحساب: $accountRoleLabel'),
                              if (placedAsAmbassador)
                                const Text('طلب مندوبة: نعم'),
                              if (submitterUid.trim().isNotEmpty)
                                Text('UID: $submitterUid'),
                              if (submitterEmail.trim().isNotEmpty)
                                Text('حساب الإرسال: $submitterEmail'),
                              if (note.trim().isNotEmpty) Text('ملاحظة: $note'),
                              if (_orderAmbassadorSummary(o).isNotEmpty) ...[
                                const SizedBox(height: 10),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Builder(
                                      builder: (context) {
                                        final s = _orderAmbassadorSummary(o);
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'ملخص المندوبة',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w900),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                                'القطع المباعة: ${s['soldPieces'] ?? '—'}'),
                                            Text(
                                                'إجمالي المبيعات: ${s['grossSales'] ?? '—'} د.ل'),
                                            Text(
                                                'العمولة التقديرية: ${s['estimatedCommission'] ?? '—'} د.ل'),
                                            Text(
                                                'النسبة: ${s['estimatedCommissionPercent'] ?? '—'}%'),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              if (widget.adminMode) ...[
                                _contactActions(phone: phone),
                                const SizedBox(height: 6),
                              ],
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: address.trim().isEmpty
                                        ? null
                                        : () => _copyToClipboard(address),
                                    icon:
                                        const Icon(Icons.location_on_outlined),
                                    label: const Text('نسخ العنوان'),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: () => _copyToClipboard(summary),
                                    icon:
                                        const Icon(Icons.receipt_long_outlined),
                                    label: const Text('نسخ تفاصيل الطلب'),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }),
                        const Divider(height: 20),
                      ],
                      Text('تفاصيل المبلغ',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      if (pricing.isNotEmpty) ...[
                        _PriceLine(
                            label: 'المجموع الفرعي',
                            value:
                                '${(pricing['subtotal'] ?? '').toString()} د.ل'),
                        _PriceLine(
                          label: 'الشحن',
                          value: (pricing['shipping'] == null ||
                                  (pricing['shipping'] as num).toDouble() == 0)
                              ? 'مجاني'
                              : '${pricing['shipping']} د.ل',
                        ),
                        _PriceLine(
                          label: 'الخصم',
                          value: (pricing['discount'] == null ||
                                  (pricing['discount'] as num).toDouble() == 0)
                              ? '—'
                              : '-${pricing['discount']} د.ل',
                        ),
                        if (pricing['couponCode'] != null &&
                            pricing['couponCode'].toString().isNotEmpty)
                          _PriceLine(
                              label: 'الكوبون',
                              value: pricing['couponCode'].toString()),
                        const Divider(height: 18),
                        _PriceLine(
                            label: 'الإجمالي',
                            value:
                                '${(pricing['grandTotal'] ?? payload['total'] ?? '').toString()} د.ل',
                            bold: true),
                      ] else ...[
                        Text('المجموع: ${payload['total'] ?? ''} د.ل',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                      const SizedBox(height: 8),
                      const Text('عناصر الطلب:'),
                      const SizedBox(height: 8),
                      ...((payload['items'] as List<dynamic>?) ?? const [])
                          .map((it) {
                        final m = Map<String, dynamic>.from(it as Map);
                        final sz = (m['size'] ?? '').toString().trim();
                        final ln = (m['length'] ?? '').toString().trim();
                        final meta = <String>[];
                        if (sz.isNotEmpty) meta.add('المقاس: $sz');
                        if (ln.isNotEmpty) meta.add('الطول: $ln');
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: SizedBox(
                            width: 40,
                            height: 40,
                            child: NetworkOrPlaceholderImage(
                              url: m['imageUrl']?.toString(),
                              borderRadius: 8,
                              fit: BoxFit.cover,
                              showLoadingSpinner: false,
                            ),
                          ),
                          title: Text(
                            meta.isEmpty
                                ? (m['name'] ?? '').toString()
                                : '${(m['name'] ?? '').toString()}  •  ${meta.join('  •  ')}',
                          ),
                          trailing: Text(
                              '${m['quantity'] ?? 1} x ${m['price'] ?? ''}'),
                        );
                      }),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إغلاق')),
                  if (!widget.adminMode && canCancel)
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _confirmCancelAndApply(
                          o['orderId'] as String,
                          asAmbassador: isAmbassadorOrder,
                        );
                      },
                      style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error),
                      child: const Text('إلغاء الطلب'),
                    ),
                  if (widget.adminMode) ...[
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        _showChangeStatus(o['orderId'] as String);
                      },
                      child: const Text('تغيير حالة الطلب'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final nameCtl = TextEditingController(
                            text: (payload['customer']?['name'] ?? '')
                                .toString());
                        final phoneCtl = TextEditingController(
                            text: (payload['customer']?['phone'] ?? '')
                                .toString());
                        final addressCtl = TextEditingController(
                            text: (payload['customer']?['address'] ?? '')
                                .toString());
                        final cityCtl = TextEditingController(
                            text: (payload['customer']?['city'] ?? '')
                                .toString());
                        final noteCtl = TextEditingController(
                            text: (payload['customer']?['note'] ?? '')
                                .toString());
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (c2) => AlertDialog(
                            title: const Text('تعديل بيانات الطلب'),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                      controller: nameCtl,
                                      decoration: const InputDecoration(
                                          labelText: 'الاسم')),
                                  TextField(
                                      controller: phoneCtl,
                                      decoration: const InputDecoration(
                                          labelText: 'الهاتف'),
                                      keyboardType: TextInputType.phone),
                                  TextField(
                                      controller: cityCtl,
                                      decoration: const InputDecoration(
                                          labelText: 'المدينة')),
                                  TextField(
                                      controller: addressCtl,
                                      decoration: const InputDecoration(
                                          labelText: 'العنوان')),
                                  TextField(
                                      controller: noteCtl,
                                      decoration: const InputDecoration(
                                          labelText: 'ملاحظة'),
                                      maxLines: 2),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(c2, false),
                                  child: const Text('إلغاء')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(c2, true),
                                  child: const Text('حفظ')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          if (widget.adminMode && _usingCloud) {
                            try {
                              await CartRepository()
                                  .updateAdminOrderCustomerInCloud(
                                o['orderId'] as String,
                                {
                                  'name': nameCtl.text.trim(),
                                  'phone': phoneCtl.text.trim(),
                                  'city': cityCtl.text.trim(),
                                  'address': addressCtl.text.trim(),
                                  'note': noteCtl.text.trim(),
                                },
                              );
                            } catch (_) {}
                          }
                          await CartRepository()
                              .updateOrderCustomer(o['orderId'] as String, {
                            'name': nameCtl.text.trim(),
                            'phone': phoneCtl.text.trim(),
                            'city': cityCtl.text.trim(),
                            'address': addressCtl.text.trim(),
                            'note': noteCtl.text.trim(),
                          });
                          await _load();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم حفظ التعديل')));
                        }
                        nameCtl.dispose();
                        phoneCtl.dispose();
                        addressCtl.dispose();
                        cityCtl.dispose();
                        noteCtl.dispose();
                      },
                      child: const Text('حفظ التعديل'),
                    ),
                    if (canCancel)
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _confirmCancelAndApply(
                            o['orderId'] as String,
                            asAmbassador: isAmbassadorOrder,
                          );
                        },
                        style: TextButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.error),
                        child: const Text('إلغاء الطلب'),
                      ),
                  ],
                ],
              ));
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: openDetails,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.9)),
                      ),
                      child: heroImage == null
                          ? Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: cs.surfaceContainerLow,
                              ),
                              child: Icon(Icons.shopping_bag_outlined,
                                  color: cs.onSurfaceVariant),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(17),
                              child: NetworkOrPlaceholderImage(
                                url: heroImage,
                                fit: BoxFit.cover,
                                showLoadingSpinner: false,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'طلب #${o['orderId']}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_statusIcon(status),
                                        size: 15, color: statusColor),
                                    const SizedBox(width: 6),
                                    Text(
                                      _statusLabel(status),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: statusColor,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _itemsPreview(payload),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      height: 1.45,
                                    ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (customerName.isNotEmpty)
                                _infoPill(context,
                                    icon: Icons.person_outline,
                                    label: 'العميل',
                                    value: customerName),
                              _infoPill(context,
                                  icon: Icons.receipt_outlined,
                                  label: 'العناصر',
                                  value: '$itemsCount'),
                              if (customerCity.isNotEmpty)
                                _infoPill(context,
                                    icon: Icons.location_on_outlined,
                                    label: 'المدينة',
                                    value: customerCity),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الإجمالي',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              totalText(),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: cs.outlineVariant,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(start: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'تاريخ الطلب',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _dateLabel(created),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (shippingVal != null ||
                    (discountVal != null && discountVal > 0) ||
                    (coupon != null && coupon.toString().isNotEmpty) ||
                    isAmbassadorOrder) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (shippingVal != null)
                        _infoPill(context,
                            icon: Icons.local_shipping_outlined,
                            label: 'الشحن',
                            value: shippingVal == 0
                                ? 'مجاني'
                                : Money.lyd2(shippingVal)),
                      if (discountVal != null && discountVal > 0)
                        _infoPill(context,
                            icon: Icons.discount_outlined,
                            label: 'الخصم',
                            value: '-${Money.lyd2(discountVal)}'),
                      if (coupon != null && coupon.toString().isNotEmpty)
                        _infoPill(context,
                            icon: Icons.confirmation_number_outlined,
                            label: 'الكوبون',
                            value: coupon.toString()),
                      if (widget.adminMode && isAmbassadorOrder)
                        _infoPill(context,
                            icon: Icons.campaign_outlined,
                            label: 'النوع',
                            value: 'طلب مندوبة'),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: openDetails,
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('عرض التفاصيل'),
                      ),
                    ),
                    if (!widget.adminMode && canCancel) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmCancelAndApply(
                            o['orderId'] as String,
                            asAmbassador: isAmbassadorOrder,
                          ),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('إلغاء الطلب'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.error,
                            side: BorderSide(
                                color: cs.error.withValues(alpha: 0.25)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _contactActions({required String phone}) {
    final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        FilledButton.tonalIcon(
          onPressed:
              normalized.isEmpty ? null : () => _copyToClipboard(normalized),
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('نسخ'),
        ),
        FilledButton.tonalIcon(
          onPressed: normalized.isEmpty
              ? null
              : () => _openUri(Uri.parse('tel:$normalized')),
          icon: const Icon(Icons.call_outlined),
          label: const Text('اتصال'),
        ),
        FilledButton.tonalIcon(
          onPressed: normalized.isEmpty
              ? null
              : () {
                  // WhatsApp supports https deep links.
                  final digits = normalized.replaceAll('+', '');
                  _openUri(Uri.parse('https://wa.me/$digits'));
                },
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('واتساب'),
        ),
      ],
    );
  }

  String _formatOrderSummaryText({
    required String orderId,
    required DateTime createdAt,
    required String status,
    required Map<String, dynamic> payload,
  }) {
    final customer = (payload['customer'] as Map?) != null
        ? Map<String, dynamic>.from(payload['customer'] as Map)
        : <String, dynamic>{};
    final pricing = (payload['pricing'] as Map?) != null
        ? Map<String, dynamic>.from(payload['pricing'] as Map)
        : <String, dynamic>{};
    final items = (payload['items'] as List?)?.cast<dynamic>() ?? const [];

    final name = (customer['name'] ?? '').toString();
    final phone = (customer['phone'] ?? '').toString();
    final address = (customer['address'] ?? '').toString();
    final city = (customer['city'] ?? '').toString();
    final payment = (customer['paymentMethod'] ?? '').toString();
    final note = (customer['note'] ?? '').toString();
    final accountRoleLabel = (customer['accountRoleLabel'] ?? '').toString();
    final placedAsAmbassador = customer['placedAsAmbassador'] == true;
    final submitterUid = (customer['submitterUid'] ?? '').toString();
    final submitterEmail = (customer['submitterEmail'] ?? '').toString();
    final summary = (payload['ambassadorSummary'] as Map?) != null
        ? Map<String, dynamic>.from(payload['ambassadorSummary'] as Map)
        : <String, dynamic>{};

    final subtotal = (pricing['subtotal'] as num?)?.toDouble();
    final shipping = (pricing['shipping'] as num?)?.toDouble();
    final discount = (pricing['discount'] as num?)?.toDouble();
    final coupon = (pricing['couponCode'] ?? '').toString();
    final grandTotal = (pricing['grandTotal'] as num?)?.toDouble();

    final b = StringBuffer();
    b.writeln('طلب #$orderId');
    b.writeln('التاريخ: ${createdAt.toLocal()}');
    b.writeln('الحالة: $status');
    if (name.trim().isNotEmpty) b.writeln('الاسم: $name');
    if (phone.trim().isNotEmpty) b.writeln('الهاتف: $phone');
    if (city.trim().isNotEmpty) b.writeln('المدينة: $city');
    if (address.trim().isNotEmpty) b.writeln('العنوان: $address');
    if (payment.trim().isNotEmpty) b.writeln('طريقة الدفع: $payment');
    if (note.trim().isNotEmpty) b.writeln('ملاحظة: $note');
    if (accountRoleLabel.trim().isNotEmpty) {
      b.writeln('نوع الحساب: $accountRoleLabel');
    }
    if (placedAsAmbassador) {
      b.writeln('طلب مندوبة: نعم');
    }
    if (submitterUid.trim().isNotEmpty) b.writeln('UID: $submitterUid');
    if (submitterEmail.trim().isNotEmpty) {
      b.writeln('حساب الإرسال: $submitterEmail');
    }
    if (summary.isNotEmpty) {
      final soldPieces = summary['soldPieces'];
      final grossSales = summary['grossSales'];
      final estimatedCommission = summary['estimatedCommission'];
      final commissionPercent = summary['estimatedCommissionPercent'];
      b.writeln('');
      b.writeln('ملخص المندوبة:');
      if (soldPieces != null) b.writeln('القطع المباعة: $soldPieces');
      if (grossSales != null) b.writeln('إجمالي المبيعات: $grossSales د.ل');
      if (estimatedCommission != null) {
        b.writeln('العمولة التقديرية: $estimatedCommission د.ل');
      }
      if (commissionPercent != null) {
        b.writeln('نسبة العمولة الفعلية: $commissionPercent%');
      }
    }

    b.writeln('');
    b.writeln('العناصر:');
    for (final it in items) {
      final m = Map<String, dynamic>.from(it as Map);
      final nm = (m['name'] ?? '').toString();
      final qty = (m['quantity'] ?? 1).toString();
      final price = (m['price'] ?? '').toString();
      final sz = (m['size'] ?? '').toString().trim();
      final ln = (m['length'] ?? '').toString().trim();
      final sizePart = sz.isEmpty ? '' : ' — المقاس: $sz';
      final lenPart = ln.isEmpty ? '' : ' — الطول: $ln';
      b.writeln('- $nm$sizePart$lenPart  ($qty × $price)');
    }

    b.writeln('');
    if (subtotal != null) {
      b.writeln('المجموع الفرعي: ${subtotal.toStringAsFixed(2)} د.ل');
    }
    if (shipping != null) {
      b.writeln(
          'الشحن: ${shipping == 0 ? 'مجاني' : '${shipping.toStringAsFixed(2)} د.ل'}');
    }
    if (discount != null && discount > 0) {
      b.writeln('الخصم: -${discount.toStringAsFixed(2)} د.ل');
    }
    if (coupon.trim().isNotEmpty) b.writeln('الكوبون: $coupon');
    if (grandTotal != null) {
      b.writeln('الإجمالي: ${grandTotal.toStringAsFixed(2)} د.ل');
    } else if (payload['total'] != null) {
      b.writeln('الإجمالي: ${payload['total']} د.ل');
    }
    return b.toString().trim();
  }

  Widget _inlineBannerSlot(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'إعلان',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          const AdBanner(),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted) return;
      _load();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _trySyncStatusesFromLocalServer();

      List<Map<String, dynamic>> rows;

      _usingCloud = false;
      if (!widget.adminMode) {
        final uid = FirebaseAuthService.instance.currentUser?.uid;
        if (_preferServerControl && uid != null) {
          rows = await CartRepository().getRemoteOrdersForUser(uid);
          if (rows.isEmpty) {
            rows = await CartRepository().getOrdersForLocalUser(uid: uid);
            rows = await _overlayRemoteStatuses(rows, uid: uid);
          }
        } else if (_preferServerControl) {
          rows = await CartRepository().getOrdersForLocalUser(uid: uid);
          rows = await _overlayRemoteStatuses(rows, uid: uid);
        } else if (uid != null) {
          try {
            rows = await CartRepository().getOrdersForUserFromCloud(uid);
            rows = await _overlayRemoteStatuses(rows, uid: uid);
            _usingCloud = true;
          } catch (_) {
            // Fallback to *local orders for this uid only* (privacy).
            rows = await CartRepository().getOrdersForLocalUser(uid: uid);
            rows = await _overlayRemoteStatuses(rows, uid: uid);
          }
        } else {
          rows = await CartRepository().getOrdersForLocalUser(uid: null);
          rows = await _overlayRemoteStatuses(rows, uid: null);
        }
      } else {
        if (_preferServerControl) {
          rows = await CartRepository().getOrders();
          rows = await _overlayRemoteStatuses(rows, uid: null);
        } else if (FirebaseAuthService.instance.isSupported) {
          try {
            rows = await CartRepository().getAdminOrdersFromCloud();
            rows = await _overlayRemoteStatuses(rows, uid: null);
            _usingCloud = true;
          } catch (_) {
            rows = await CartRepository().getOrders();
            rows = await _overlayRemoteStatuses(rows, uid: null);
            _usingCloud = false;
          }
        } else {
          rows = await CartRepository().getOrders();
          rows = await _overlayRemoteStatuses(rows, uid: null);
        }
      }

      if (!mounted) return;
      setState(() {
        _orders = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usingCloud = false;
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _trySyncStatusesFromLocalServer() async {
    try {
      final uid = widget.adminMode
          ? null
          : FirebaseAuthService.instance.currentUser?.uid;
      await CartRepository().syncLocalOrderStatusesFromServer(
        uid: uid,
        sinceMs: _lastLocalStatusSyncMs,
      );
      _lastLocalStatusSyncMs = DateTime.now().millisecondsSinceEpoch;
    } catch (_) {
      // Best effort only.
    }
  }

  Future<List<Map<String, dynamic>>> _overlayRemoteStatuses(
    List<Map<String, dynamic>> rows, {
    required String? uid,
  }) async {
    try {
      final statuses = await CartRepository().getRemoteOrderStatuses(uid: uid);
      if (statuses.isEmpty) return rows;

      return rows.map((row) {
        final orderId = (row['orderId'] ?? '').toString().trim();
        final remoteStatus = statuses[orderId];
        if (orderId.isEmpty || remoteStatus == null || remoteStatus.isEmpty) {
          return row;
        }
        return {
          ...row,
          'status': remoteStatus,
        };
      }).toList(growable: false);
    } catch (_) {
      return rows;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleOrders = widget.adminMode
        ? _orders.where(_matchesAdminFilters).toList(growable: false)
        : _orders;
    final showBanner = !widget.adminMode;

    String rangeLabel(_OrdersRange r) {
      switch (r) {
        case _OrdersRange.today:
          return 'اليوم';
        case _OrdersRange.week:
          return '7 أيام';
        case _OrdersRange.month:
          return '30 يوم';
        case _OrdersRange.all:
          return 'الكل';
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('الطلبات السابقة')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: Icons.wifi_off_outlined,
                  title: 'تعذر تحميل الطلبات',
                  subtitle:
                      'حصلت مشكلة أثناء قراءة البيانات المحلية. جربي مرة ثانية.',
                  action: FilledButton.tonal(
                    onPressed: _load,
                    child: const Text('إعادة المحاولة'),
                  ),
                )
              : visibleOrders.isEmpty
                  ? EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: widget.adminMode
                          ? 'لا توجد نتائج ضمن الفلاتر'
                          : 'لا توجد طلبات سابقة',
                      subtitle: widget.adminMode
                          ? 'غيّري الفلاتر أو وسّعي النطاق الزمني.'
                          : 'بعد ما تكملي أول طلب، بتشوفيه هنا مع حالته وتفاصيله.',
                      action: FilledButton.tonal(
                        onPressed: widget.adminMode
                            ? _load
                            : () {
                                AppShellNav.goHome();
                                Navigator.maybePop(context);
                              },
                        child: Text(widget.adminMode
                            ? 'تحديث البيانات'
                            : 'تصفح المنتجات'),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: visibleOrders.length +
                            (widget.adminMode ? 1 : 0) +
                            1 +
                            (showBanner ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _ordersOverviewCard(context, visibleOrders);
                          }

                          var cursor = 1;

                          if (showBanner) {
                            if (index == cursor) {
                              return _inlineBannerSlot(context);
                            }
                            cursor++;
                          }

                          if (widget.adminMode && index == cursor) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      ChoiceChip(
                                        label: const Text('كل الحالات'),
                                        selected: _adminStatusFilter == 'all',
                                        onSelected: (_) => setState(
                                            () => _adminStatusFilter = 'all'),
                                      ),
                                      ChoiceChip(
                                        label: const Text('قيد المراجعة'),
                                        selected:
                                            _adminStatusFilter == 'pending',
                                        onSelected: (_) => setState(() =>
                                            _adminStatusFilter = 'pending'),
                                      ),
                                      ChoiceChip(
                                        label: const Text('تم التسليم'),
                                        selected:
                                            _adminStatusFilter == 'delivered',
                                        onSelected: (_) => setState(() =>
                                            _adminStatusFilter = 'delivered'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final r in _OrdersRange.values)
                                        ChoiceChip(
                                          label: Text(rangeLabel(r)),
                                          selected: _adminRange == r,
                                          onSelected: (_) =>
                                              setState(() => _adminRange = r),
                                        ),
                                      FilterChip(
                                        label:
                                            const Text('طلبات المندوبات فقط'),
                                        selected: _adminOnlyAmbassador,
                                        onSelected: (v) => setState(
                                            () => _adminOnlyAmbassador = v),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }

                          if (widget.adminMode) {
                            cursor++;
                          }

                          final o = visibleOrders[index - cursor];
                          return _buildOrderCard(context, o);
                        },
                      ),
                    ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _PriceLine(
      {required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.w900)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

enum _OrdersRange {
  today,
  week,
  month,
  all,
}
