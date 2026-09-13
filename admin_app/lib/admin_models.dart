import 'dart:convert';

int asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

double asDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? fallback;
}

bool asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return const {'1', 'true', 'yes', 'on'}.contains('$value'.toLowerCase());
}

String _cleanOption(Object? value) => '$value'
    .trim()
    .replaceAll(RegExp(r'''^[\s\[\]"']+|[\s\[\]"']+$'''), '')
    .trim();

List<String> asStringList(Object? value) {
  if (value is List) {
    return value
        .map(_cleanOption)
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') return [];
  try {
    final decoded = jsonDecode(text);
    if (decoded is List) return asStringList(decoded);
  } catch (_) {}
  return text
      .split(RegExp(r'[,،\n\r]+'))
      .map(_cleanOption)
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();
}

Map<String, int> asQuantityMap(Object? value) {
  if (value is Map) {
    final result = <String, int>{};
    for (final entry in value.entries) {
      final key = _cleanOption(entry.key);
      if (key.isNotEmpty) result[key] = asInt(entry.value).clamp(0, 1 << 30);
    }
    return result;
  }
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') return {};
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map) return asQuantityMap(decoded);
  } catch (_) {}
  return {};
}

class AdminProduct {
  const AdminProduct({
    required this.id,
    required this.name,
    required this.productCode,
    required this.price,
    required this.oldPrice,
    required this.purchasePrice,
    required this.commissionPercent,
    required this.category,
    required this.tags,
    required this.sizes,
    required this.sizeType,
    required this.lengths,
    required this.colors,
    required this.stockQuantity,
    required this.lowStockThreshold,
    required this.sizeQuantities,
    required this.colorQuantities,
    required this.rating,
    required this.reviewsCount,
    required this.description,
    required this.imageUrls,
    required this.isHidden,
    required this.createdAt,
  });

  factory AdminProduct.fromJson(Map<String, dynamic> json) {
    final images = asStringList(json['imageUrls']);
    final primary = '${json['imageUrl'] ?? ''}'.trim();
    if (primary.isNotEmpty && !images.contains(primary))
      images.insert(0, primary);
    return AdminProduct(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      productCode: '${json['productCode'] ?? ''}',
      price: asDouble(json['price']),
      oldPrice: asDouble(json['oldPrice']),
      purchasePrice: asDouble(json['purchasePrice']).clamp(0, double.infinity),
      commissionPercent: asDouble(json['commissionPercent']).clamp(0, 100),
      category: '${json['category'] ?? 'غير مصنف'}',
      tags: asStringList(json['tags']),
      sizes: asStringList(json['sizes']),
      sizeType: '${json['sizeType'] ?? 'clothing'}',
      lengths: asStringList(json['lengths']),
      colors: asStringList(json['colors']),
      stockQuantity: asInt(json['stockQuantity']),
      lowStockThreshold: asInt(json['lowStockThreshold']),
      sizeQuantities: asQuantityMap(json['sizeQuantities']),
      colorQuantities: asQuantityMap(json['colorQuantities']),
      rating: asDouble(json['rating']),
      reviewsCount: asInt(json['reviewsCount']),
      description: '${json['description'] ?? ''}',
      imageUrls: images,
      isHidden: asBool(json['isHidden']),
      createdAt: asInt(json['createdAt']),
    );
  }

  final String id;
  final String name;
  final String productCode;
  final double price;
  final double oldPrice;
  final double purchasePrice;
  final double commissionPercent;
  final String category;
  final List<String> tags;
  final List<String> sizes;
  final String sizeType;
  final List<String> lengths;
  final List<String> colors;
  final int stockQuantity;
  final int lowStockThreshold;
  final Map<String, int> sizeQuantities;
  final Map<String, int> colorQuantities;
  final double rating;
  final int reviewsCount;
  final String description;
  final List<String> imageUrls;
  final bool isHidden;
  final int createdAt;

  int get availableStock => sizeQuantities.isEmpty
      ? stockQuantity
      : sizeQuantities.values.fold(0, (sum, quantity) => sum + quantity);
}

class AdminOrder {
  const AdminOrder({
    required this.orderId,
    required this.status,
    required this.customerName,
    required this.customerPhone,
    required this.grandTotal,
    required this.itemsCount,
    required this.createdAtMs,
    required this.payload,
    required this.ambassadorSummary,
    required this.commissionInfo,
    required this.externalDelivery,
    required this.trackingToken,
    required this.inventoryReserved,
  });

