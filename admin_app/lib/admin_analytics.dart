import 'admin_models.dart';

Map<String, dynamic> mapValue(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

String textValue(Object? value) {
  final valueText = '${value ?? ''}'.trim();
  return valueText == 'null' ? '' : valueText;
}

class OrderLine {
  const OrderLine({
    required this.productId,
    required this.code,
    required this.name,
    required this.imageUrl,
    required this.size,
    required this.color,
    required this.quantity,
    required this.unitPrice,
    required this.commissionPercent,
  });

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
    productId: textValue(json['id'] ?? json['productId']),
    code: textValue(json['productCode'] ?? json['code']),
    name:
        textValue(json['name'] ?? json['productName'] ?? json['title']).isEmpty
        ? 'منتج'
        : textValue(json['name'] ?? json['productName'] ?? json['title']),
    imageUrl: textValue(json['imageUrl']),
    size: textValue(json['size']),
    color: textValue(json['color']),
    quantity: asInt(json['quantity'] ?? json['qty'], 1).clamp(1, 999999),
    unitPrice: asDouble(
      json['price'] ??
          json['unitPrice'] ??
          json['salePrice'] ??
          json['finalPrice'],
    ),
    commissionPercent: asDouble(json['commissionPercent']),
  );

  final String productId;
  final String code;
  final String name;
  final String imageUrl;
  final String size;
  final String color;
  final int quantity;
  final double unitPrice;
  final double commissionPercent;

  double get lineTotal => unitPrice * quantity;
}

extension AdminOrderDetails on AdminOrder {
  Map<String, dynamic> get customer => mapValue(payload['customer']);
  Map<String, dynamic> get pricing => mapValue(payload['pricing']);
  Map<String, dynamic> get nestedAmbassadorSummary =>
      mapValue(payload['ambassadorSummary']);
  Map<String, dynamic> get commissionState => commissionInfo;

  Map<String, dynamic> get effectiveAmbassadorSummary =>
      ambassadorSummary.isNotEmpty
      ? ambassadorSummary
      : nestedAmbassadorSummary;

