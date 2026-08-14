import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'admin_analytics.dart';
import 'admin_api.dart';
import 'admin_models.dart';

const orderStatuses = {
  'pending': 'قيد المراجعة',
  'processing': 'قيد التجهيز',
  'shipped': 'تم الشحن',
  'delivered': 'تم التوصيل',
  'canceled': 'ملغي',
  'returning': 'الشحنة راجعة',
  'returned': 'تم إرجاع الشحنة',
};

class ProfessionalOrdersScreen extends StatefulWidget {
  const ProfessionalOrdersScreen({super.key});
  @override
  State<ProfessionalOrdersScreen> createState() =>
      _ProfessionalOrdersScreenState();
}

class _ProfessionalOrdersScreenState extends State<ProfessionalOrdersScreen> {
  List<AdminOrder> _orders = [];
  bool _loading = true;
  Object? _error;
  String _status = '';
  String _source = 'all';
  String _query = '';
  Map<String, dynamic> _deliveryConfig = {};
  final Set<String> _sendingToDelivery = {};
  Timer? _refreshTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        AdminApi.instance.orders(status: _status),
        AdminApi.instance.darbSabeelStatus(),
      ]);
      if (mounted) {
        setState(() {
          _orders = results[0] as List<AdminOrder>;
          _deliveryConfig = results[1] as Map<String, dynamic>;
        });
      }
    } catch (error) {
      if (mounted && !silent) setState(() => _error = error);
    } finally {
      _refreshing = false;
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _changeStatus(AdminOrder order) async {
    final availableStatuses = switch (order.status) {
      'delivered' => const {'delivered', 'returning'},
      'returning' => const {'returning', 'returned', 'delivered'},
      'returned' => const {'returned'},
      _ => orderStatuses.keys.toSet(),
    };
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: orderStatuses.entries
              .where((entry) => availableStatuses.contains(entry.key))
              .map(
                (entry) => ListTile(
                  leading: Icon(
                    entry.key == order.status
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                  ),
                  title: Text(entry.value),
                  onTap: () => Navigator.pop(context, entry.key),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected == null || selected == order.status) return;
    if (!mounted) return;
    if (selected == 'returning' || selected == 'returned') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(
            selected == 'returned'
                ? Icons.inventory_2_outlined
                : Icons.assignment_return_outlined,
          ),
          title: Text(
            selected == 'returned'
                ? 'تأكيد استلام المرتجع؟'
                : 'بدء إرجاع الطلب؟',
          ),
          content: Text(
            selected == 'returned'
                ? 'سيُعاد نفس المقاس والكمية إلى المخزون، ويُستبعد الطلب من المبيعات والأرباح وعمولة المندوبة.'
                : 'سيُعلّق احتساب البيع والعمولة، لكن القطعة لن تعود إلى المخزون حتى يتم استلامها فعليًا واختيار «تم إرجاع الشحنة».',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('تراجع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await AdminApi.instance.updateOrderStatus(order.orderId, selected);
      await _load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _sendToDarbSabeel(AdminOrder order) async {
    if (_sendingToDelivery.contains(order.orderId)) return;
    if (_deliveryConfig['ready'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'الربط غير مفعّل بعد. أضيفي بيانات حساب درب السبيل في Render أولًا.',
          ),
        ),
      );
      return;
    }
    setState(() => _sendingToDelivery.add(order.orderId));
    try {
      await AdminApi.instance.sendOrderToDarbSabeel(
        order.orderId,
        force: order.deliveryStatus == 'failed',
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء الشحنة في درب السبيل بنجاح')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر إرسال الشحنة: $error')));
        await _load();
      }
    } finally {
      if (mounted) setState(() => _sendingToDelivery.remove(order.orderId));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ProfessionalError(error: _error, retry: _load);
    final visible = _orders.where((order) {
      if (_source == 'customer' && order.isAmbassador) return false;
      if (_source == 'ambassador' && !order.isAmbassador) return false;
      final search = _query.trim().toLowerCase();
      if (search.isEmpty) return true;
      return '${order.orderId} ${order.buyerName} ${order.buyerPhone} ${order.ambassadorName} ${order.lines.map((item) => item.name).join(' ')}'
          .toLowerCase()
          .contains(search);
    }).toList();
    final customerPieces = visible
        .where((order) => !order.isAmbassador)
        .fold(0, (sum, order) => sum + order.totalPieces);
    final ambassadorPieces = visible
        .where((order) => order.isAmbassador)
        .fold(0, (sum, order) => sum + order.totalPieces);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: _deliveryConfig['ready'] == true
                ? const Color(0xFFE7F5EC)
                : const Color(0xFFFFF3D8),
            child: ListTile(
              leading: Icon(
                Icons.local_shipping_outlined,
                color: _deliveryConfig['ready'] == true
                    ? Colors.green.shade700
                    : Colors.orange.shade800,
              ),
              title: Text(
                _deliveryConfig['ready'] == true
                    ? 'درب السبيل متصل وجاهز'
                    : 'درب السبيل يحتاج تفعيل',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                _deliveryConfig['ready'] == true
                    ? 'الطلبات الجديدة تُرسل تلقائيًا ويمكن إعادة المحاولة من التفاصيل.'
                    : 'أضيفي API Key وبيانات الحساب إلى Environment في Render.',
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'بحث بالطلب أو العميل أو المنتج',
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'all',
                label: Text('الجميع'),
                icon: Icon(Icons.all_inbox_outlined),
              ),
              ButtonSegment(
                value: 'customer',
                label: Text('الزبائن'),
                icon: Icon(Icons.person_outline),
              ),
              ButtonSegment(
                value: 'ambassador',
                label: Text('المندوبات'),
                icon: Icon(Icons.campaign_outlined),
              ),
            ],
            selected: {_source},
            onSelectionChanged: (values) =>
                setState(() => _source = values.first),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('كل الحالات'),
                  selected: _status.isEmpty,
                  onSelected: (_) {
                    setState(() => _status = '');
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                for (final entry in orderStatuses.entries)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: FilterChip(
                      label: Text(entry.value),
                      selected: _status == entry.key,
                      onSelected: (_) {
                        setState(() => _status = entry.key);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  icon: Icons.person_outline,
                  title: 'قطع الزبائن',
                  value: '$customerPieces',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryTile(
                  icon: Icons.campaign_outlined,
                  title: 'قطع المندوبات',
                  value: '$ambassadorPieces',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(35),
                child: Center(child: Text('لا توجد طلبات مطابقة')),
              ),
            ),
          for (final order in visible)
            _DetailedOrderCard(
              order: order,
              onStatus: () => _changeStatus(order),
              onDelivery: () => _sendToDarbSabeel(order),
              sendingToDelivery: _sendingToDelivery.contains(order.orderId),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _DetailedOrderCard extends StatelessWidget {
  const _DetailedOrderCard({
    required this.order,
    required this.onStatus,
    required this.onDelivery,
    required this.sendingToDelivery,
  });
  final AdminOrder order;
  final VoidCallback onStatus;
  final VoidCallback onDelivery;
  final bool sendingToDelivery;

  @override
  Widget build(BuildContext context) {
    final color = order.isAmbassador
        ? Colors.purple
        : Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showOrderDetails(context, order, onStatus, onDelivery),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: .12),
                    child: Icon(
                      order.isAmbassador
                          ? Icons.campaign_outlined
                          : Icons.person_outline,
                      color: color,
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
                        Text(
                          order.isAmbassador
                              ? 'بيع بواسطة ${order.ambassadorName}'
                              : 'شراء مباشر من ${order.buyerName}',
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(orderStatuses[order.status] ?? order.status),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const Divider(height: 24),
              if (order.deliveryStatus.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      order.hasCreatedShipment
                          ? Icons.local_shipping
                          : Icons.error_outline,
                      size: 18,
                      color: order.hasCreatedShipment
                          ? Colors.green
                          : Colors.orange.shade800,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        order.hasCreatedShipment
                            ? 'شحنة درب السبيل${order.trackingNumber.isEmpty ? '' : ' • ${order.trackingNumber}'}'
                            : 'إرسال درب السبيل: ${order.deliveryStatus == 'sending' ? 'جارٍ الإرسال' : 'فشل ويحتاج إعادة محاولة'}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
              ],
              Row(
                children: [
                  Expanded(
                    child: _MiniValue(
                      label: 'القيمة',
                      value: '${order.effectiveTotal.toStringAsFixed(2)} د.ل',
                    ),
                  ),
                  Expanded(
                    child: _MiniValue(
                      label: 'عدد القطع',
                      value: '${order.totalPieces}',
                    ),
                  ),
                  Expanded(
                    child: _MiniValue(
                      label: 'التاريخ',
                      value: formatDateTime(
                        order.createdAtMs,
                      ).split(' • ').first,
                    ),
                  ),
                ],
              ),
              if (order.lines.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      for (final line in order.lines.take(3))
                        _CompactOrderLine(line: line),
                      if (order.lines.length > 3)
                        Text(
                          '+ ${order.lines.length - 3} منتجات أخرى',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showOrderDetails(
                        context,
                        order,
                        onStatus,
                        onDelivery,
                      ),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('كل التفاصيل'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: onStatus,
                      icon: const Icon(Icons.sync_alt),
                      label: const Text('تغيير الحالة'),
                    ),
                  ),
                ],
              ),
              if (!order.hasCreatedShipment) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: sendingToDelivery ? null : onDelivery,
                    icon: sendingToDelivery
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.local_shipping_outlined),
                    label: Text(
                      order.deliveryStatus == 'failed'
                          ? 'إعادة الإرسال إلى درب السبيل'
                          : 'إرسال إلى درب السبيل',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactOrderLine extends StatelessWidget {
  const _CompactOrderLine({required this.line});
  final OrderLine line;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 42,
            height: 48,
            child: line.imageUrl.isEmpty
                ? const ColoredBox(
                    color: Colors.black12,
                    child: Icon(Icons.inventory_2_outlined, size: 18),
                  )
                : Image.network(
                    line.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                '× ${line.quantity}${line.size.isEmpty ? '' : ' • ${line.size}'}${line.color.isEmpty ? '' : ' • ${line.color}'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Text(
          '${line.lineTotal.toStringAsFixed(2)} د.ل',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

Future<void> _showOrderDetails(
  BuildContext context,
  AdminOrder order,
  VoidCallback onStatus,
  VoidCallback onDelivery,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .9,
      maxChildSize: .96,
      minChildSize: .55,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
        children: [
          Text(
            'تفاصيل الطلب #${order.orderId}',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          _InfoBlock(
            title: order.isAmbassador ? 'البيع والمندوبة' : 'بيانات الزبون',
            rows: [
              (
                'نوع الطلب',
                order.isAmbassador ? 'بيع بواسطة مندوبة' : 'شراء زبون مباشر',
              ),
              ('اسم المستلم', order.buyerName),
              ('الهاتف', order.buyerPhone),
              ('البريد', order.buyerEmail),
              ('المدينة', order.buyerCity),
              ('العنوان', order.buyerAddress),
              if (order.isAmbassador) ('اسم المندوبة', order.ambassadorName),
              if (order.isAmbassador) ('هاتف المندوبة', order.ambassadorPhone),
              if (order.isAmbassador) ('بريد المندوبة', order.ambassadorEmail),
            ],
          ),
          const SizedBox(height: 12),
          _InfoBlock(
            title: 'شركة التوصيل • درب السبيل',
            rows: [
              (
                'حالة الربط',
                switch (order.deliveryStatus) {
                  'created' => 'تم إنشاء الشحنة',
                  'sending' => 'جارٍ الإرسال',
                  'failed' => 'فشل الإرسال',
                  _ => 'لم تُرسل بعد',
                },
              ),
              if (order.trackingNumber.isNotEmpty)
                ('رقم الشحنة / التتبع', order.trackingNumber),
              if (order.providerStatus.isNotEmpty)
                ('حالة درب السبيل', _providerStatusLabel(order.providerStatus)),
              if (order.deliveryError.isNotEmpty)
                ('سبب آخر فشل', order.deliveryError),
            ],
          ),
          if (order.hasCreatedShipment) ...[
            const SizedBox(height: 12),
            _AdminShipmentTimeline(order: order),
          ],
          const SizedBox(height: 12),
          _InfoBlock(
            title: 'ملخص الطلب',
            rows: [
              ('الحالة', orderStatuses[order.status] ?? order.status),
              ('إجمالي القطع', '${order.totalPieces}'),
              ('قيمة الطلب', '${order.effectiveTotal.toStringAsFixed(2)} د.ل'),
              (
                'الشحن',
                '${asDouble(order.pricing['shipping']).toStringAsFixed(2)} د.ل',
              ),
              (
                'الخصم',
                '${asDouble(order.pricing['discount']).toStringAsFixed(2)} د.ل',
              ),
              ('التاريخ', formatDateTime(order.createdAtMs)),
            ],
          ),
          const SizedBox(height: 12),
          _ReturnAccountingCard(order: order),
          const SizedBox(height: 16),
          Text(
            order.isAmbassador
                ? 'القطع المباعة بواسطة المندوبة'
                : 'القطع التي اشتراها الزبون',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (order.lines.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('تفاصيل القطع غير محفوظة في هذا الطلب القديم.'),
              ),
            ),
          for (final line in order.lines)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _CompactOrderLine(line: line),
              ),
            ),
          const SizedBox(height: 16),
          if (!order.hasCreatedShipment) ...[
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onDelivery();
              },
              icon: const Icon(Icons.local_shipping_outlined),
              label: Text(
                order.deliveryStatus == 'failed'
                    ? 'إعادة الإرسال إلى درب السبيل'
                    : 'إنشاء شحنة درب السبيل',
              ),
            ),
            const SizedBox(height: 9),
          ],
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onStatus();
            },
            icon: const Icon(Icons.sync_alt),
            label: const Text('تغيير حالة الطلب'),
          ),
        ],
      ),
    ),
  );
}

class _ReturnAccountingCard extends StatelessWidget {
  const _ReturnAccountingCard({required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final (color, icon, title, accounting, inventory) = switch (order.status) {
      'returning' => (
        Colors.orange,
        Icons.assignment_return_outlined,
        'الطلب في مسار الإرجاع',
        'الحسابات: البيع والربح وعمولة المندوبة معلّقة وغير محتسبة.',
        'المخزون: القطع لم تُضف بعد؛ بانتظار استلام المرتجع فعليًا.',
      ),
      'returned' => (
        Colors.teal,
        Icons.inventory_2_outlined,
        'تم استلام المرتجع',
        'الحسابات: الطلب مستبعد من الإيراد والربح وعمولة المندوبة.',
        'المخزون: أُعيد نفس المقاس والكمية مرة واحدة إلى الرصيد.',
      ),
      'canceled' => (
        Colors.red,
        Icons.cancel_outlined,
        'الطلب ملغي قبل اكتمال التسليم',
        'الحسابات: الطلب غير محتسب ضمن المبيعات أو الأرباح أو العمولة.',
        'المخزون: تم فك الحجز وإرجاع نفس المقاس والكمية.',
      ),
      'delivered' => (
        Colors.green,
        Icons.verified_outlined,
        'بيع مكتمل ومُسلَّم',
        'الحسابات: القيمة ضمن الإيراد والربح، وعمولة المندوبة مستحقة إن وُجدت.',
        'المخزون: القطع مباعة ولا تظهر ضمن الرصيد المتاح.',
      ),
      _ => (
        Colors.blueGrey,
        Icons.lock_clock_outlined,
        'الطلب قيد التنفيذ',
        'الحسابات: لا يُعتمد كبيع نهائي حتى يتم التوصيل.',
        order.inventoryReserved
            ? 'المخزون: الكمية محجوزة لهذا الطلب وغير متاحة للبيع.'
            : 'المخزون: لا توجد كمية محجوزة لهذا الطلب.',
      ),
    };
    return Card(
      color: color.withValues(alpha: .09),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(accounting),
            const SizedBox(height: 5),
            Text(inventory),
          ],
        ),
      ),
    );
  }
}

