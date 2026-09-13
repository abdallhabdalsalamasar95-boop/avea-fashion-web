import 'dart:convert';

import 'package:flutter/material.dart';

import 'admin_api.dart';
import 'admin_models.dart';
import 'product_editor.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});
  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  late Future<DashboardSummary> _future = AdminApi.instance.dashboardSummary();
  void _refresh() =>
      setState(() => _future = AdminApi.instance.dashboardSummary());
  @override
  Widget build(BuildContext context) => FutureBuilder<DashboardSummary>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting)
        return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError)
        return ErrorView(error: snapshot.error, onRetry: _refresh);
      final data = snapshot.data!;
      final cards = [
        (
          'المنتجات',
          asInt(data.products['total']),
          Icons.inventory_2_outlined,
          Colors.deepOrange,
        ),
        (
          'المخزون المنخفض',
          asInt(data.products['lowStock']),
          Icons.warning_amber_rounded,
          Colors.amber.shade800,
        ),
        (
          'الطلبات',
          asInt(data.orders['total']),
          Icons.receipt_long_outlined,
          Colors.blue,
        ),
        (
          'طلبات اليوم',
          asInt(data.orders['today']),
          Icons.today_outlined,
          Colors.indigo,
        ),
        (
          'المندوبات',
          asInt(data.users['ambassadors']),
          Icons.groups_2_outlined,
          Colors.purple,
        ),
        (
          'الأجهزة',
          asInt(data.devices['total']),
          Icons.devices_outlined,
          Colors.green,
        ),
      ];
      return RefreshIndicator(
        onRefresh: () async {
          _refresh();
          await _future;
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2C1D17), Color(0xFF7B4D32)],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Color(0xFFE8BD82),
                    size: 36,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'مركز تحكم CARMEN KARLA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'بيانات متجرك الحقيقية مباشرة من الخادم',
                    style: TextStyle(color: Color(0xFFE7DAD2)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.35,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final item = cards[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(item.$3, color: item.$4),
                        Text(
                          '${item.$2}',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          item.$1,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حالة الطلبات',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final status in const [
                      ('pending', 'قيد المراجعة'),
                      ('processing', 'قيد التجهيز'),
                      ('shipped', 'تم الشحن'),
                      ('delivered', 'تم التوصيل'),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Expanded(child: Text(status.$2)),
                            CircleAvatar(
                              radius: 16,
                              child: Text(
                                '${asInt(data.orders[status.$1])}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<AdminProduct> _items = [];
  bool _loading = true;
  Object? _error;
  String _query = '';

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
      final items = await AdminApi.instance.products();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([AdminProduct? product]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductEditorScreen(product: product)),
    );
    if (changed == true) _load();
  }

  Future<void> _delete(AdminProduct product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text('حذف «${product.name}» نهائياً؟'),
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
      await AdminApi.instance.deleteProduct(product.id);
      await _load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items
        .where(
          (item) => '${item.name} ${item.productCode} ${item.category}'
              .toLowerCase()
              .contains(_query.toLowerCase()),
        )
        .toList();
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorView(error: _error, onRetry: _load);
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                children: [
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'بحث بالاسم أو الكود أو التصنيف',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${filtered.length} منتج',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _edit,
                        icon: const Icon(Icons.add),
                        label: const Text('منتج جديد'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (filtered.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('لا توجد منتجات مطابقة')),
            )
          else
            SliverList.separated(
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final product = filtered[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: InkWell(
                    onTap: () => _edit(product),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: 76,
                              height: 88,
                              child: product.imageUrls.isEmpty
                                  ? ColoredBox(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHigh,
                                      child: const Icon(
                                        Icons.image_not_supported_outlined,
                                      ),
                                    )
                                  : Image.network(
                                      product.imageUrls.first,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.broken_image_outlined,
                                              ),
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
                                        product.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    if (product.isHidden)
                                      const Chip(
                                        label: Text('مخفي'),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${product.price.toStringAsFixed(2)} د.ل • ${product.category}',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Wrap(
                                  spacing: 6,
                                  children: [
                                    Chip(
                                      avatar: const Icon(
                                        Icons.inventory_outlined,
                                        size: 15,
                                      ),
                                      label: Text(
                                        '${product.availableStock} قطعة',
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    if (product.productCode.isNotEmpty)
                                      Chip(
                                        label: Text(product.productCode),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (action) async {
                              if (action == 'edit') _edit(product);
                              if (action == 'hide') {
                                await AdminApi.instance.setProductHidden(
                                  product,
                                  !product.isHidden,
                                );
                                _load();
                              }
                              if (action == 'delete') _delete(product);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('تعديل'),
                              ),
                              PopupMenuItem(
                                value: 'hide',
                                child: Text(
                                  product.isHidden ? 'إظهار' : 'إخفاء',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('حذف'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<AdminOrder> _orders = [];
  bool _loading = true;
  Object? _error;
  String _filter = '';
  static const statuses = {
    'pending': 'قيد المراجعة',
    'confirmed': 'مؤكد',
    'processing': 'قيد التجهيز',
    'shipped': 'تم الشحن',
    'delivered': 'تم التوصيل',
    'canceled': 'ملغي',
  };
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
      final items = await AdminApi.instance.orders(status: _filter);
      if (mounted) setState(() => _orders = items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _status(AdminOrder order) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final status in statuses.entries)
              ListTile(
                title: Text(status.value),
                trailing: order.status == status.key
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, status.key),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == order.status) return;
    try {
      await AdminApi.instance.updateOrderStatus(order.orderId, picked);
      _load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorView(error: _error, onRetry: _load);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('الكل'),
                  selected: _filter.isEmpty,
                  onSelected: (_) {
                    setState(() => _filter = '');
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                for (final status in statuses.entries)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilterChip(
                      label: Text(status.value),
                      selected: _filter == status.key,
                      onSelected: (_) {
                        setState(() => _filter = status.key);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_orders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: Text('لا توجد طلبات')),
            ),
          for (final order in _orders)
            _OrderCard(
              order: order,
              statusLabel: statuses[order.status] ?? order.status,
              onStatus: () => _status(order),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.statusLabel,
    required this.onStatus,
  });
  final AdminOrder order;
  final String statusLabel;
  final VoidCallback onStatus;
  @override
  Widget build(BuildContext context) {
    final customer = order.payload['customer'] is Map
        ? Map<String, dynamic>.from(order.payload['customer'] as Map)
        : <String, dynamic>{};
    final pricing = order.payload['pricing'] is Map
        ? Map<String, dynamic>.from(order.payload['pricing'] as Map)
        : <String, dynamic>{};
    final name = order.customerName.isNotEmpty
        ? order.customerName
        : '${customer['name'] ?? 'عميل'}';
    final total = order.grandTotal > 0
        ? order.grandTotal
        : asDouble(pricing['grandTotal'] ?? order.payload['total']);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Icon(
                    order.isAmbassador
                        ? Icons.campaign_outlined
                        : Icons.person_outline,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلب #${order.orderId}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(name),
                    ],
                  ),
                ),
                Chip(
                  label: Text(statusLabel),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _TinyStat(
                    label: 'الإجمالي',
                    value: '${total.toStringAsFixed(2)} د.ل',
                  ),
                ),
                Expanded(
                  child: _TinyStat(
                    label: 'العناصر',
                    value: '${order.itemsCount}',
                  ),
                ),
                if (order.isAmbassador)
                  const Expanded(
                    child: _TinyStat(label: 'النوع', value: 'مندوبة'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onStatus,
              icon: const Icon(Icons.sync_alt),
              label: const Text('تغيير الحالة'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AmbassadorsScreen extends StatefulWidget {
  const AmbassadorsScreen({super.key});
  @override
  State<AmbassadorsScreen> createState() => _AmbassadorsScreenState();
}

class _AmbassadorsScreenState extends State<AmbassadorsScreen> {
  late Future<List<AdminOrder>> _future = AdminApi.instance.orders();
  void _refresh() => setState(() => _future = AdminApi.instance.orders());
  @override
  Widget build(BuildContext context) => FutureBuilder<List<AdminOrder>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting)
        return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError)
        return ErrorView(error: snapshot.error, onRetry: _refresh);
      final grouped = <String, List<AdminOrder>>{};
      for (final order in snapshot.data!.where((order) => order.isAmbassador)) {
        final customer = order.payload['customer'] is Map
            ? Map<String, dynamic>.from(order.payload['customer'] as Map)
            : <String, dynamic>{};
        final key =
            '${customer['submitterUid'] ?? customer['submitterEmail'] ?? customer['phone'] ?? 'unknown'}';
        grouped.putIfAbsent(key, () => []).add(order);
      }
      return RefreshIndicator(
        onRefresh: () async {
          _refresh();
          await _future;
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${grouped.length} مندوبة نشطة',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            if (grouped.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('لا توجد طلبات مندوبات بعد')),
              ),
            for (final entry in grouped.entries)
              Builder(
                builder: (context) {
                  final first = entry.value.first;
                  final customer = first.payload['customer'] is Map
                      ? Map<String, dynamic>.from(
                          first.payload['customer'] as Map,
                        )
                      : <String, dynamic>{};
                  final total = entry.value.fold<double>(
                    0,
                    (sum, order) =>
                        sum +
                        asDouble(
                          order.payload['pricing'] is Map
                              ? (order.payload['pricing'] as Map)['grandTotal']
                              : order.payload['total'],
                        ),
                  );
                  final commission = entry.value.fold<double>(
                    0,
                    (sum, order) =>
                        sum +
                        asDouble(
                          order.ambassadorSummary['estimatedCommission'],
                        ),
                  );
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      leading: const CircleAvatar(
                        child: Icon(Icons.campaign_outlined),
                      ),
                      title: Text(
                        '${customer['name'] ?? customer['submitterEmail'] ?? 'مندوبة'}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${entry.value.length} طلب • مبيعات ${total.toStringAsFixed(2)} د.ل\nعمولة تقديرية ${commission.toStringAsFixed(2)} د.ل',
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
          ],
        ),
      );
    },
  );
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _image = TextEditingController();
  bool _sending = false;
  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _image.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('العنوان والنص مطلوبان')));
      return;
    }
    setState(() => _sending = true);
    try {
      final sent = await AdminApi.instance.sendNotification(
        title: _title.text.trim(),
        body: _body.text.trim(),
        imageUrl: _image.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم الإرسال إلى $sent جهاز')));
        _title.clear();
        _body.clear();
        _image.clear();
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.notifications_active_outlined, size: 44),
              const SizedBox(height: 12),
              Text(
                'إشعار لجميع الزبائن',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'عنوان الإشعار',
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _body,
                minLines: 4,
                maxLines: 7,
                decoration: const InputDecoration(
                  labelText: 'نص الرسالة',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.message_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _image,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'رابط صورة (اختياري)',
                  prefixIcon: Icon(Icons.image_outlined),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_sending ? 'جارٍ الإرسال...' : 'إرسال الإشعار'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});
  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  late Future<Map<String, dynamic>> _future = AdminApi.instance.deviceStats();
  void _refresh() => setState(() => _future = AdminApi.instance.deviceStats());
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting)
        return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError)
        return ErrorView(error: snapshot.error, onRetry: _refresh);
      final data = snapshot.data!;
      final items = data['items'] is List ? data['items'] as List : const [];
      return RefreshIndicator(
        onRefresh: () async {
          _refresh();
          await _future;
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    title: 'كل الأجهزة',
                    value: '${asInt(data['totalDevices'] ?? data['total'])}',
                    icon: Icons.devices,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    title: 'نشطة',
                    value: '${asInt(data['activeDevices'] ?? data['active'])}',
                    icon: Icons.online_prediction,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'سجل الأجهزة',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: Text('لا توجد بيانات أجهزة')),
                ),
              ),
            for (final raw in items.whereType<Map>())
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.smartphone)),
                  title: Text(
                    '${raw['platform'] ?? raw['model'] ?? 'جهاز'}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${raw['appVersion'] ?? ''} • ${raw['city'] ?? raw['country'] ?? ''}',
                  ),
                  trailing: Text(
                    '${raw['lastSeenAt'] ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class MarketingScreen extends StatefulWidget {
  const MarketingScreen({super.key});
  @override
  State<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends State<MarketingScreen> {
  final _controller = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  Object? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await AdminApi.instance.marketingConfig();
      _controller.text = const JsonEncoder.withIndent(
        '  ',
      ).convert(config['config'] ?? config);
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    try {
      setState(() => _saving = true);
      final decoded = jsonDecode(_controller.text);
      if (decoded is! Map)
        throw const FormatException('يجب أن تكون الإعدادات كائناً');
      await AdminApi.instance.saveMarketingConfig(
        Map<String, dynamic>.from(decoded),
      );
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ إعدادات الحملات')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر الحفظ: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorView(error: _error, onRetry: _load);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'إعدادات العروض والحملات',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text('محرر الإعدادات المتقدمة المتصلة مباشرة بالخادم.'),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  minLines: 18,
                  maxLines: 30,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'Marketing JSON',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الإعدادات'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});
  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _url = TextEditingController(text: AdminApi.instance.baseUrl);
  final _token = TextEditingController(text: AdminApi.instance.token);
  bool _checking = false;
  bool? _healthy;
  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    AdminApi.instance.baseUrl = _url.text.trim();
    AdminApi.instance.token = _token.text.trim();
    setState(() {
      _checking = true;
      _healthy = null;
    });
    try {
      final ok = await AdminApi.instance.health();
      await AdminApi.instance.dashboardSummary();
      if (mounted) setState(() => _healthy = ok);
    } catch (_) {
      if (mounted) setState(() => _healthy = false);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.cloud_sync_outlined, size: 50),
              const SizedBox(height: 12),
              Text(
                'اتصال API الأصلي',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'لا يتم تحميل أي موقع. التطبيق يتصل بواجهات JSON الآمنة مباشرة.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _url,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'عنوان الخادم',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _token,
                textDirection: TextDirection.ltr,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'رمز الإدارة',
                  prefixIcon: Icon(Icons.key),
                ),
              ),
              const SizedBox(height: 16),
              if (_healthy != null)
                ListTile(
                  tileColor: _healthy!
                      ? Colors.green.withValues(alpha: .1)
                      : Colors.red.withValues(alpha: .1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Icon(
                    _healthy! ? Icons.check_circle : Icons.error,
                    color: _healthy! ? Colors.green : Colors.red,
                  ),
                  title: Text(
                    _healthy!
                        ? 'الاتصال سليم وموثّق'
                        : 'فشل الاتصال أو التوثيق',
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _checking ? null : _check,
                icon: _checking
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.health_and_safety_outlined),
                label: const Text('فحص الاتصال'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 55,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 14),
          Text(
            'تعذر تحميل البيانات',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    ),
  );
}

class _TinyStat extends StatelessWidget {
  const _TinyStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 3),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });
  final String title;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(title),
        ],
      ),
    ),
  );
}