  factory AdminOrder.fromJson(Map<String, dynamic> json) => AdminOrder(
    orderId: '${json['orderId'] ?? ''}',
    status: '${json['status'] ?? 'pending'}',
    customerName: '${json['customerName'] ?? ''}',
    customerPhone: '${json['customerPhone'] ?? ''}',
    grandTotal: asDouble(json['grandTotal']),
    itemsCount: asInt(json['itemsCount']),
    createdAtMs: asInt(json['createdAtMs']),
    payload: json['payload'] is Map
        ? Map<String, dynamic>.from(json['payload'] as Map)
        : {},
    ambassadorSummary: json['ambassadorSummary'] is Map
        ? Map<String, dynamic>.from(json['ambassadorSummary'] as Map)
        : {},
    commissionInfo: json['commission'] is Map
        ? Map<String, dynamic>.from(json['commission'] as Map)
        : {},
    externalDelivery: json['externalDelivery'] is Map
        ? Map<String, dynamic>.from(json['externalDelivery'] as Map)
        : {},
    trackingToken: '${json['trackingToken'] ?? ''}',
    inventoryReserved: asBool(json['inventoryReserved']),
  );

  final String orderId;
  final String status;
  final String customerName;
  final String customerPhone;
  final double grandTotal;
  final int itemsCount;
  final int createdAtMs;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> ambassadorSummary;
  final Map<String, dynamic> commissionInfo;
  final Map<String, dynamic> externalDelivery;
  final String trackingToken;
  final bool inventoryReserved;

  String get deliveryStatus => '${externalDelivery['status'] ?? ''}'.trim();
  String get trackingNumber =>
      '${externalDelivery['trackingNumber'] ?? externalDelivery['shipmentId'] ?? ''}'
          .trim();
  String get deliveryError => '${externalDelivery['lastError'] ?? ''}'.trim();
  String get providerStatus =>
      '${externalDelivery['providerStatus'] ?? ''}'.trim().toLowerCase();
  String get deliveryLocationLabel {
    if (status == 'returning') return 'الطلب راجع مع المندوب';
    if (status == 'returned') return 'المرتجع وصل للشركة';
    if (status == 'canceled') return 'الطلب ملغي';
    if (providerStatus.contains('assigned') ||
        providerStatus.contains('picked')) {
      return 'الطلب عند المندوب';
    }
    if (deliveryStatus == 'created' || providerStatus.isNotEmpty) {
      return 'الطلب لدى شركة التوصيل';
    }
    return 'لم يُرسل لشركة التوصيل';
  }