  List<OrderLine> get lines {
    final raw = payload['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => OrderLine.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  int get totalPieces => lines.fold(0, (sum, item) => sum + item.quantity);

  double get effectiveTotal {
    if (grandTotal > 0) return grandTotal;
    final summary = effectiveAmbassadorSummary;
    return asDouble(
      pricing['grandTotal'] ??
          payload['grandTotal'] ??
          payload['total'] ??
          payload['totalLyd'] ??
          summary['grandTotal'],
    );
  }

  String get buyerName => customerName.isNotEmpty
      ? customerName
      : (textValue(customer['name']).isEmpty
            ? 'عميل غير محدد'
            : textValue(customer['name']));
  String get buyerPhone =>
      customerPhone.isNotEmpty ? customerPhone : textValue(customer['phone']);
  String get buyerEmail => textValue(customer['email']);
  String get buyerAddress => textValue(customer['address']);
  String get buyerCity => textValue(customer['city']);
  String get buyerUid => textValue(customer['uid']);

  String get ambassadorUid => textValue(
    effectiveAmbassadorSummary['ambassadorUid'] ??
        customer['submitterUid'] ??
        customer['uid'],
  );
  String get ambassadorEmail => textValue(
    effectiveAmbassadorSummary['ambassadorEmail'] ?? customer['submitterEmail'],
  );
  String get ambassadorPhone => textValue(
    effectiveAmbassadorSummary['ambassadorPhone'] ??
        customer['submitterPhone'] ??
        customer['accountPhone'],
  );
  String get ambassadorName {
    final explicit = textValue(
      effectiveAmbassadorSummary['ambassadorName'] ??
          customer['submitterName'] ??
          customer['accountName'],
    );
    if (explicit.isNotEmpty) return explicit;
    if (ambassadorEmail.isNotEmpty) return ambassadorEmail.split('@').first;
    return 'مندوبة غير محددة';
  }

  String get ambassadorKey {
    if (ambassadorUid.isNotEmpty) return 'uid:$ambassadorUid';
    if (ambassadorEmail.isNotEmpty) return 'email:$ambassadorEmail';
    if (ambassadorPhone.isNotEmpty) return 'phone:$ambassadorPhone';
    return 'name:$ambassadorName';
  }

  String get commissionStatus => textValue(commissionState['status']);
  double get commissionBaseAmount => asDouble(commissionState['baseAmount']);
  double get commissionApprovedAmount => asDouble(
    commissionState['approvedAmount'],
  );
  String get commissionNote => textValue(commissionState['note']);

  double commission({
    required double defaultPercent,
    required bool perProductEnabled,
  }) {
    final summary = effectiveAmbassadorSummary;
    var value = asDouble(summary['estimatedCommission']);
    if (value > 0) return value;
    final gross = asDouble(summary['grossSales']);
    final percent = asDouble(summary['commissionPercent']);
    if (gross > 0 && percent > 0) return gross * percent.clamp(0, 100) / 100;
    value = lines.fold(0, (sum, item) {
      final percent = perProductEnabled && item.commissionPercent > 0
          ? item.commissionPercent
          : defaultPercent;
      return sum + item.lineTotal * percent.clamp(0, 100) / 100;
    });
    if (value > 0) return value;
    return effectiveTotal * defaultPercent.clamp(0, 100) / 100;
  }
}

class AmbassadorProfile {
  AmbassadorProfile({
    required this.key,
    required this.name,
    required this.uid,
    required this.email,
    required this.phone,
    required this.orders,
    required this.defaultPercent,
    required this.perProductEnabled,
    this.address = '',
    this.lastSeenMs = 0,
    this.status = 'active',
    this.joinedAtMs = 0,
  });

  final String key;
  final String name;
  final String uid;
  final String email;
  final String phone;
  final List<AdminOrder> orders;
  final double defaultPercent;
  final bool perProductEnabled;
  final String address;
  final int lastSeenMs;
  final String status;
  final int joinedAtMs;

  int get ordersCount => orders.length;
  int get pieces => orders
      .where(
        (order) =>
            !{'canceled', 'returning', 'returned'}.contains(order.status),
      )
      .fold(0, (sum, order) => sum + order.totalPieces);
  int get deliveredOrders =>
      orders.where((order) => order.status == 'delivered').length;
  int get canceledOrders => orders
      .where((order) => {'canceled', 'returned'}.contains(order.status))
      .length;
  int get openOrders => ordersCount - deliveredOrders - canceledOrders;
  double get sales => orders
      .where(
        (order) =>
            !{'canceled', 'returning', 'returned'}.contains(order.status),
      )
      .fold(0, (sum, order) => sum + order.effectiveTotal);
  double get deliveredCommission => orders
      .where((order) => order.status == 'delivered')
      .fold(
        0,
        (sum, order) =>
            sum +
            order.commission(
              defaultPercent: defaultPercent,
              perProductEnabled: perProductEnabled,
            ),
      );
  double get pendingCommission => orders
      .where(
        (order) =>
            order.status != 'delivered' &&
            !{'canceled', 'returning', 'returned'}.contains(order.status),
      )
      .fold(
        0,
        (sum, order) =>
            sum +
            order.commission(
              defaultPercent: defaultPercent,
              perProductEnabled: perProductEnabled,
            ),
      );
  double get averageOrder => ordersCount == 0 ? 0 : sales / ordersCount;
  double get deliveryRate =>
      ordersCount == 0 ? 0 : deliveredOrders * 100 / ordersCount;
  int get lastOrderMs => orders.fold(
    0,
    (last, order) => order.createdAtMs > last ? order.createdAtMs : last,
  );
}

List<AmbassadorProfile> buildAmbassadorProfiles(
  List<AdminOrder> orders, {
  required double defaultPercent,
  required bool perProductEnabled,
  List<Map<String, dynamic>> devicePresence = const [],
  List<Map<String, dynamic>> registeredProfiles = const [],
}) {
  final grouped = <String, List<AdminOrder>>{};
  for (final order in orders.where((order) => order.isAmbassador)) {
    grouped.putIfAbsent(order.ambassadorKey, () => []).add(order);
  }
  final profiles = grouped.entries.map((entry) {
    final sorted = [...entry.value]
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    final first = sorted.first;
    final presence = devicePresence
        .where(
          (item) =>
              first.ambassadorUid.isNotEmpty &&
              textValue(item['uid']) == first.ambassadorUid,
        )
        .fold<Map<String, dynamic>>(
          {},
          (latest, item) =>
              asInt(item['lastSeenMs']) > asInt(latest['lastSeenMs'])
              ? item
              : latest,
        );
    return AmbassadorProfile(
      key: entry.key,
      name: first.ambassadorName,
      uid: first.ambassadorUid,
      email: first.ambassadorEmail,
      phone: first.ambassadorPhone.isNotEmpty
          ? first.ambassadorPhone
          : textValue(presence['ambassadorPhone']),
      address: textValue(presence['ambassadorAddress']),
      lastSeenMs: asInt(presence['lastSeenMs']),
      orders: sorted,
      defaultPercent: defaultPercent,
      perProductEnabled: perProductEnabled,
    );
  }).toList();
  for (final registered in registeredProfiles) {
    final uid = textValue(registered['uid']);
    final email = textValue(registered['email']);
    final phone = textValue(
      registered['ambassadorPhone'] ?? registered['phone'],
    );
    final matchIndex = profiles.indexWhere(
      (profile) =>
          (uid.isNotEmpty && profile.uid == uid) ||
          (email.isNotEmpty && profile.email == email) ||
          (phone.isNotEmpty && profile.phone == phone),
    );
    final existing = matchIndex >= 0 ? profiles[matchIndex] : null;
    final registeredName = textValue(registered['ambassadorName']);
    final registeredAddress = textValue(registered['ambassadorAddress']);
    final merged = AmbassadorProfile(
      key: uid.isNotEmpty ? 'uid:$uid' : existing?.key ?? 'email:$email',
      name: registeredName.isNotEmpty
          ? registeredName
          : existing?.name ?? 'مندوبة جديدة',
      uid: uid.isNotEmpty ? uid : existing?.uid ?? '',
      email: email.isNotEmpty ? email : existing?.email ?? '',
      phone: phone.isNotEmpty ? phone : existing?.phone ?? '',
      address: registeredAddress.isNotEmpty
          ? registeredAddress
          : existing?.address ?? '',
      lastSeenMs: existing?.lastSeenMs ?? 0,
      status: textValue(registered['status']).isNotEmpty
          ? textValue(registered['status'])
          : existing?.status ?? 'active',
      joinedAtMs: asInt(registered['joinedAt'], existing?.joinedAtMs ?? 0),
      orders: existing?.orders ?? const [],
      defaultPercent: defaultPercent,
      perProductEnabled: perProductEnabled,
    );
    if (matchIndex >= 0) {
      profiles[matchIndex] = merged;
    } else {
      profiles.add(merged);
    }
  }
  profiles.sort((a, b) => b.sales.compareTo(a.sales));
  return profiles;
}

class DeviceRecord {
  const DeviceRecord({required this.raw});
  final Map<String, dynamic> raw;
  String get id => textValue(raw['installationId'] ?? raw['deviceId']);
  String get platform => textValue(raw['platform']);
  String get type => textValue(raw['deviceType']);
  String get brand => textValue(raw['brand'] ?? raw['manufacturer']);
  String get model =>
      textValue(raw['model'] ?? raw['device'] ?? raw['product']);
  String get os => textValue(raw['osVersion'] ?? raw['systemName']);
  String get app => textValue(raw['appVersion']);
  String get build => textValue(raw['appBuild']);
  String get locale => textValue(raw['locale']);
  String get uid => textValue(raw['uid']);
  String get role => textValue(raw['accountRole']).isEmpty
      ? 'customer'
      : textValue(raw['accountRole']);
  String get ambassadorName => textValue(raw['ambassadorName']);
  String get ambassadorPhone => textValue(raw['ambassadorPhone']);
  String get ambassadorAddress => textValue(raw['ambassadorAddress']);
  String get ip => textValue(raw['lastIp']);
  String get event => textValue(raw['lastEvent']);
  int get firstSeenMs => asInt(raw['firstSeenMs']);
  int get lastSeenMs => asInt(raw['lastSeenMs']);
  int get seenCount => asInt(raw['seenCount']);
  bool get isAmbassador =>
      asBool(raw['isAmbassador']) || role.toLowerCase() == 'ambassador';
}

String formatDateTime(int milliseconds) {
  if (milliseconds <= 0) return 'غير متوفر';
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} • ${two(date.hour)}:${two(date.minute)}';
}