String _providerStatusLabel(String status) => switch (status) {
  'pending' => 'قيد الانتظار',
  'processing' => 'تحت المعالجة',
  'booked' || 'assigned' || 'accepted' => 'تحت المعالجة',
  'shipped' => 'في التوصيل',
  'completed' || 'released' || 'delivered' => 'تم التوصيل',
  'canceled' || 'cancelled' || 'returning' => 'الشحنة راجعة',
  'returned' => 'تم إرجاع الشحنة',
  'deleted' => 'تم حذف الشحنة',
  _ => status,
};

class _AdminShipmentTimeline extends StatelessWidget {
  const _AdminShipmentTimeline({required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final returning = order.status == 'returning' || order.status == 'returned';
    final stages = returning
        ? const [
            ('pending', 'انتظار'),
            ('processing', 'معالجة'),
            ('shipped', 'توصيل'),
            ('returning', 'راجعة'),
            ('returned', 'تم الإرجاع'),
          ]
        : const [
            ('pending', 'انتظار'),
            ('processing', 'معالجة'),
            ('shipped', 'توصيل'),
            ('delivered', 'تم التوصيل'),
          ];
    final current = stages.indexWhere((stage) => stage.$1 == order.status);
    final events = order.deliveryTimeline;
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route_outlined),
                const SizedBox(width: 8),
                Text(
                  'مسار الشحنة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var index = 0; index < stages.length; index++) ...[
                  Expanded(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: index <= current
                              ? returning
                                    ? Colors.orange.shade700
                                    : Colors.green.shade700
                              : Colors.grey.shade300,
                          child: Icon(
                            index <= current ? Icons.check : Icons.circle,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          stages[index].$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  if (index < stages.length - 1)
                    Expanded(
                      child: Divider(
                        color: index < current
                            ? returning
                                  ? Colors.orange.shade500
                                  : Colors.green.shade500
                            : Colors.grey.shade300,
                        thickness: 2,
                      ),
                    ),
                ],
              ],
            ),
            if (events.isNotEmpty) ...[
              const Divider(height: 28),
              for (final event in events.reversed.take(12))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${event['descriptionAr'] ?? event['descriptionEn'] ?? 'تحديث على الشحنة'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if ('${event['timestamp'] ?? ''}'.isNotEmpty)
                              Text(
                                '${event['timestamp']}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class ProfessionalAmbassadorsScreen extends StatefulWidget {
  const ProfessionalAmbassadorsScreen({super.key});
  @override
  State<ProfessionalAmbassadorsScreen> createState() =>
      _ProfessionalAmbassadorsScreenState();
}

class _ProfessionalAmbassadorsScreenState
    extends State<ProfessionalAmbassadorsScreen> {
  bool _loading = true;
  Object? _error;
  List<AmbassadorProfile> _profiles = [];
  double _sales = 0;
  double _paid = 0;
  double _pending = 0;
  int _pieces = 0;
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
      final results = await Future.wait([
        AdminApi.instance.orders(),
        AdminApi.instance.marketingConfig(),
        AdminApi.instance.deviceStats(),
        AdminApi.instance.ambassadors(),
      ]);
      final orders = results[0] as List<AdminOrder>;
      final configEnvelope = results[1] as Map<String, dynamic>;
      final config = mapValue(configEnvelope['config']);
      final commission = mapValue(config['commission']);
      final devices = results[2] as Map<String, dynamic>;
      final registered = results[3] as List<Map<String, dynamic>>;
      final recent = devices['recentItems'] is List
          ? (devices['recentItems'] as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : <Map<String, dynamic>>[];
      final profiles = buildAmbassadorProfiles(
        orders,
        defaultPercent: asDouble(commission['defaultPercent'], 7),
        perProductEnabled: commission['perProductEnabled'] != false,
        devicePresence: recent,
        registeredProfiles: registered,
      );
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _sales = profiles.fold(0, (sum, item) => sum + item.sales);
        _paid = profiles.fold(0, (sum, item) => sum + item.deliveredCommission);
        _pending = profiles.fold(
          0,
          (sum, item) => sum + item.pendingCommission,
        );
        _pieces = profiles.fold(0, (sum, item) => sum + item.pieces);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ProfessionalError(error: _error, retry: _load);
    final visible = _profiles
        .where(
          (profile) =>
              '${profile.name} ${profile.phone} ${profile.email} ${profile.uid}'
                  .toLowerCase()
                  .contains(_query.toLowerCase()),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'بحث باسم أو هاتف أو حساب المندوبة',
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.45,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _SummaryTile(
                icon: Icons.groups_2_outlined,
                title: 'المندوبات',
                value: '${_profiles.length}',
              ),
              _SummaryTile(
                icon: Icons.shopping_bag_outlined,
                title: 'القطع المباعة',
                value: '$_pieces',
              ),
              _SummaryTile(
                icon: Icons.payments_outlined,
                title: 'المبيعات',
                value: '${_sales.toStringAsFixed(2)} د.ل',
              ),
              _SummaryTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'أرباح فعلية',
                value: '${_paid.toStringAsFixed(2)} د.ل',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.pending_actions_outlined),
              title: const Text(
                'أرباح معلقة',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              trailing: Text(
                '${_pending.toStringAsFixed(2)} د.ل',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (visible.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(35),
                child: Center(child: Text('لا توجد بيانات مندوبات مطابقة')),
              ),
            ),
          for (var index = 0; index < visible.length; index++)
            _AmbassadorCard(rank: index + 1, profile: visible[index]),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _AmbassadorCard extends StatelessWidget {
  const _AmbassadorCard({required this.rank, required this.profile});
  final int rank;
  final AmbassadorProfile profile;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AmbassadorDetailsScreen(profile: profile),
        ),
      ),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '#$rank',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        profile.phone.isNotEmpty
                            ? profile.phone
                            : profile.email,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        profile.status == 'active' ? 'نشطة' : profile.status,
                      ),
                    ),
                    const Icon(Icons.chevron_left),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _MiniValue(label: 'القطع', value: '${profile.pieces}'),
                ),
                Expanded(
                  child: _MiniValue(
                    label: 'الطلبات',
                    value: '${profile.ordersCount}',
                  ),
                ),
                Expanded(
                  child: _MiniValue(
                    label: 'المبيعات',
                    value: profile.sales.toStringAsFixed(0),
                  ),
                ),
                Expanded(
                  child: _MiniValue(
                    label: 'الربح',
                    value: profile.deliveredCommission.toStringAsFixed(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (profile.deliveryRate / 100).clamp(0, 1),
            ),
            const SizedBox(height: 5),
            Text(
              'نسبة نجاح التوصيل ${profile.deliveryRate.toStringAsFixed(1)}% • ${profile.openOrders} طلب مفتوح',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class AmbassadorDetailsScreen extends StatelessWidget {
  const AmbassadorDetailsScreen({super.key, required this.profile});
  final AmbassadorProfile profile;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ملف المندوبة')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 34,
                  child: Icon(Icons.campaign_outlined, size: 34),
                ),
                const SizedBox(height: 10),
                Text(
                  profile.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                if (profile.phone.isNotEmpty) Text(profile.phone),
                if (profile.email.isNotEmpty) Text(profile.email),
                if (profile.address.isNotEmpty)
                  Text(profile.address, textAlign: TextAlign.center),
                if (profile.uid.isNotEmpty)
                  SelectableText(
                    'UID: ${profile.uid}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                Text(
                  'حالة الحساب: ${profile.status == 'active' ? 'نشطة' : profile.status}',
                ),
                if (profile.joinedAtMs > 0)
                  Text('تاريخ الانضمام: ${formatDateTime(profile.joinedAtMs)}'),
                const SizedBox(height: 8),
                Text('آخر طلب: ${formatDateTime(profile.lastOrderMs)}'),
                if (profile.lastSeenMs > 0)
                  Text(
                    'آخر ظهور بالتطبيق: ${formatDateTime(profile.lastSeenMs)}',
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.45,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _SummaryTile(
              icon: Icons.shopping_bag_outlined,
              title: 'القطع المباعة',
              value: '${profile.pieces}',
            ),
            _SummaryTile(
              icon: Icons.payments_outlined,
              title: 'المبيعات',
              value: '${profile.sales.toStringAsFixed(2)} د.ل',
            ),
            _SummaryTile(
              icon: Icons.verified_outlined,
              title: 'أرباح فعلية',
              value: '${profile.deliveredCommission.toStringAsFixed(2)} د.ل',
            ),
            _SummaryTile(
              icon: Icons.pending_outlined,
              title: 'أرباح معلقة',
              value: '${profile.pendingCommission.toStringAsFixed(2)} د.ل',
            ),
            _SummaryTile(
              icon: Icons.done_all,
              title: 'طلبات موصلة',
              value: '${profile.deliveredOrders}',
            ),
            _SummaryTile(
              icon: Icons.calculate_outlined,
              title: 'متوسط الطلب',
              value: '${profile.averageOrder.toStringAsFixed(2)} د.ل',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'طلبات ومبيعات هذه المندوبة',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        for (final order in profile.orders)
          Card(
            child: ExpansionTile(
              leading: order.lines.isEmpty || order.lines.first.imageUrl.isEmpty
                  ? const CircleAvatar(child: Icon(Icons.receipt_long_outlined))
                  : CircleAvatar(
                      backgroundImage: NetworkImage(order.lines.first.imageUrl),
                    ),
              title: Text(
                'طلب #${order.orderId}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                '${order.totalPieces} قطعة • ${order.effectiveTotal.toStringAsFixed(2)} د.ل • ${orderStatuses[order.status] ?? order.status}',
              ),
              trailing: Text(
                '${{'canceled', 'returning', 'returned'}.contains(order.status) ? '0.00' : order.commission(defaultPercent: profile.defaultPercent, perProductEnabled: profile.perProductEnabled).toStringAsFixed(2)} د.ل',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              children: [
                for (final line in order.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: _CompactOrderLine(line: line),
                  ),
                ListTile(
                  title: Text('الزبون: ${order.buyerName}'),
                  subtitle: Text(
                    '${order.buyerPhone}${order.buyerCity.isEmpty ? '' : ' • ${order.buyerCity}'}',
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 30),
      ],
    ),
  );
}

class ProfessionalWithdrawalsScreen extends StatefulWidget {
  const ProfessionalWithdrawalsScreen({super.key});

  @override
  State<ProfessionalWithdrawalsScreen> createState() =>
      _ProfessionalWithdrawalsScreenState();
}

class _ProfessionalWithdrawalsScreenState
    extends State<ProfessionalWithdrawalsScreen> {
  List<AmbassadorWithdrawalRequest> _requests = [];
  bool _loading = true;
  Object? _error;
  String _filter = 'all';
  String? _updatingId;

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
      final requests = await AdminApi.instance.ambassadorWithdrawals();
      requests.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
      if (mounted) setState(() => _requests = requests);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeStatus(
    AmbassadorWithdrawalRequest request,
    String nextStatus,
  ) async {
    final action = withdrawalStatusLabels[nextStatus] ?? nextStatus;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          nextStatus == 'rejected'
              ? Icons.cancel_outlined
              : nextStatus == 'paid'
              ? Icons.verified_outlined
              : Icons.check_circle_outline,
        ),
        title: Text('$action؟'),
        content: Text(
          'هل تريدين اعتماد حالة «$action» لطلب ${request.ambassadorName.isEmpty ? 'المندوبة' : request.ambassadorName} بمبلغ ${request.amount.toStringAsFixed(2)} د.ل؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _updatingId = request.id);
    try {
      await AdminApi.instance.updateWithdrawalStatus(request.id, nextStatus);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم تحديث الطلب إلى: $action')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر تحديث الطلب: $error')));
      }
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  double _totalFor(String status) => _requests
      .where((request) => request.status == status)
      .fold(0, (sum, request) => sum + request.amount);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ProfessionalError(error: _error, retry: _load);
    final visible = _filter == 'all'
        ? _requests
        : _requests.where((request) => request.status == _filter).toList();
    final pendingCount = _requests
        .where((request) => request.status == 'pending')
        .length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.security_rounded),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'راجعي بيانات المندوبة والمبلغ قبل القبول. اختاري «تم الدفع» فقط بعد تحويل المبلغ فعليًا.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _SummaryTile(
                icon: Icons.pending_actions_rounded,
                title: 'بانتظار المراجعة ($pendingCount)',
                value: '${_totalFor('pending').toStringAsFixed(2)} د.ل',
              ),
              _SummaryTile(
                icon: Icons.task_alt_rounded,
                title: 'مقبولة',
                value: '${_totalFor('approved').toStringAsFixed(2)} د.ل',
              ),
              _SummaryTile(
                icon: Icons.payments_rounded,
                title: 'مدفوعة',
                value: '${_totalFor('paid').toStringAsFixed(2)} د.ل',
              ),
              _SummaryTile(
                icon: Icons.receipt_long_rounded,
                title: 'إجمالي الطلبات',
                value: '${_requests.length}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in const {
                  'all': 'الكل',
                  'pending': 'قيد المراجعة',
                  'approved': 'تم القبول',
                  'paid': 'تم الدفع',
                  'rejected': 'مرفوض',
                }.entries)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: FilterChip(
                      label: Text(entry.value),
                      selected: _filter == entry.key,
                      onSelected: (_) => setState(() => _filter = entry.key),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (visible.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(35),
                child: Center(child: Text('لا توجد طلبات سحب ضمن هذه الحالة')),
              ),
            ),
          for (final request in visible)
            _WithdrawalRequestCard(
              request: request,
              updating: _updatingId == request.id,
              onStatus: (status) => _changeStatus(request, status),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _WithdrawalRequestCard extends StatelessWidget {
  const _WithdrawalRequestCard({
    required this.request,
    required this.updating,
    required this.onStatus,
  });

  final AmbassadorWithdrawalRequest request;
  final bool updating;
  final ValueChanged<String> onStatus;

  Color _statusColor() => switch (request.status) {
    'approved' => Colors.blue,
    'paid' => Colors.green,
    'rejected' => Colors.red,
    _ => Colors.orange,
  };

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    final name = request.ambassadorName.trim().isEmpty
        ? 'مندوبة غير معروفة'
        : request.ambassadorName;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: .12),
                  child: Icon(Icons.person_outline_rounded, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      if (request.ambassadorPhone.isNotEmpty)
                        Text(request.ambassadorPhone),
                    ],
                  ),
                ),
                Chip(
                  avatar: Icon(Icons.circle, size: 10, color: color),
                  label: Text(request.statusLabel),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const Divider(height: 26),
            Row(
              children: [
                Expanded(
                  child: _MiniValue(
                    label: 'المبلغ المطلوب',
                    value: '${request.amount.toStringAsFixed(2)} د.ل',
                  ),
                ),
                Expanded(
                  child: _MiniValue(
                    label: 'تاريخ الطلب',
                    value: formatDateTime(
                      request.createdAtMs,
                    ).split(' • ').first,
                  ),
                ),
              ],
            ),
            if (request.allowedNextStatuses.isNotEmpty) ...[
              const SizedBox(height: 14),
              if (updating)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  children: [
                    if (request.allowedNextStatuses.contains('approved'))
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => onStatus('approved'),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('قبول'),
                        ),
                      ),
                    if (request.allowedNextStatuses.contains('paid'))
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => onStatus('paid'),
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('تم الدفع'),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onStatus('rejected'),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('رفض'),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class ProfessionalDevicesScreen extends StatefulWidget {
  const ProfessionalDevicesScreen({super.key});
  @override
  State<ProfessionalDevicesScreen> createState() =>
      _ProfessionalDevicesScreenState();
}

class _ProfessionalDevicesScreenState extends State<ProfessionalDevicesScreen> {
  late Future<Map<String, dynamic>> _future = AdminApi.instance.deviceStats();
  String _filter = 'all';
  void _reload() => setState(() => _future = AdminApi.instance.deviceStats());
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting)
        return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError)
        return _ProfessionalError(error: snapshot.error, retry: _reload);
      final data = snapshot.data!;
      final records = data['recentItems'] is List
          ? (data['recentItems'] as List)
                .whereType<Map>()
                .map(
                  (item) => DeviceRecord(raw: Map<String, dynamic>.from(item)),
                )
                .where((device) {
                  if (_filter == 'ambassador') return device.isAmbassador;
                  if (_filter == 'customer') return !device.isAmbassador;
                  return true;
                })
                .toList()
          : <DeviceRecord>[];
      return RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _future;
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.45,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _SummaryTile(
                  icon: Icons.install_mobile_outlined,
                  title: 'كل التثبيتات',
                  value: '${asInt(data['totalInstalled'])}',
                ),
                _SummaryTile(
                  icon: Icons.today_outlined,
                  title: 'نشطة اليوم',
                  value: '${asInt(data['active1d'])}',
                ),
                _SummaryTile(
                  icon: Icons.date_range_outlined,
                  title: 'نشطة 7 أيام',
                  value: '${asInt(data['active7d'])}',
                ),
                _SummaryTile(
                  icon: Icons.devices_outlined,
                  title: 'نشطة 30 يوم',
                  value: '${asInt(data['active30d'])}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('الجميع')),
                ButtonSegment(value: 'customer', label: Text('زبائن')),
                ButtonSegment(value: 'ambassador', label: Text('مندوبات')),
              ],
              selected: {_filter},
              onSelectionChanged: (values) =>
                  setState(() => _filter = values.first),
            ),
            const SizedBox(height: 14),
            Text(
              '${records.length} جهاز بالتفاصيل',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (records.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: Text('لا توجد أجهزة ضمن هذا الفلتر')),
                ),
              ),
            for (final device in records) _DeviceCard(device: device),
            const SizedBox(height: 80),
          ],
        ),
      );
    },
  );
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device});
  final DeviceRecord device;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      onTap: () => _showDevice(context, device),
      contentPadding: const EdgeInsets.all(14),
      leading: CircleAvatar(
        child: Icon(
          device.platform.toLowerCase() == 'ios'
              ? Icons.phone_iphone
              : Icons.android,
        ),
      ),
      title: Text(
        '${device.brand} ${device.model}'.trim().isEmpty
            ? 'جهاز غير معروف'
            : '${device.brand} ${device.model}'.trim(),
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        '${device.platform} ${device.os} • تطبيق ${device.app} (${device.build})\n${device.isAmbassador
            ? 'حساب مندوبة: ${device.ambassadorName}'
            : device.uid.isEmpty
            ? 'زائر بدون حساب'
            : 'حساب زبون'} • ${formatDateTime(device.lastSeenMs)}',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_left),
    ),
  );
}