  int get deliveryLastSyncAtMs => asInt(externalDelivery['lastSyncAtMs']);
  List<Map<String, dynamic>> get deliveryTimeline =>
      externalDelivery['timeline'] is List
      ? (externalDelivery['timeline'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : const [];
  bool get hasCreatedShipment => deliveryStatus == 'created';

  bool get isAmbassador {
    final customer = payload['customer'];
    return ambassadorSummary['isAmbassadorOrder'] == true ||
        (customer is Map &&
            (customer['placedAsAmbassador'] == true ||
                customer['accountRole'] == 'ambassador'));
  }
}

const withdrawalStatusLabels = {
  'pending': 'قيد المراجعة',
  'approved': 'تم القبول',
  'paid': 'تم الدفع',
  'rejected': 'مرفوض',
};

class AmbassadorWithdrawalRequest {
  const AmbassadorWithdrawalRequest({
    required this.id,
    required this.ambassadorUid,
    required this.ambassadorName,
    required this.ambassadorPhone,
    required this.amount,
    required this.status,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  factory AmbassadorWithdrawalRequest.fromJson(Map<String, dynamic> json) =>
      AmbassadorWithdrawalRequest(
        id: '${json['id'] ?? ''}',
        ambassadorUid: '${json['ambassadorUid'] ?? ''}',
        ambassadorName: '${json['ambassadorName'] ?? ''}',
        ambassadorPhone: '${json['ambassadorPhone'] ?? ''}',
        amount: asDouble(json['amount']),
        status: '${json['status'] ?? 'pending'}',
        createdAtMs: asInt(json['createdAtMs']),
        updatedAtMs: asInt(json['updatedAtMs']),
      );

  final String id;
  final String ambassadorUid;
  final String ambassadorName;
  final String ambassadorPhone;
  final double amount;
  final String status;
  final int createdAtMs;
  final int updatedAtMs;

  String get statusLabel => withdrawalStatusLabels[status] ?? status;

  List<String> get allowedNextStatuses => switch (status) {
    'pending' => const ['approved', 'rejected'],
    'approved' => const ['paid', 'rejected'],
    _ => const [],
  };
}

class AmbassadorCommissionHistoryEntry {
  const AmbassadorCommissionHistoryEntry({
    required this.id,
    required this.action,
    required this.previousStatus,
    required this.nextStatus,
    required this.previousAmount,
    required this.nextAmount,
    required this.delta,
    required this.note,
    required this.createdAtMs,
    required this.actor,
  });

  factory AmbassadorCommissionHistoryEntry.fromJson(
    Map<String, dynamic> json,
  ) => AmbassadorCommissionHistoryEntry(
    id: '${json['id'] ?? ''}',
    action: '${json['action'] ?? ''}',
    previousStatus: '${json['previousStatus'] ?? ''}',
    nextStatus: '${json['nextStatus'] ?? ''}',
    previousAmount: asDouble(json['previousAmount']),
    nextAmount: asDouble(json['nextAmount']),
    delta: asDouble(json['delta']),
    note: '${json['note'] ?? ''}',
    createdAtMs: asInt(json['createdAtMs']),
    actor: '${json['actor'] ?? ''}',
  );

  final String id;
  final String action;
  final String previousStatus;
  final String nextStatus;
  final double previousAmount;
  final double nextAmount;
  final double delta;
  final String note;
  final int createdAtMs;
  final String actor;
}

class AmbassadorCommissionRecord {
  const AmbassadorCommissionRecord({
    required this.id,
    required this.sourceType,
    required this.orderId,
    required this.ambassadorKey,
    required this.ambassadorUid,
    required this.ambassadorName,
    required this.ambassadorEmail,
    required this.ambassadorPhone,
    required this.status,
    required this.baseAmount,
    required this.approvedAmount,
    required this.note,
    required this.reason,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.history,
  });

  factory AmbassadorCommissionRecord.fromJson(Map<String, dynamic> json) =>
      AmbassadorCommissionRecord(
        id: '${json['id'] ?? ''}',
        sourceType: '${json['sourceType'] ?? 'manual'}',
        orderId: '${json['orderId'] ?? ''}',
        ambassadorKey: '${json['ambassadorKey'] ?? ''}',
        ambassadorUid: '${json['ambassadorUid'] ?? ''}',
        ambassadorName: '${json['ambassadorName'] ?? ''}',
        ambassadorEmail: '${json['ambassadorEmail'] ?? ''}',
        ambassadorPhone: '${json['ambassadorPhone'] ?? ''}',
        status: '${json['status'] ?? 'pending'}',
        baseAmount: asDouble(json['baseAmount']),
        approvedAmount: asDouble(json['approvedAmount']),
        note: '${json['note'] ?? ''}',
        reason: '${json['reason'] ?? ''}',
        createdAtMs: asInt(json['createdAtMs']),
        updatedAtMs: asInt(json['updatedAtMs']),
        history: json['history'] is List
            ? (json['history'] as List)
                  .whereType<Map>()
                  .map(
                    (item) => AmbassadorCommissionHistoryEntry.fromJson(
                      Map<String, dynamic>.from(item),
                    ),
                  )
                  .toList()
            : const [],
      );

  final String id;
  final String sourceType;
  final String orderId;
  final String ambassadorKey;
  final String ambassadorUid;
  final String ambassadorName;
  final String ambassadorEmail;
  final String ambassadorPhone;
  final String status;
  final double baseAmount;
  final double approvedAmount;
  final String note;
  final String reason;
  final int createdAtMs;
  final int updatedAtMs;
  final List<AmbassadorCommissionHistoryEntry> history;

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isCanceled => status == 'canceled';
}

class AmbassadorFinanceEvent {
  const AmbassadorFinanceEvent({
    required this.id,
    required this.type,
    required this.label,
    required this.amount,
    required this.status,
    required this.createdAtMs,
    required this.note,
    required this.orderId,
  });

  factory AmbassadorFinanceEvent.fromJson(Map<String, dynamic> json) =>
      AmbassadorFinanceEvent(
        id: '${json['id'] ?? ''}',
        type: '${json['type'] ?? ''}',
        label: '${json['label'] ?? ''}',
        amount: asDouble(json['amount']),
        status: '${json['status'] ?? ''}',
        createdAtMs: asInt(json['createdAtMs']),
        note: '${json['note'] ?? ''}',
        orderId: '${json['orderId'] ?? ''}',
      );

  final String id;
  final String type;
  final String label;
  final double amount;
  final String status;
  final int createdAtMs;
  final String note;
  final String orderId;
}

class AmbassadorFinanceProfile {
  const AmbassadorFinanceProfile({
    required this.key,
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.status,
    required this.joinedAtMs,
    required this.lastOrderMs,
    required this.ordersCount,
    required this.deliveredOrders,
    required this.openOrders,
    required this.canceledOrders,
    required this.pieces,
    required this.sales,
    required this.pipelineCommission,
    required this.pendingApprovalCommission,
    required this.approvedCommission,
    required this.canceledCommission,
    required this.manualAdjustments,
    required this.approvedAdjustments,
    required this.pendingAdjustments,
    required this.reservedWithdrawals,
    required this.pendingWithdrawalsTotal,
    required this.approvedWithdrawalsTotal,
    required this.paidWithdrawalsTotal,
    required this.rejectedWithdrawalsTotal,
    required this.availableBalance,
    required this.needsAttention,
    required this.orders,
    required this.records,
    required this.history,
  });

  factory AmbassadorFinanceProfile.fromJson(Map<String, dynamic> json) =>
      AmbassadorFinanceProfile(
        key: '${json['key'] ?? ''}',
        uid: '${json['uid'] ?? ''}',
        name: '${json['name'] ?? 'مندوبة غير محددة'}',
        email: '${json['email'] ?? ''}',
        phone: '${json['phone'] ?? ''}',
        address: '${json['address'] ?? ''}',
        status: '${json['status'] ?? 'active'}',
        joinedAtMs: asInt(json['joinedAtMs']),
        lastOrderMs: asInt(json['lastOrderMs']),
        ordersCount: asInt(json['ordersCount']),
        deliveredOrders: asInt(json['deliveredOrders']),
        openOrders: asInt(json['openOrders']),
        canceledOrders: asInt(json['canceledOrders']),
        pieces: asInt(json['pieces']),
        sales: asDouble(json['sales']),
        pipelineCommission: asDouble(json['pipelineCommission']),
        pendingApprovalCommission: asDouble(json['pendingApprovalCommission']),
        approvedCommission: asDouble(json['approvedCommission']),
        canceledCommission: asDouble(json['canceledCommission']),
        manualAdjustments: asDouble(json['manualAdjustments']),
        approvedAdjustments: asDouble(json['approvedAdjustments']),
        pendingAdjustments: asDouble(json['pendingAdjustments']),
        reservedWithdrawals: asDouble(json['reservedWithdrawals']),
        pendingWithdrawalsTotal: asDouble(json['pendingWithdrawalsTotal']),
        approvedWithdrawalsTotal: asDouble(json['approvedWithdrawalsTotal']),
        paidWithdrawalsTotal: asDouble(json['paidWithdrawalsTotal']),
        rejectedWithdrawalsTotal: asDouble(json['rejectedWithdrawalsTotal']),
        availableBalance: asDouble(json['availableBalance']),
        needsAttention: asBool(json['needsAttention']),
        orders: json['orders'] is List
            ? (json['orders'] as List)
                  .whereType<Map>()
                  .map(
                    (item) =>
                        AdminOrder.fromJson(Map<String, dynamic>.from(item)),
                  )
                  .toList()
            : const [],
        records: json['records'] is List
            ? (json['records'] as List)
                  .whereType<Map>()
                  .map(
                    (item) => AmbassadorCommissionRecord.fromJson(
                      Map<String, dynamic>.from(item),
                    ),
                  )
                  .toList()
            : const [],
        history: json['history'] is List
            ? (json['history'] as List)
                  .whereType<Map>()
                  .map(
                    (item) => AmbassadorFinanceEvent.fromJson(
                      Map<String, dynamic>.from(item),
                    ),
                  )
                  .toList()
            : const [],
      );

  final String key;
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String status;
  final int joinedAtMs;
  final int lastOrderMs;
  final int ordersCount;
  final int deliveredOrders;
  final int openOrders;
  final int canceledOrders;
  final int pieces;
  final double sales;
  final double pipelineCommission;
  final double pendingApprovalCommission;
  final double approvedCommission;
  final double canceledCommission;
  final double manualAdjustments;
  final double approvedAdjustments;
  final double pendingAdjustments;
  final double reservedWithdrawals;
  final double pendingWithdrawalsTotal;
  final double approvedWithdrawalsTotal;
  final double paidWithdrawalsTotal;
  final double rejectedWithdrawalsTotal;
  final double availableBalance;
  final bool needsAttention;
  final List<AdminOrder> orders;
  final List<AmbassadorCommissionRecord> records;
  final List<AmbassadorFinanceEvent> history;

  double get deliveryRate =>
      ordersCount == 0 ? 0 : (deliveredOrders * 100) / ordersCount;
  double get averageOrder => ordersCount == 0 ? 0 : sales / ordersCount;
}

class AmbassadorProgramSummary {
  const AmbassadorProgramSummary({
    required this.ambassadorCount,
    required this.ordersCount,
    required this.sales,
    required this.pipelineCommission,
    required this.pendingApprovalCommission,
    required this.approvedCommission,
    required this.canceledCommission,
    required this.manualAdjustments,
    required this.availableBalance,
    required this.reservedWithdrawals,
    required this.pendingWithdrawalsTotal,
    required this.approvedWithdrawalsTotal,
    required this.paidWithdrawalsTotal,
    required this.deliveredOrders,
    required this.openOrders,
    required this.items,
  });

  factory AmbassadorProgramSummary.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] is Map
        ? Map<String, dynamic>.from(json['summary'] as Map)
        : json;
    return AmbassadorProgramSummary(
      ambassadorCount: asInt(summary['ambassadorCount']),
      ordersCount: asInt(summary['ordersCount']),
      sales: asDouble(summary['sales']),
      pipelineCommission: asDouble(summary['pipelineCommission']),
      pendingApprovalCommission: asDouble(summary['pendingApprovalCommission']),
      approvedCommission: asDouble(summary['approvedCommission']),
      canceledCommission: asDouble(summary['canceledCommission']),
      manualAdjustments: asDouble(summary['manualAdjustments']),
      availableBalance: asDouble(summary['availableBalance']),
      reservedWithdrawals: asDouble(summary['reservedWithdrawals']),
      pendingWithdrawalsTotal: asDouble(summary['pendingWithdrawalsTotal']),
      approvedWithdrawalsTotal: asDouble(summary['approvedWithdrawalsTotal']),
      paidWithdrawalsTotal: asDouble(summary['paidWithdrawalsTotal']),
      deliveredOrders: asInt(summary['deliveredOrders']),
      openOrders: asInt(summary['openOrders']),
      items: json['items'] is List
          ? (json['items'] as List)
                .whereType<Map>()
                .map(
                  (item) => AmbassadorFinanceProfile.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
    );
  }

  final int ambassadorCount;
  final int ordersCount;
  final double sales;
  final double pipelineCommission;
  final double pendingApprovalCommission;
  final double approvedCommission;
  final double canceledCommission;
  final double manualAdjustments;
  final double availableBalance;
  final double reservedWithdrawals;
  final double pendingWithdrawalsTotal;
  final double approvedWithdrawalsTotal;
  final double paidWithdrawalsTotal;
  final int deliveredOrders;
  final int openOrders;
  final List<AmbassadorFinanceProfile> items;
}

class DashboardSummary {
  const DashboardSummary({
    required this.products,
    required this.orders,
    required this.users,
    required this.devices,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) =>
      DashboardSummary(
        products: json['products'] is Map
            ? Map<String, dynamic>.from(json['products'] as Map)
            : {},
        orders: json['orders'] is Map
            ? Map<String, dynamic>.from(json['orders'] as Map)
            : {},
        users: json['users'] is Map
            ? Map<String, dynamic>.from(json['users'] as Map)
            : {},
        devices: json['devices'] is Map
            ? Map<String, dynamic>.from(json['devices'] as Map)
            : {},
      );

  final Map<String, dynamic> products;
  final Map<String, dynamic> orders;
  final Map<String, dynamic> users;
  final Map<String, dynamic> devices;
}

class AdminExpense {
  const AdminExpense({
    required this.id,
    required this.amount,
    required this.category,
    required this.description,
    required this.expenseAtMs,
  });

  factory AdminExpense.fromJson(Map<String, dynamic> json) => AdminExpense(
    id: '${json['id'] ?? ''}',
    amount: asDouble(json['amount']),
    category: '${json['category'] ?? 'other'}',
    description: '${json['description'] ?? ''}',
    expenseAtMs: asInt(json['expenseAtMs']),
  );

  final String id;
  final double amount;
  final String category;
  final String description;
  final int expenseAtMs;
}

class ProductAccountingSummary {
  const ProductAccountingSummary({
    required this.productId,
    required this.name,
    required this.pieces,
    required this.sales,
    required this.cost,
    required this.profit,
  });

  factory ProductAccountingSummary.fromJson(Map<String, dynamic> json) =>
      ProductAccountingSummary(
        productId: '${json['productId'] ?? ''}',
        name: '${json['name'] ?? 'منتج'}',
        pieces: asInt(json['pieces']),
        sales: asDouble(json['sales']),
        cost: asDouble(json['cost']),
        profit: asDouble(json['profit']),
      );

  final String productId;
  final String name;
  final int pieces;
  final double sales;
  final double cost;
  final double profit;
}

class AccountingSummary {
  const AccountingSummary({
    required this.deliveredOrders,
    required this.soldPieces,
    required this.revenue,
    required this.costOfGoods,
    required this.grossProfit,
    required this.ambassadorCommissions,
    required this.approvedAmbassadorCommissions,
    required this.pendingAmbassadorCommissions,
    required this.pipelineAmbassadorCommissions,
    required this.availableAmbassadorBalance,
    required this.reservedWithdrawalBalance,
    required this.ambassadorCount,
    required this.expenses,
    required this.netProfit,
    required this.inventoryPieces,
    required this.inventoryCostValue,
    required this.inventorySaleValue,
    required this.inventoryPotentialProfit,
    required this.missingCostProducts,
    required this.missingCostSoldPieces,
    required this.topProducts,
    required this.topAmbassadors,
  });

  factory AccountingSummary.fromJson(Map<String, dynamic> json) =>
      AccountingSummary(
        deliveredOrders: asInt(json['deliveredOrders']),
        soldPieces: asInt(json['soldPieces']),
        revenue: asDouble(json['revenue']),
        costOfGoods: asDouble(json['costOfGoods']),
        grossProfit: asDouble(json['grossProfit']),
        ambassadorCommissions: asDouble(json['ambassadorCommissions']),
        approvedAmbassadorCommissions: asDouble(
          json['approvedAmbassadorCommissions'],
        ),
        pendingAmbassadorCommissions: asDouble(
          json['pendingAmbassadorCommissions'],
        ),
        pipelineAmbassadorCommissions: asDouble(
          json['pipelineAmbassadorCommissions'],
        ),
        availableAmbassadorBalance: asDouble(
          json['availableAmbassadorBalance'],
        ),
        reservedWithdrawalBalance: asDouble(json['reservedWithdrawalBalance']),
        ambassadorCount: asInt(json['ambassadorCount']),
        expenses: asDouble(json['expenses']),
        netProfit: asDouble(json['netProfit']),
        inventoryPieces: asInt(json['inventoryPieces']),
        inventoryCostValue: asDouble(json['inventoryCostValue']),
        inventorySaleValue: asDouble(json['inventorySaleValue']),
        inventoryPotentialProfit: asDouble(json['inventoryPotentialProfit']),
        missingCostProducts: asInt(json['missingCostProducts']),
        missingCostSoldPieces: asInt(json['missingCostSoldPieces']),
        topProducts: json['topProducts'] is List
            ? (json['topProducts'] as List)
                  .whereType<Map>()
                  .map(
                    (item) => ProductAccountingSummary.fromJson(
                      Map<String, dynamic>.from(item),
                    ),
                  )
                  .toList()
            : const [],
        topAmbassadors: json['topAmbassadors'] is List
            ? (json['topAmbassadors'] as List)
                  .whereType<Map>()
                  .map(
                    (item) => AmbassadorFinanceProfile.fromJson(
                      Map<String, dynamic>.from(item),
                    ),
                  )
                  .toList()
            : const [],
      );

  final int deliveredOrders;
  final int soldPieces;
  final double revenue;
  final double costOfGoods;
  final double grossProfit;
  final double ambassadorCommissions;
  final double approvedAmbassadorCommissions;
  final double pendingAmbassadorCommissions;
  final double pipelineAmbassadorCommissions;
  final double availableAmbassadorBalance;
  final double reservedWithdrawalBalance;
  final int ambassadorCount;
  final double expenses;
  final double netProfit;
  final int inventoryPieces;
  final double inventoryCostValue;
  final double inventorySaleValue;
  final double inventoryPotentialProfit;
  final int missingCostProducts;
  final int missingCostSoldPieces;
  final List<ProductAccountingSummary> topProducts;
  final List<AmbassadorFinanceProfile> topAmbassadors;
}