Future<void> _showDevice(BuildContext context, DeviceRecord device) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تفاصيل الجهاز والحساب',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            _InfoBlock(
              title: 'الجهاز',
              rows: [
                ('المعرّف', device.id),
                ('المنصة', device.platform),
                ('النوع', device.type),
                ('الشركة', device.brand),
                ('الموديل', device.model),
                ('النظام', device.os),
                ('اللغة', device.locale),
              ],
            ),
            const SizedBox(height: 12),
            _InfoBlock(
              title: 'التطبيق والنشاط',
              rows: [
                ('إصدار التطبيق', device.app),
                ('رقم البناء', device.build),
                ('أول ظهور', formatDateTime(device.firstSeenMs)),
                ('آخر ظهور', formatDateTime(device.lastSeenMs)),
                ('عدد مرات الظهور', '${device.seenCount}'),
                ('آخر حدث', device.event),
                ('آخر IP', device.ip),
              ],
            ),
            const SizedBox(height: 12),
            _InfoBlock(
              title: 'الحساب المرتبط',
              rows: [
                ('UID', device.uid),
                (
                  'نوع الحساب',
                  device.isAmbassador
                      ? 'مندوبة'
                      : device.uid.isEmpty
                      ? 'زائر'
                      : 'زبون',
                ),
                if (device.isAmbassador)
                  ('اسم المندوبة', device.ambassadorName),
                if (device.isAmbassador)
                  ('هاتف المندوبة', device.ambassadorPhone),
                if (device.isAmbassador)
                  ('عنوان المندوبة', device.ambassadorAddress),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class ProfessionalMarketingScreen extends StatefulWidget {
  const ProfessionalMarketingScreen({super.key});
  @override
  State<ProfessionalMarketingScreen> createState() =>
      _ProfessionalMarketingScreenState();
}

class _ProfessionalMarketingScreenState
    extends State<ProfessionalMarketingScreen> {
  bool _loading = true;
  bool _saving = false;
  Object? _error;
  Map<String, dynamic> _config = {};
  List<AdminProduct> _products = [];
  final _commission = TextEditingController();
  final _offerTitle = TextEditingController();
  final _offerSubtitle = TextEditingController();
  final _offerCta = TextEditingController();
  final _bannerAlt = TextEditingController();
  final _bannerLink = TextEditingController();
  final _announcementText = TextEditingController();
  final _sectionBannerAlt = TextEditingController();
  final _sectionBannerLink = TextEditingController();
  final _ambassadorWhatsapp = TextEditingController();
  bool _perProduct = true;
  bool _bannerEnabled = true;
  bool _uploadingBanner = false;
  bool _announcementEnabled = true;
  int _announcementSpeed = 18;
  String _announcementStyle = 'rose';
  bool _sectionBannerEnabled = true;
  bool _uploadingSectionBanner = false;
  bool _ambassadorSupportEnabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commission.dispose();
    _offerTitle.dispose();
    _offerSubtitle.dispose();
    _offerCta.dispose();
    _bannerAlt.dispose();
    _bannerLink.dispose();
    _announcementText.dispose();
    _sectionBannerAlt.dispose();
    _sectionBannerLink.dispose();
    _ambassadorWhatsapp.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _list(String key) {
    final value = _config[key];
    return value is List
        ? value
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : [];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        AdminApi.instance.marketingConfig(),
        AdminApi.instance.products(),
      ]);
      final envelope = results[0] as Map<String, dynamic>;
      final config = mapValue(envelope['config']);
      final commission = mapValue(config['commission']);
      final offers = mapValue(config['offers']);
      final websiteHome = mapValue(config['websiteHome']);
      final announcement = mapValue(websiteHome['announcement']);
      final banner = mapValue(websiteHome['banner']);
      final sectionBanner = mapValue(websiteHome['sectionBanner']);
      final ambassadorSupport = mapValue(config['ambassadorSupport']);
      _commission.text = '${asDouble(commission['defaultPercent'], 7)}';
      _perProduct = commission['perProductEnabled'] != false;
      _offerTitle.text = textValue(offers['title']);
      _offerSubtitle.text = textValue(offers['subtitle']);
      _offerCta.text = textValue(offers['ctaLabel']);
      _bannerAlt.text = textValue(banner['altText']).isEmpty
          ? 'بانر أڤيا فاشن'
          : textValue(banner['altText']);
      _bannerLink.text = textValue(banner['linkUrl']).isEmpty
          ? '#collection'
          : textValue(banner['linkUrl']);
      _bannerEnabled = banner['enabled'] != false;
      _announcementText.text = textValue(announcement['text']).isEmpty
          ? 'شحن لجميع المدن الليبية • الدفع عند الاستلام'
          : textValue(announcement['text']);
      _announcementEnabled = announcement['enabled'] != false;
      _announcementSpeed = asInt(announcement['speedSeconds'], 18).clamp(6, 60);
      _announcementStyle =
          const {
            'dark',
            'rose',
            'gold',
          }.contains(textValue(announcement['style']))
          ? textValue(announcement['style'])
          : 'rose';
      _sectionBannerAlt.text = textValue(sectionBanner['altText']).isEmpty
          ? 'بانر أحدث المنتجات والأكثر مبيعًا'
          : textValue(sectionBanner['altText']);
      _sectionBannerLink.text = textValue(sectionBanner['linkUrl']).isEmpty
          ? '#collection'
          : textValue(sectionBanner['linkUrl']);
      _sectionBannerEnabled = sectionBanner['enabled'] != false;
      _ambassadorWhatsapp.text = textValue(ambassadorSupport['whatsappNumber']);
      _ambassadorSupportEnabled = ambassadorSupport['enabled'] == true;
      if (mounted)
        setState(() {
          _config = config;
          _products = results[1] as List<AdminProduct>;
        });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      _config['commission'] = {
        'defaultPercent': (double.tryParse(_commission.text) ?? 7).clamp(
          0,
          100,
        ),
        'perProductEnabled': _perProduct,
      };
      final offers = mapValue(_config['offers']);
      offers['title'] = _offerTitle.text.trim();
      offers['subtitle'] = _offerSubtitle.text.trim();
      offers['ctaLabel'] = _offerCta.text.trim();
      _config['offers'] = offers;
      final websiteHome = mapValue(_config['websiteHome']);
      websiteHome['announcement'] = {
        'text': _announcementText.text.trim(),
        'enabled': _announcementEnabled,
        'speedSeconds': _announcementSpeed,
        'style': _announcementStyle,
      };
      final banner = mapValue(websiteHome['banner']);
      banner['altText'] = _bannerAlt.text.trim();
      banner['linkUrl'] = _bannerLink.text.trim();
      banner['enabled'] = _bannerEnabled;
      websiteHome['banner'] = banner;
      final sectionBanner = mapValue(websiteHome['sectionBanner']);
      sectionBanner['altText'] = _sectionBannerAlt.text.trim();
      sectionBanner['linkUrl'] = _sectionBannerLink.text.trim();
      sectionBanner['enabled'] = _sectionBannerEnabled;
      websiteHome['sectionBanner'] = sectionBanner;
      final categories = _listFrom(websiteHome['categories']);
      for (var index = 0; index < categories.length; index++) {
        categories[index]['sortOrder'] = index;
      }
      websiteHome['categories'] = categories;
      _config['websiteHome'] = websiteHome;
      _config['ambassadorSupport'] = {
        'whatsappNumber': _ambassadorWhatsapp.text.trim(),
        'enabled': _ambassadorSupportEnabled,
      };
      final saved = await AdminApi.instance.saveMarketingConfig(_config);
      if (!mounted) return;
      setState(() => _config = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الحفظ والربط مع الموقع والتطبيق')),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل الحفظ: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editCoupon([int? index]) async {
    if (_saving) return;
    final items = _list('coupons');
    final initial = index == null
        ? <String, dynamic>{
            'code':
                'NEW${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}',
            'type': 'percent',
            'value': 10,
            'minSubtotal': 0,
            'maxDiscount': 0,
            'freeShipping': 0,
            'enabled': 1,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          }
        : items[index];
    final edited = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CouponDialog(initial: initial),
    );
    if (edited == null) return;
    if (index == null) {
      items.insert(0, edited);
    } else {
      items[index] = edited;
    }
    setState(() => _config['coupons'] = items);
    await _save();
  }

  Future<void> _removeCoupon(int index) async {
    if (_saving) return;
    final items = _list('coupons');
    if (index < 0 || index >= items.length) return;
    items.removeAt(index);
    setState(() => _config['coupons'] = items);
    await _save();
  }

  Future<void> _editCampaign(String kind, [int? index]) async {
    final key = kind == 'offer' ? 'offers' : '${kind}s';
    final source = kind == 'offer'
        ? _listFrom(mapValue(_config['offers'])['items'])
        : _list(key);
    final defaults = switch (kind) {
      'offer' => <String, dynamic>{
        'id': _unique('offer'),
        'text': 'عرض جديد',
        'kind': 'other',
        'enabled': true,
        'productIds': <String>[],
      },
      'gift' => <String, dynamic>{
        'id': _unique('gift'),
        'title': 'هدية جديدة',
        'description': '',
        'enabled': true,
        'badge': '',
        'ctaLabel': '',
        'giftType': '',
        'giftValue': '',
        'minOrderTotal': 0,
        'imageUrl': '',
      },
      _ => <String, dynamic>{
        'id': _unique('competition'),
        'title': 'مسابقة جديدة',
        'description': '',
        'enabled': true,
        'prize': '',
        'ctaLabel': '',
        'endAt': '',
        'imageUrl': '',
      },
    };
    final edited = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CampaignDialog(
        kind: kind,
        initial: index == null ? defaults : source[index],
        products: _products,
      ),
    );
    if (edited == null) return;
    if (index == null) {
      source.insert(0, edited);
    } else {
      source[index] = edited;
    }
    setState(() {
      if (kind == 'offer') {
        final offers = mapValue(_config['offers']);
        offers['items'] = source;
        _config['offers'] = offers;
      } else {
        _config[key] = source;
      }
    });
  }

  Map<String, dynamic> _websiteHome() => mapValue(_config['websiteHome']);

  List<Map<String, dynamic>> _websiteCategories() =>
      _listFrom(_websiteHome()['categories']);

  Future<void> _uploadBanner() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    setState(() => _uploadingBanner = true);
    try {
      final url = await AdminApi.instance.uploadImage(result.files.first);
      if (!mounted) return;
      setState(() {
        final websiteHome = _websiteHome();
        final banner = mapValue(websiteHome['banner']);
        banner['imageUrl'] = url;
        websiteHome['banner'] = banner;
        _config['websiteHome'] = websiteHome;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل رفع صورة البانر: $error')));
      }
    } finally {
      if (mounted) setState(() => _uploadingBanner = false);
    }
  }

  void _removeBanner() {
    setState(() {
      final websiteHome = _websiteHome();
      final banner = mapValue(websiteHome['banner']);
      banner['imageUrl'] = '';
      websiteHome['banner'] = banner;
      _config['websiteHome'] = websiteHome;
    });
  }

  Future<void> _uploadSectionBanner() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    setState(() => _uploadingSectionBanner = true);
    try {
      final url = await AdminApi.instance.uploadImage(result.files.first);
      if (!mounted) return;
      setState(() {
        final websiteHome = _websiteHome();
        final banner = mapValue(websiteHome['sectionBanner']);
        banner['imageUrl'] = url;
        websiteHome['sectionBanner'] = banner;
        _config['websiteHome'] = websiteHome;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل رفع بانر بين الأقسام: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingSectionBanner = false);
    }
  }

  void _removeSectionBanner() {
    setState(() {
      final websiteHome = _websiteHome();
      final banner = mapValue(websiteHome['sectionBanner']);
      banner['imageUrl'] = '';
      websiteHome['sectionBanner'] = banner;
      _config['websiteHome'] = websiteHome;
    });
  }

  void _setSectionBannerSetting(String key, Object value) {
    setState(() {
      final websiteHome = _websiteHome();
      final banner = mapValue(websiteHome['sectionBanner']);
      banner[key] = value;
      websiteHome['sectionBanner'] = banner;
      _config['websiteHome'] = websiteHome;
    });
  }

  Future<void> _editWebsiteCategory([int? index]) async {
    final items = _websiteCategories();
    if (index == null && items.length >= 12) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الحد الأقصى 12 قسمًا')));
      return;
    }
    final initial = index == null
        ? <String, dynamic>{
            'id': _unique('web_category'),
            'title': 'قسم جديد',
            'imageUrl': '',
            'productCategoryFilter': '',
            'enabled': true,
            'sortOrder': items.length,
          }
        : items[index];
    final productCategories =
        _products
            .map((product) => product.category.trim())
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final edited = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _WebsiteCategoryDialog(
        initial: initial,
        productCategories: productCategories,
      ),
    );
    if (edited == null) return;
    if (index == null) {
      items.add(edited);
    } else {
      items[index] = edited;
    }
    setState(() {
      final websiteHome = _websiteHome();
      websiteHome['categories'] = items;
      _config['websiteHome'] = websiteHome;
    });
  }

  void _removeWebsiteCategory(int index) {
    setState(() {
      final websiteHome = _websiteHome();
      websiteHome['categories'] = _websiteCategories()..removeAt(index);
      _config['websiteHome'] = websiteHome;
    });
  }

  void _remove(String kind, int index) {
    setState(() {
      if (kind == 'coupon') {
        final list = _list('coupons')..removeAt(index);
        _config['coupons'] = list;
      } else if (kind == 'offer') {
        final offers = mapValue(_config['offers']);
        offers['items'] = _listFrom(offers['items'])..removeAt(index);
        _config['offers'] = offers;
      } else {
        final key = '${kind}s';
        _config[key] = _list(key)..removeAt(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ProfessionalError(error: _error, retry: _load);
    final offers = mapValue(_config['offers']);
    final websiteHome = _websiteHome();
    final banner = mapValue(websiteHome['banner']);
    final sectionBanner = mapValue(websiteHome['sectionBanner']);
    final websiteAppearance = mapValue(_config['websiteAppearance']);
    final websiteCategories = _websiteCategories();
    return DefaultTabController(
      length: 7,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'العمولة'),
                Tab(text: 'واجهة الموقع'),
                Tab(text: 'تصميم الموقع'),
                Tab(text: 'الكوبونات'),
                Tab(text: 'العروض'),
                Tab(text: 'الهدايا'),
                Tab(text: 'المسابقات'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _CampaignPage(
                  children: [
                    TextField(
                      controller: _commission,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'نسبة العمولة العامة %',
                      ),
                    ),
                    SwitchListTile.adaptive(
                      value: _perProduct,
                      onChanged: (value) => setState(() => _perProduct = value),
                      title: const Text('عمولة مختلفة لكل منتج'),
                      subtitle: const Text(
                        'عند إيقافها تُستخدم النسبة العامة لجميع المنتجات',
                      ),
                    ),
                  ],
                ),
                _WebsiteHomePage(
                  announcementText: _announcementText,
                  announcementEnabled: _announcementEnabled,
                  announcementSpeed: _announcementSpeed,
                  announcementStyle: _announcementStyle,
                  onAnnouncementEnabledChanged: (value) =>
                      setState(() => _announcementEnabled = value),
                  onAnnouncementSpeedChanged: (value) =>
                      setState(() => _announcementSpeed = value),
                  onAnnouncementStyleChanged: (value) =>
                      setState(() => _announcementStyle = value),
                  banner: banner,
                  bannerAlt: _bannerAlt,
                  bannerLink: _bannerLink,
                  bannerEnabled: _bannerEnabled,
                  uploadingBanner: _uploadingBanner,
                  onBannerEnabledChanged: (value) =>
                      setState(() => _bannerEnabled = value),
                  onUploadBanner: _uploadBanner,
                  onRemoveBanner: _removeBanner,
                  sectionBanner: sectionBanner,
                  sectionBannerAlt: _sectionBannerAlt,
                  sectionBannerLink: _sectionBannerLink,
                  sectionBannerEnabled: _sectionBannerEnabled,
                  uploadingSectionBanner: _uploadingSectionBanner,
                  onSectionBannerEnabledChanged: (value) =>
                      setState(() => _sectionBannerEnabled = value),
                  onUploadSectionBanner: _uploadSectionBanner,
                  onRemoveSectionBanner: _removeSectionBanner,
                  onSectionBannerSettingChanged: _setSectionBannerSetting,
                  categories: websiteCategories,
                  onAddCategory: _editWebsiteCategory,
                  onEditCategory: (index) => _editWebsiteCategory(index),
                  onDeleteCategory: _removeWebsiteCategory,
                ),
                _WebsiteAppearancePage(
                  value: websiteAppearance,
                  whatsappController: _ambassadorWhatsapp,
                  ambassadorSupportEnabled: _ambassadorSupportEnabled,
                  onAmbassadorSupportEnabledChanged: (value) =>
                      setState(() => _ambassadorSupportEnabled = value),
                  onChanged: (value) =>
                      setState(() => _config['websiteAppearance'] = value),
                ),
                _CampaignList(
                  title: 'أكواد الخصم',
                  addLabel: 'إضافة كوبون',
                  items: _list('coupons'),
                  titleOf: (item) => textValue(item['code']),
                  subtitleOf: (item) =>
                      '${item['type']} • ${item['value']} • ${asBool(item['enabled']) ? 'مفعّل' : 'متوقف'}',
                  onAdd: _editCoupon,
                  onEdit: (index) => _editCoupon(index),
                  onDelete: _removeCoupon,
                ),
                _CampaignPage(
                  children: [
                    TextField(
                      controller: _offerTitle,
                      decoration: const InputDecoration(
                        labelText: 'عنوان بانر العروض',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _offerSubtitle,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'وصف البانر',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _offerCta,
                      decoration: const InputDecoration(
                        labelText: 'نص زر البانر',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _InlineCampaignList(
                      title: 'عناصر العروض',
                      items: _listFrom(offers['items']),
                      titleOf: (item) => textValue(item['text']),
                      subtitleOf: (item) =>
                          '${item['kind']} • ${asStringList(item['productIds']).length} منتج',
                      onAdd: () => _editCampaign('offer'),
                      onEdit: (index) => _editCampaign('offer', index),
                      onDelete: (index) => _remove('offer', index),
                    ),
                  ],
                ),
                _CampaignList(
                  title: 'الهدايا',
                  addLabel: 'إضافة هدية',
                  items: _list('gifts'),
                  titleOf: (item) => textValue(item['title']),
                  subtitleOf: (item) =>
                      '${item['giftValue']} • حد الطلب ${item['minOrderTotal']}',
                  onAdd: () => _editCampaign('gift'),
                  onEdit: (index) => _editCampaign('gift', index),
                  onDelete: (index) => _remove('gift', index),
                ),
                _CampaignList(
                  title: 'المسابقات',
                  addLabel: 'إضافة مسابقة',
                  items: _list('competitions'),
                  titleOf: (item) => textValue(item['title']),
                  subtitleOf: (item) =>
                      '${item['prize']} • النهاية ${item['endAt']}',
                  onAdd: () => _editCampaign('competition'),
                  onEdit: (index) => _editCampaign('competition', index),
                  onDelete: (index) => _remove('competition', index),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: const Text('حفظ ونشر على الموقع والتطبيق'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<Map<String, dynamic>> _listFrom(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
    : [];
String _unique(String prefix) =>
    '${prefix}_${DateTime.now().millisecondsSinceEpoch}';

class _CampaignPage extends StatelessWidget {
  const _CampaignPage({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ],
  );
}

class _WebsiteHomePage extends StatelessWidget {
  const _WebsiteHomePage({
    required this.announcementText,
    required this.announcementEnabled,
    required this.announcementSpeed,
    required this.announcementStyle,
    required this.onAnnouncementEnabledChanged,
    required this.onAnnouncementSpeedChanged,
    required this.onAnnouncementStyleChanged,
    required this.banner,
    required this.bannerAlt,
    required this.bannerLink,
    required this.bannerEnabled,
    required this.uploadingBanner,
    required this.onBannerEnabledChanged,
    required this.onUploadBanner,
    required this.onRemoveBanner,
    required this.sectionBanner,
    required this.sectionBannerAlt,
    required this.sectionBannerLink,
    required this.sectionBannerEnabled,
    required this.uploadingSectionBanner,
    required this.onSectionBannerEnabledChanged,
    required this.onUploadSectionBanner,
    required this.onRemoveSectionBanner,
    required this.onSectionBannerSettingChanged,
    required this.categories,
    required this.onAddCategory,
    required this.onEditCategory,
    required this.onDeleteCategory,
  });
  final TextEditingController announcementText;
  final bool announcementEnabled;
  final int announcementSpeed;
  final String announcementStyle;
  final ValueChanged<bool> onAnnouncementEnabledChanged;
  final ValueChanged<int> onAnnouncementSpeedChanged;
  final ValueChanged<String> onAnnouncementStyleChanged;
  final Map<String, dynamic> banner;
  final TextEditingController bannerAlt;
  final TextEditingController bannerLink;
  final bool bannerEnabled;
  final bool uploadingBanner;
  final ValueChanged<bool> onBannerEnabledChanged;
  final VoidCallback onUploadBanner;
  final VoidCallback onRemoveBanner;
  final Map<String, dynamic> sectionBanner;
  final TextEditingController sectionBannerAlt;
  final TextEditingController sectionBannerLink;
  final bool sectionBannerEnabled;
  final bool uploadingSectionBanner;
  final ValueChanged<bool> onSectionBannerEnabledChanged;
  final VoidCallback onUploadSectionBanner;
  final VoidCallback onRemoveSectionBanner;
  final void Function(String key, Object value) onSectionBannerSettingChanged;
  final List<Map<String, dynamic>> categories;
  final VoidCallback onAddCategory;
  final ValueChanged<int> onEditCategory;
  final ValueChanged<int> onDeleteCategory;

  @override
  Widget build(BuildContext context) {
    final imageUrl = textValue(banner['imageUrl']);
    final sectionImageUrl = textValue(sectionBanner['imageUrl']);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'شريط الإعلان المتحرك',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'يظهر أعلى الموقع ويتحرك تلقائيًا بدون أن يزعج التصفح.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: announcementText,
                  minLines: 2,
                  maxLines: 3,
                  maxLength: 240,
                  decoration: const InputDecoration(
                    labelText: 'نص الشريط',
                    prefixIcon: Icon(Icons.campaign_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                Text('سرعة الحركة: $announcementSpeed ثانية'),
                Slider(
                  value: announcementSpeed.toDouble(),
                  min: 6,
                  max: 60,
                  divisions: 18,
                  label: '$announcementSpeed ثانية',
                  onChanged: (value) =>
                      onAnnouncementSpeedChanged(value.round()),
                ),
                DropdownButtonFormField<String>(
                  initialValue: announcementStyle,
                  decoration: const InputDecoration(labelText: 'لون الشريط'),
                  items: const [
                    DropdownMenuItem(value: 'rose', child: Text('وردي أڤيا')),
                    DropdownMenuItem(value: 'dark', child: Text('داكن أنيق')),
                    DropdownMenuItem(value: 'gold', child: Text('ذهبي هادئ')),
                  ],
                  onChanged: (value) {
                    if (value != null) onAnnouncementStyleChanged(value);
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: announcementEnabled,
                  onChanged: onAnnouncementEnabledChanged,
                  title: const Text('إظهار الشريط أعلى الموقع'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'البانر العلوي للموقع',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'ارفعي صورة واحدة كاملة وعريضة، ويعرضها الموقع كما هي بدون إضافة نصوص فوقها.',
                ),
                const SizedBox(height: 14),
                AspectRatio(
                  aspectRatio: 1.86,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: imageUrl.isEmpty
                        ? Container(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.panorama_outlined, size: 46),
                                  SizedBox(height: 8),
                                  Text('لم تُرفع صورة بانر بعد'),
                                ],
                              ),
                            ),
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                  child: Text('تعذر تحميل معاينة الصورة'),
                                ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: uploadingBanner ? null : onUploadBanner,
                        icon: uploadingBanner
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.image_outlined),
                        label: Text(
                          imageUrl.isEmpty
                              ? 'رفع صورة البانر'
                              : 'استبدال الصورة',
                        ),
                      ),
                    ),
                    if (imageUrl.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: onRemoveBanner,
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'إزالة الصورة',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bannerAlt,
                  decoration: const InputDecoration(
                    labelText: 'وصف الصورة لمحركات البحث',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bannerLink,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'الرابط عند الضغط على البانر',
                    hintText: '#collection أو رابط كامل',
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: bannerEnabled,
                  onChanged: onBannerEnabledChanged,
                  title: const Text('إظهار البانر على الموقع'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _MarketingBannerEditor(
          title: 'بانر بين الأحدث والأكثر مبيعًا',
          description:
              'تظهر هذه الصورة في الموقع والتطبيق بين قسمي أحدث المنتجات والأكثر مبيعًا.',
          emptyLabel: 'لم تُرفع صورة بين الأقسام بعد',
          imageUrl: sectionImageUrl,
          altController: sectionBannerAlt,
          linkController: sectionBannerLink,
          enabled: sectionBannerEnabled,
          uploading: uploadingSectionBanner,
          onEnabledChanged: onSectionBannerEnabledChanged,
          onUpload: onUploadSectionBanner,
          onRemove: onRemoveSectionBanner,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'تنسيق بانر الوسط',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'تحكمي في عرض الصورة وارتفاعها والمسافة بينها وبين المنتجات.',
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: textValue(sectionBanner['widthMode']).isEmpty
                      ? 'full'
                      : textValue(sectionBanner['widthMode']),
                  decoration: const InputDecoration(labelText: 'عرض البانر'),
                  items: const [
                    DropdownMenuItem(
                      value: 'full',
                      child: Text('بعرض الشاشة — مقترح'),
                    ),
                    DropdownMenuItem(
                      value: 'container',
                      child: Text('داخل حدود المنتجات'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onSectionBannerSettingChanged('widthMode', value);
                    }
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: textValue(sectionBanner['height']).isEmpty
                      ? 'medium'
                      : textValue(sectionBanner['height']),
                  decoration: const InputDecoration(labelText: 'ارتفاع الصورة'),
                  items: const [
                    DropdownMenuItem(value: 'compact', child: Text('منخفض')),
                    DropdownMenuItem(value: 'medium', child: Text('متوسط')),
                    DropdownMenuItem(value: 'large', child: Text('كبير')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onSectionBannerSettingChanged('height', value);
                    }
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: textValue(sectionBanner['spacing']).isEmpty
                      ? 'tight'
                      : textValue(sectionBanner['spacing']),
                  decoration: const InputDecoration(
                    labelText: 'المسافة من المنتجات',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'tight',
                      child: Text('قريبة — مقترح'),
                    ),
                    DropdownMenuItem(value: 'normal', child: Text('عادية')),
                    DropdownMenuItem(value: 'wide', child: Text('واسعة')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onSectionBannerSettingChanged('spacing', value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _InlineCampaignList(
          title: 'أقسام واجهة الموقع',
          addLabel: 'إضافة قسم',
          items: categories,
          titleOf: (item) => textValue(item['title']),
          subtitleOf: (item) {
            final filter = textValue(item['productCategoryFilter']);
            return filter.isEmpty
                ? 'يعرض كل المنتجات'
                : 'فلتر المنتجات: $filter';
          },
          onAdd: onAddCategory,
          onEdit: onEditCategory,
          onDelete: onDeleteCategory,
        ),
      ],
    );
  }
}

class _MarketingBannerEditor extends StatelessWidget {
  const _MarketingBannerEditor({
    required this.title,
    required this.description,
    required this.emptyLabel,
    required this.imageUrl,
    required this.altController,
    required this.linkController,
    required this.enabled,
    required this.uploading,
    required this.onEnabledChanged,
    required this.onUpload,
    required this.onRemove,
  });

  final String title;
  final String description;
  final String emptyLabel;
  final String imageUrl;
  final TextEditingController altController;
  final TextEditingController linkController;
  final bool enabled;
  final bool uploading;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onUpload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(description),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 1.86,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: imageUrl.isEmpty
                  ? ColoredBox(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: Center(child: Text(emptyLabel)),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(child: Text('تعذر تحميل معاينة الصورة')),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: uploading ? null : onUpload,
                  icon: uploading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image_outlined),
                  label: Text(
                    imageUrl.isEmpty ? 'رفع الصورة' : 'استبدال الصورة',
                  ),
                ),
              ),
              if (imageUrl.isNotEmpty) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'إزالة الصورة',
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: altController,
            decoration: const InputDecoration(labelText: 'وصف الصورة'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: linkController,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'الرابط عند الضغط',
              hintText: '#collection أو رابط كامل',
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: enabled,
            onChanged: onEnabledChanged,
            title: const Text('إظهار الصورة في الموقع والتطبيق'),
          ),
        ],
      ),
    ),
  );
}

class _WebsiteAppearancePage extends StatelessWidget {
  const _WebsiteAppearancePage({
    required this.value,
    required this.whatsappController,
    required this.ambassadorSupportEnabled,
    required this.onAmbassadorSupportEnabledChanged,
    required this.onChanged,
  });

  final Map<String, dynamic> value;
  final TextEditingController whatsappController;
  final bool ambassadorSupportEnabled;
  final ValueChanged<bool> onAmbassadorSupportEnabledChanged;
  final ValueChanged<Map<String, dynamic>> onChanged;

  void _set(String key, Object next) => onChanged({...value, key: next});

  @override
  Widget build(BuildContext context) {
    final cardSize = textValue(value['productCardSize']).isEmpty
        ? 'small'
        : textValue(value['productCardSize']);
    final imageRatio = textValue(value['productImageRatio']).isEmpty
        ? 'portrait'
        : textValue(value['productImageRatio']);
    final discountCorner = textValue(value['discountCorner']).isEmpty
        ? 'right'
        : textValue(value['discountCorner']);
    final buttonSize = textValue(value['checkoutButtonSize']).isEmpty
        ? 'small'
        : textValue(value['checkoutButtonSize']);
    final confirmPosition = textValue(value['checkoutConfirmPosition']).isEmpty
        ? 'afterCustomer'
        : textValue(value['checkoutConfirmPosition']);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'أقسام الصفحة الرئيسية',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'أظهري فقط الأقسام التي تحتاجينها للحفاظ على واجهة بسيطة.',
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: value['showHomepageCategories'] != false,
                  onChanged: (next) => _set('showHomepageCategories', next),
                  title: const Text('إظهار أقسام المنتجات'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: value['showOffersStrip'] != false,
                  onChanged: (next) => _set('showOffersStrip', next),
                  title: const Text('إظهار شريط العروض'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: value['showNewestSection'] != false,
                  onChanged: (next) => _set('showNewestSection', next),
                  title: const Text('إظهار أحدث المنتجات'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: value['showBestSellingSection'] != false,
                  onChanged: (next) => _set('showBestSellingSection', next),
                  title: const Text('إظهار الأكثر مبيعًا'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'بطاقات المنتجات في كامل الموقع',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'تُطبّق على الرئيسية والمتجر والأقسام والمفضلة فور الحفظ.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: cardSize,
                  decoration: const InputDecoration(labelText: 'حجم البطاقة'),
                  items: const [
                    DropdownMenuItem(
                      value: 'small',
                      child: Text('صغير — 5 بطاقات'),
                    ),
                    DropdownMenuItem(
                      value: 'medium',
                      child: Text('متوسط — 4 بطاقات'),
                    ),
                    DropdownMenuItem(
                      value: 'large',
                      child: Text('كبير — 3 بطاقات'),
                    ),
                  ],
                  onChanged: (next) {
                    if (next != null) _set('productCardSize', next);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: imageRatio,
                  decoration: const InputDecoration(
                    labelText: 'شكل صورة المنتج',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'portrait',
                      child: Text('عمودية 3:4'),
                    ),
                    DropdownMenuItem(value: 'tall', child: Text('عمودية 4:5')),
                    DropdownMenuItem(value: 'square', child: Text('مربعة 1:1')),
                  ],
                  onChanged: (next) {
                    if (next != null) _set('productImageRatio', next);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: discountCorner,
                  decoration: const InputDecoration(labelText: 'زاوية الخصم'),
                  items: const [
                    DropdownMenuItem(
                      value: 'right',
                      child: Text('يمين — القلب يسار'),
                    ),
                    DropdownMenuItem(
                      value: 'left',
                      child: Text('يسار — القلب يمين'),
                    ),
                  ],
                  onChanged: (next) {
                    if (next != null) _set('discountCorner', next);
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: value['showFavorite'] != false,
                  onChanged: (next) => _set('showFavorite', next),
                  title: const Text('إظهار زر القلب'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: value['showShare'] != false,
                  onChanged: (next) => _set('showShare', next),
                  title: const Text('إظهار زر المشاركة'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'دعم المندوبات عبر واتساب',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'يظهر كزر عائم في صفحة المندوبات فقط، ويمكن تغييره أو إخفاؤه في أي وقت.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: whatsappController,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'رقم واتساب الدعم',
                    hintText: '+218912345678 أو 0912345678',
                    prefixIcon: Icon(Icons.chat_outlined),
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: ambassadorSupportEnabled,
                  onChanged: onAmbassadorSupportEnabledChanged,
                  title: const Text('إظهار زر الدعم للمندوبات'),
                  subtitle: const Text('لن يظهر الزر إذا كان الرقم فارغًا'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'صفحة إتمام الطلب',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: confirmPosition,
                  decoration: const InputDecoration(
                    labelText: 'مكان تأكيد الطلب',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'afterCustomer',
                      child: Text('بعد بيانات العميلة مباشرة'),
                    ),
                    DropdownMenuItem(
                      value: 'summary',
                      child: Text('داخل ملخص الطلب'),
                    ),
                  ],
                  onChanged: (next) {
                    if (next != null) _set('checkoutConfirmPosition', next);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: buttonSize,
                  decoration: const InputDecoration(
                    labelText: 'حجم زر التأكيد',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'small', child: Text('صغير وبسيط')),
                    DropdownMenuItem(value: 'medium', child: Text('متوسط')),
                  ],
                  onChanged: (next) {
                    if (next != null) _set('checkoutButtonSize', next);
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'بعد التعديل اضغطي «حفظ ونشر على الموقع والتطبيق» لتطبيقه على الموقع مباشرة.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WebsiteCategoryDialog extends StatefulWidget {
  const _WebsiteCategoryDialog({
    required this.initial,
    required this.productCategories,
  });
  final Map<String, dynamic> initial;
  final List<String> productCategories;
  @override
  State<_WebsiteCategoryDialog> createState() => _WebsiteCategoryDialogState();
}

class _WebsiteCategoryDialogState extends State<_WebsiteCategoryDialog> {
  late final _title = TextEditingController(
    text: textValue(widget.initial['title']),
  );
  late final _filter = TextEditingController(
    text: textValue(widget.initial['productCategoryFilter']),
  );
  late String _imageUrl = textValue(widget.initial['imageUrl']);
  late bool _enabled = widget.initial['enabled'] != false;
  bool _uploading = false;

  @override
  void dispose() {
    _title.dispose();
    _filter.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    setState(() => _uploading = true);
    try {
      final url = await AdminApi.instance.uploadImage(result.files.first);
      if (mounted) setState(() => _imageUrl = url);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل رفع صورة القسم: $error')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('قسم واجهة الموقع'),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(100),
                ),
                child: _imageUrl.isEmpty
                    ? Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.image_outlined, size: 48),
                      )
                    : Image.network(
                        _imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(child: Text('تعذر تحميل الصورة')),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: _uploading ? null : _pickImage,
              icon: _uploading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_outlined),
              label: Text(
                _imageUrl.isEmpty ? 'رفع صورة القسم' : 'استبدال الصورة',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'اسم القسم الظاهر'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _filter,
              decoration: const InputDecoration(
                labelText: 'تصنيف المنتجات المرتبط',
                hintText: 'اتركيه فارغًا لعرض كل المنتجات',
              ),
            ),
            if (widget.productCategories.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: widget.productCategories
                      .map(
                        (category) => ActionChip(
                          label: Text(category),
                          onPressed: () =>
                              setState(() => _filter.text = category),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            SwitchListTile.adaptive(
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
              title: const Text('إظهار القسم'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: _title.text.trim().isEmpty || _imageUrl.isEmpty
            ? null
            : () => Navigator.pop(context, {
                ...widget.initial,
                'title': _title.text.trim(),
                'imageUrl': _imageUrl,
                'productCategoryFilter': _filter.text.trim(),
                'enabled': _enabled,
              }),
        child: const Text('اعتماد ونشر'),
      ),
    ],
  );
}

class _CampaignList extends StatelessWidget {
  const _CampaignList({
    required this.title,
    required this.addLabel,
    required this.items,
    required this.titleOf,
    required this.subtitleOf,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });
  final String title;
  final String addLabel;
  final List<Map<String, dynamic>> items;
  final String Function(Map<String, dynamic>) titleOf;
  final String Function(Map<String, dynamic>) subtitleOf;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _InlineCampaignList(
        title: title,
        items: items,
        titleOf: titleOf,
        subtitleOf: subtitleOf,
        onAdd: onAdd,
        onEdit: onEdit,
        onDelete: onDelete,
        addLabel: addLabel,
      ),
    ],
  );
}

class _InlineCampaignList extends StatelessWidget {
  const _InlineCampaignList({
    required this.title,
    required this.items,
    required this.titleOf,
    required this.subtitleOf,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    this.addLabel = 'إضافة',
  });
  final String title;
  final String addLabel;
  final List<Map<String, dynamic>> items;
  final String Function(Map<String, dynamic>) titleOf;
  final String Function(Map<String, dynamic>) subtitleOf;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(addLabel),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (items.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: Text('لا توجد عناصر بعد')),
          ),
        ),
      for (var index = 0; index < items.length; index++)
        Card(
          child: ListTile(
            title: Text(
              titleOf(items[index]),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(subtitleOf(items[index])),
            leading: Icon(
              asBool(items[index]['enabled'])
                  ? Icons.check_circle
                  : Icons.pause_circle_outline,
              color: asBool(items[index]['enabled'])
                  ? Colors.green
                  : Colors.grey,
            ),
            onTap: () => onEdit(index),
            trailing: IconButton(
              onPressed: () => onDelete(index),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        ),
    ],
  );
}

class _CouponDialog extends StatefulWidget {
  const _CouponDialog({required this.initial});
  final Map<String, dynamic> initial;
  @override
  State<_CouponDialog> createState() => _CouponDialogState();
}

class _CouponDialogState extends State<_CouponDialog> {
  late final _code = TextEditingController(
    text: textValue(widget.initial['code']),
  );
  late final _value = TextEditingController(
    text: '${asDouble(widget.initial['value'])}',
  );
  late final _minimum = TextEditingController(
    text: '${asDouble(widget.initial['minSubtotal'])}',
  );
  late final _maximum = TextEditingController(
    text: '${asDouble(widget.initial['maxDiscount'])}',
  );
  late String _type = textValue(widget.initial['type']).isEmpty
      ? 'percent'
      : textValue(widget.initial['type']);
  late bool _enabled = asBool(widget.initial['enabled']);
  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    _minimum.dispose();
    _maximum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('كوبون الخصم'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'الكود'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'النوع'),
            items: const [
              DropdownMenuItem(value: 'percent', child: Text('نسبة مئوية')),
              DropdownMenuItem(value: 'fixed', child: Text('مبلغ ثابت')),
              DropdownMenuItem(value: 'freeShipping', child: Text('شحن مجاني')),
            ],
            onChanged: (value) => setState(() => _type = value ?? _type),
          ),
          const SizedBox(height: 10),
          if (_type != 'freeShipping')
            TextField(
              controller: _value,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'القيمة'),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _minimum,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الحد الأدنى للطلب'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _maximum,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'سقف الخصم'),
          ),
          SwitchListTile.adaptive(
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
            title: const Text('مفعّل'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: () {
          if (_code.text.trim().isEmpty) return;
          Navigator.pop(context, {
            ...widget.initial,
            'code': _code.text.trim().toUpperCase(),
            'type': _type,
            'value': _type == 'freeShipping' ? 0 : asDouble(_value.text),
            'minSubtotal': asDouble(_minimum.text),
            'maxDiscount': asDouble(_maximum.text),
            'freeShipping': _type == 'freeShipping' ? 1 : 0,
            'enabled': _enabled ? 1 : 0,
          });
        },
        child: const Text('اعتماد'),
      ),
    ],
  );
}

class _CampaignDialog extends StatefulWidget {
  const _CampaignDialog({
    required this.kind,
    required this.initial,
    required this.products,
  });
  final String kind;
  final Map<String, dynamic> initial;
  final List<AdminProduct> products;
  @override
  State<_CampaignDialog> createState() => _CampaignDialogState();
}

class _CampaignDialogState extends State<_CampaignDialog> {
  late final _title = TextEditingController(
    text: textValue(widget.initial[widget.kind == 'offer' ? 'text' : 'title']),
  );
  late final _description = TextEditingController(
    text: textValue(
      widget.initial[widget.kind == 'offer' ? 'text' : 'description'],
    ),
  );
  late final _cta = TextEditingController(
    text: textValue(widget.initial['ctaLabel']),
  );
  late final _extra = TextEditingController(
    text: textValue(
      widget.initial[widget.kind == 'gift'
          ? 'giftValue'
          : widget.kind == 'competition'
          ? 'prize'
          : 'kind'],
    ),
  );
  late final _minimum = TextEditingController(
    text: '${asDouble(widget.initial['minOrderTotal'])}',
  );
  late final _endAt = TextEditingController(
    text: textValue(widget.initial['endAt']),
  );
  late final Set<String> _productIds = asStringList(
    widget.initial['productIds'],
  ).toSet();
  late bool _enabled = widget.initial['enabled'] != false;
  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _cta.dispose();
    _extra.dispose();
    _minimum.dispose();
    _endAt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.kind == 'offer'
          ? 'العرض'
          : widget.kind == 'gift'
          ? 'الهدية'
          : 'المسابقة',
    ),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'العنوان'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'الوصف'),
            ),
            const SizedBox(height: 10),
            if (widget.kind != 'offer')
              TextField(
                controller: _cta,
                decoration: const InputDecoration(labelText: 'نص الزر'),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _extra,
              decoration: InputDecoration(
                labelText: widget.kind == 'offer'
                    ? 'نوع العرض'
                    : widget.kind == 'gift'
                    ? 'قيمة الهدية'
                    : 'الجائزة',
              ),
            ),
            const SizedBox(height: 10),
            if (widget.kind == 'gift')
              TextField(
                controller: _minimum,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الحد الأدنى للطلب',
                ),
              ),
            if (widget.kind == 'competition')
              TextField(
                controller: _endAt,
                decoration: const InputDecoration(labelText: 'تاريخ النهاية'),
              ),
            if (widget.kind == 'offer') ...[
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: EdgeInsets.only(top: 12, bottom: 6),
                  child: Text(
                    'المنتجات المرتبطة',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              for (final product in widget.products)
                CheckboxListTile(
                  value: _productIds.contains(product.id),
                  onChanged: (selected) => setState(() {
                    if (selected == true) {
                      _productIds.add(product.id);
                    } else {
                      _productIds.remove(product.id);
                    }
                  }),
                  title: Text(product.name),
                  subtitle: Text(product.productCode),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
            ],
            SwitchListTile.adaptive(
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
              title: const Text('مفعّل'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: () {
          final next = {...widget.initial, 'enabled': _enabled};
          if (widget.kind == 'offer') {
            next.addAll({
              'text': _title.text.trim(),
              'kind': _extra.text.trim(),
              'productIds': _productIds.toList(),
            });
          } else if (widget.kind == 'gift') {
            next.addAll({
              'title': _title.text.trim(),
              'description': _description.text.trim(),
              'ctaLabel': _cta.text.trim(),
              'giftValue': _extra.text.trim(),
              'minOrderTotal': asDouble(_minimum.text),
            });
          } else {
            next.addAll({
              'title': _title.text.trim(),
              'description': _description.text.trim(),
              'ctaLabel': _cta.text.trim(),
              'prize': _extra.text.trim(),
              'endAt': _endAt.text.trim(),
            });
          }
          Navigator.pop(context, next);
        },
        child: const Text('اعتماد'),
      ),
    ],
  );
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.rows});
  final String title;
  final List<(String, String)> rows;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const Divider(),
          for (final row in rows.where((row) => row.$2.isNotEmpty))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      row.$1,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      row.$2,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          Text(
            value,
            maxLines: 1,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(title, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

class _MiniValue extends StatelessWidget {
  const _MiniValue({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _ProfessionalError extends StatelessWidget {
  const _ProfessionalError({required this.error, required this.retry});
  final Object? error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 55),
          const SizedBox(height: 12),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    ),
  );
}
