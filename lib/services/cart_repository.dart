import 'dart:async';
import 'dart:convert';
import 'package:universal_io/io.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'app_settings.dart';
import 'firebase_auth_service.dart';

class CartItem {
  final String id;

  /// Unique cart line identifier (product + selected options).
  ///
  /// This is used as the primary key in the cart table so the same product can
  /// exist multiple times in the cart with different size/length.
  final String lineId;
  final String name;
  final double price;
  final String? imageUrl;
  final String? category;

  /// Comma-separated tags snapshot at time of adding to cart.
  final String? tags;
  final String? size;
  final String? length;
  final String? color;
  final bool sabilEnabled;
  final String? sabilReferenceCode;
  final double commissionPercent;
  int quantity;

  CartItem({
    required this.id,
    String? lineId,
    required this.name,
    required this.price,
    this.imageUrl,
    this.category,
    this.tags,
    this.size,
    this.length,
    this.color,
    this.sabilEnabled = false,
    this.sabilReferenceCode,
    this.commissionPercent = 0.0,
    this.quantity = 1,
  }) : lineId =
            lineId ?? buildLineId(id, size: size, length: length, color: color);

  factory CartItem.fromProduct(
    Map<String, dynamic> product, {
    String? size,
    String? length,
    String? color,
    int quantity = 1,
  }) {
    return CartItem(
      id: product['id']?.toString() ?? '',
      name: product['name']?.toString() ?? '',
      price: (product['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: product['imageUrl']?.toString(),
      category: product['category']?.toString(),
      tags: product['tags']?.toString(),
      size: size,
      length: length,
      color: color,
      sabilEnabled: product['sabilEnabled'] is bool
          ? (product['sabilEnabled'] as bool)
          : ((product['sabilEnabled'] as num?)?.toInt() ?? 0) != 0,
      sabilReferenceCode:
          (product['sabilReferenceCode'] as String?)?.trim().isEmpty == true
              ? null
              : (product['sabilReferenceCode'] as String?),
      commissionPercent: (product['commissionPercent'] is num)
          ? (product['commissionPercent'] as num).toDouble().clamp(0.0, 100.0)
          : (double.tryParse((product['commissionPercent'] ?? '').toString())
                  ?.clamp(0.0, 100.0) ??
              0.0),
      quantity: quantity,
    );
  }

  static String _normOpt(String? v) {
    final s = (v ?? '').trim();
    return s;
  }

  /// Builds a stable cart line key from product id + options.
  ///
  /// If no options are provided, we intentionally return the product id to keep
  /// backward compatibility and to keep keys short.
  static String buildLineId(
    String productId, {
    String? size,
    String? length,
    String? color,
  }) {
    final s = _normOpt(size);
    final l = _normOpt(length);
    final c = _normOpt(color);
    if (s.isEmpty && l.isEmpty && c.isEmpty) return productId;

    // Use URI encoding to avoid separator collisions.
    final se = Uri.encodeComponent(s);
    final le = Uri.encodeComponent(l);
    final ce = Uri.encodeComponent(c);
    return '$productId|s=$se|l=$le|c=$ce';
  }

  /// Map format used for persisting orders.
  ///
  /// IMPORTANT: keeps `id` as the product id for reporting and UI.
  Map<String, dynamic> toOrderMap() => {
        'id': id,
        'name': name,
        'price': price,
        'imageUrl': imageUrl,
        'category': category,
        'tags': tags,
        'size': size,
        'length': length,
        'color': color,
        'sabilEnabled': sabilEnabled,
        'sabilReferenceCode': sabilReferenceCode,
        'commissionPercent': commissionPercent,
        'quantity': quantity,
      };

  /// Map format used for the local cart SQLite table.
  Map<String, dynamic> toDbMap() => {
        'lineId': lineId,
        'productId': id,
        'name': name,
        'price': price,
        'imageUrl': imageUrl,
        'category': category,
        'tags': tags,
        'size': size,
        'length': length,
        'color': color,
        'sabilEnabled': sabilEnabled ? 1 : 0,
        'sabilReferenceCode': sabilReferenceCode,
        'commissionPercent': commissionPercent,
        'quantity': quantity,
      };

  factory CartItem.fromMap(Map<String, dynamic> m) {
    // Support both v6 schema (id is primary key) and v7+ (lineId/productId).
    final productId = (m['productId'] ?? m['id'] ?? '').toString();
    final size = (m['size'] as String?)?.trim().isEmpty == true
        ? null
        : (m['size'] as String?);
    final length = (m['length'] as String?)?.trim().isEmpty == true
        ? null
        : (m['length'] as String?);
    final color = (m['color'] as String?)?.trim().isEmpty == true
        ? null
        : (m['color'] as String?);
    final rawLineId = (m['lineId'] ?? '').toString().trim();
    final lineId = rawLineId.isNotEmpty
        ? rawLineId
        : buildLineId(productId, size: size, length: length, color: color);

    return CartItem(
      id: productId,
      lineId: lineId,
      name: (m['name'] ?? '').toString(),
      price: (m['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: m['imageUrl'] as String?,
      category: (m['category'] as String?)?.trim().isEmpty == true
          ? null
          : (m['category'] as String?),
      tags: (m['tags'] as String?)?.trim().isEmpty == true
          ? null
          : (m['tags'] as String?),
      size: size,
      length: length,
      color: color,
      sabilEnabled: m['sabilEnabled'] is bool
          ? (m['sabilEnabled'] as bool)
          : ((m['sabilEnabled'] as num?)?.toInt() ?? 0) != 0,
      sabilReferenceCode:
          (m['sabilReferenceCode'] as String?)?.trim().isEmpty == true
              ? null
              : (m['sabilReferenceCode'] as String?),
      commissionPercent: (m['commissionPercent'] is num)
          ? (m['commissionPercent'] as num).toDouble().clamp(0.0, 100.0)
          : (double.tryParse((m['commissionPercent'] ?? '').toString())
                  ?.clamp(0.0, 100.0) ??
              0.0),
      quantity: (m['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}

class CartRepository {
  static final CartRepository _instance = CartRepository._internal();
  factory CartRepository() => _instance;
  CartRepository._internal();

  static const String _fallbackBackendBaseUrl =
      'https://carmenkarla-backend.onrender.com';

  // Keyed by CartItem.lineId (variant-safe).
  final Map<String, CartItem> _items = {};
  final _controller = StreamController<List<CartItem>>.broadcast();
  final _couponsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  Database? _db;
  int _lastCouponsRefreshAtMs = 0;
  Future<void>? _couponsRefreshInFlight;

  StreamSubscription? _authSub;
  String? _uid;

  Future<void> init() async {
    if (_db != null) return;

    // In widget/unit tests, avoid platform channels (path_provider) by using an
    // in-memory database.
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    final useInMemory = isTest || kIsWeb;
    final path = useInMemory
        ? inMemoryDatabasePath
        : join(
            (await getApplicationDocumentsDirectory()).path, 'carmen_cart.db');
    _db = await openDatabase(
      path,
      version: 12,
      // In tests, multiple repositories can open ":memory:". Disable single
      // instance to prevent them from sharing the same in-memory DB.
      singleInstance: !useInMemory,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE cart_items(
          uid TEXT NOT NULL,
          lineId TEXT NOT NULL,
          productId TEXT,
          name TEXT,
          price REAL,
          imageUrl TEXT,
          category TEXT,
          tags TEXT,
          size TEXT,
          length TEXT,
          color TEXT,
          commissionPercent REAL DEFAULT 0,
          quantity INTEGER
          ,sabilEnabled INTEGER DEFAULT 0
          ,sabilReferenceCode TEXT
          ,PRIMARY KEY(uid, lineId)
        )
      ''');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_cart_items_productId ON cart_items(productId)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_cart_items_uid ON cart_items(uid)');
        await db.execute('''
        CREATE TABLE orders(
          orderId TEXT PRIMARY KEY,
          payload TEXT,
          createdAt INTEGER,
          status TEXT DEFAULT 'pending',
          uid TEXT
        )
      ''');

        await db.execute('''
        CREATE TABLE coupons(
          code TEXT PRIMARY KEY,
          type TEXT,
          value REAL,
          minSubtotal REAL,
          maxDiscount REAL,
          freeShipping INTEGER,
          enabled INTEGER,
          startAt INTEGER,
          endAt INTEGER,
          createdAt INTEGER
        )
      ''');

        // Seed some default coupons.
        final now = DateTime.now().millisecondsSinceEpoch;
        await db.insert('coupons', {
          'code': 'CK10',
          'type': 'percent',
          'value': 10.0,
          'minSubtotal': 0.0,
          'maxDiscount': 50.0,
          'freeShipping': 0,
          'enabled': 1,
          'startAt': null,
          'endAt': null,
          'createdAt': now - 3,
        });
        await db.insert('coupons', {
          'code': 'CK20',
          'type': 'percent',
          'value': 20.0,
          'minSubtotal': 200.0,
          'maxDiscount': 80.0,
          'freeShipping': 0,
          'enabled': 1,
          'startAt': null,
          'endAt': null,
          'createdAt': now - 2,
        });
        await db.insert('coupons', {
          'code': 'FREESHIP',
          'type': 'freeShipping',
          'value': 0.0,
          'minSubtotal': 0.0,
          'maxDiscount': 0.0,
          'freeShipping': 1,
          'enabled': 1,
          'startAt': null,
          'endAt': null,
          'createdAt': now - 1,
        });
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS coupons(
              code TEXT PRIMARY KEY,
              type TEXT,
              value REAL,
              minSubtotal REAL,
              maxDiscount REAL,
              freeShipping INTEGER,
              enabled INTEGER,
              startAt INTEGER,
              endAt INTEGER,
              createdAt INTEGER
            )
          ''');

          final cnt = Sqflite.firstIntValue(
                  await db.rawQuery('SELECT COUNT(*) FROM coupons')) ??
              0;
          if (cnt == 0) {
            final now = DateTime.now().millisecondsSinceEpoch;
            await db.insert('coupons', {
              'code': 'CK10',
              'type': 'percent',
              'value': 10.0,
              'minSubtotal': 0.0,
              'maxDiscount': 50.0,
              'freeShipping': 0,
              'enabled': 1,
              'startAt': null,
              'endAt': null,
              'createdAt': now - 3,
            });
            await db.insert('coupons', {
              'code': 'CK20',
              'type': 'percent',
              'value': 20.0,
              'minSubtotal': 200.0,
              'maxDiscount': 80.0,
              'freeShipping': 0,
              'enabled': 1,
              'startAt': null,
              'endAt': null,
              'createdAt': now - 2,
            });
            await db.insert('coupons', {
              'code': 'FREESHIP',
              'type': 'freeShipping',
              'value': 0.0,
              'minSubtotal': 0.0,
              'maxDiscount': 0.0,
              'freeShipping': 1,
              'enabled': 1,
              'startAt': null,
              'endAt': null,
              'createdAt': now - 1,
            });
          }
        }

        if (oldVersion < 3) {
          // Add validity columns safely if upgrading from v2.
          final cols = await db.rawQuery("PRAGMA table_info('coupons')");
          final has = <String>{
            for (final c in cols) (c['name'] as String?) ?? ''
          };
          Future<void> addCol(String sql, String name) async {
            if (has.contains(name)) return;
            try {
              await db.execute(sql);
            } catch (_) {}
          }

          await addCol(
              'ALTER TABLE coupons ADD COLUMN startAt INTEGER', 'startAt');
          await addCol('ALTER TABLE coupons ADD COLUMN endAt INTEGER', 'endAt');
        }

        if (oldVersion < 4) {
          // Add size column for cart items.
          final cols = await db.rawQuery("PRAGMA table_info('cart_items')");
          final has = <String>{
            for (final c in cols) (c['name'] as String?) ?? ''
          };
          if (!has.contains('size')) {
            try {
              await db.execute('ALTER TABLE cart_items ADD COLUMN size TEXT');
            } catch (_) {}
          }
        }

        if (oldVersion < 5) {
          // Add length column for cart items.
          final cols = await db.rawQuery("PRAGMA table_info('cart_items')");
          final has = <String>{
            for (final c in cols) (c['name'] as String?) ?? ''
          };
          if (!has.contains('length')) {
            try {
              await db.execute('ALTER TABLE cart_items ADD COLUMN length TEXT');
            } catch (_) {}
          }
        }

        if (oldVersion < 12) {
          final cols = await db.rawQuery("PRAGMA table_info('cart_items')");
          final has = <String>{
            for (final c in cols) (c['name'] as String?) ?? ''
          };
          if (!has.contains('color')) {
            try {
              await db.execute('ALTER TABLE cart_items ADD COLUMN color TEXT');
            } catch (_) {}
          }
        }

        if (oldVersion < 6) {
          // Add category/tags snapshot columns for cart items.
          final cols = await db.rawQuery("PRAGMA table_info('cart_items')");
          final has = <String>{
            for (final c in cols) (c['name'] as String?) ?? ''
          };
          if (!has.contains('category')) {
            try {
              await db
                  .execute('ALTER TABLE cart_items ADD COLUMN category TEXT');
            } catch (_) {}
          }
          if (!has.contains('tags')) {
            try {
              await db.execute('ALTER TABLE cart_items ADD COLUMN tags TEXT');
            } catch (_) {}
          }
        }

        if (oldVersion < 7) {
          // Migrate cart items to variant-safe primary key (lineId) and keep
          // productId separate.
          try {
            final oldRows = await db.query('cart_items');

            // Rename existing table.
            await db.execute('ALTER TABLE cart_items RENAME TO cart_items_old');

            // Create the new table.
            await db.execute('''
              CREATE TABLE cart_items(
                lineId TEXT PRIMARY KEY,
                productId TEXT,
                name TEXT,
                price REAL,
                imageUrl TEXT,
                category TEXT,
                tags TEXT,
                size TEXT,
                length TEXT,
                quantity INTEGER
              )
            ''');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_cart_items_productId ON cart_items(productId)');

            // Copy rows with computed lineId.
            for (final r in oldRows) {
              final productId = (r['productId'] ?? r['id'] ?? '').toString();
              if (productId.trim().isEmpty) continue;
              final size = (r['size'] as String?)?.trim().isEmpty == true
                  ? null
                  : (r['size'] as String?);
              final length = (r['length'] as String?)?.trim().isEmpty == true
                  ? null
                  : (r['length'] as String?);
              final color = (r['color'] as String?)?.trim().isEmpty == true
                  ? null
                  : (r['color'] as String?);
              final lineId = CartItem.buildLineId(productId,
                  size: size, length: length, color: color);
              await db.insert(
                'cart_items',
                {
                  'lineId': lineId,
                  'productId': productId,
                  'name': (r['name'] ?? '').toString(),
                  'price': (r['price'] as num?)?.toDouble() ?? 0.0,
                  'imageUrl': r['imageUrl'] as String?,
                  'category': (r['category'] as String?)?.trim().isEmpty == true
                      ? null
                      : (r['category'] as String?),
                  'tags': (r['tags'] as String?)?.trim().isEmpty == true
                      ? null
                      : (r['tags'] as String?),
                  'size': size,
                  'length': length,
                  'color': (r['color'] as String?)?.trim().isEmpty == true
                      ? null
                      : (r['color'] as String?),
                  'quantity': (r['quantity'] as num?)?.toInt() ?? 1,
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }

            await db.execute('DROP TABLE cart_items_old');
          } catch (_) {
            // Best-effort; if migration fails, keep the old table.
            try {
              await db
                  .execute('ALTER TABLE cart_items_old RENAME TO cart_items');
            } catch (_) {}
          }
        }

        if (oldVersion < 9) {
          // Add uid scoping to cart items to prevent cross-account leakage.
          // Strategy:
          // - Rebuild `cart_items` with PRIMARY KEY(uid, lineId)
          // - Assign existing rows to the currently signed-in uid if available,
          //   otherwise keep them anonymous (uid = '').
          try {
            final existingRows = await db.query('cart_items');

            final upgradeUid = _currentUidSafe() ?? '';

            await db
                .execute('ALTER TABLE cart_items RENAME TO cart_items_old_v8');
            await db.execute('''
              CREATE TABLE cart_items(
                uid TEXT NOT NULL,
                lineId TEXT NOT NULL,
                productId TEXT,
                name TEXT,
                price REAL,
                imageUrl TEXT,
                category TEXT,
                tags TEXT,
                size TEXT,
                length TEXT,
                quantity INTEGER
                ,PRIMARY KEY(uid, lineId)
              )
            ''');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_cart_items_productId ON cart_items(productId)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_cart_items_uid ON cart_items(uid)');

            for (final r in existingRows) {
              final item = CartItem.fromMap(r);
              final map = <String, dynamic>{
                'uid': upgradeUid,
                ...item.toDbMap(),
              };
              await db.insert(
                'cart_items',
                map,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }

            await db.execute('DROP TABLE cart_items_old_v8');
          } catch (_) {
            // Best-effort.
          }
        }

        if (oldVersion < 10) {
          final cols = await db.rawQuery("PRAGMA table_info('cart_items')");
          final has = <String>{
            for (final c in cols) (c['name'] as String?) ?? ''
          };
          Future<void> addCol(String sql, String name) async {
            if (has.contains(name)) return;
            try {
              await db.execute(sql);
            } catch (_) {}
          }

          await addCol(
              'ALTER TABLE cart_items ADD COLUMN sabilEnabled INTEGER DEFAULT 0',
              'sabilEnabled');
          await addCol(
              'ALTER TABLE cart_items ADD COLUMN sabilReferenceCode TEXT',
              'sabilReferenceCode');
        }

        if (oldVersion < 11) {
          final cols = await db.rawQuery("PRAGMA table_info('cart_items')");
          final has = <String>{
            for (final c in cols) (c['name'] as String?) ?? ''
          };
          Future<void> addCol(String sql, String name) async {
            if (has.contains(name)) return;
            try {
              await db.execute(sql);
            } catch (_) {}
          }

          await addCol(
              'ALTER TABLE cart_items ADD COLUMN commissionPercent REAL DEFAULT 0',
              'commissionPercent');
        }
      },
    );
    // ensure orders schema includes status column for precise tracking
    final cols = await _db!.rawQuery("PRAGMA table_info('orders')");
    final hasStatus = cols.any((c) => (c['name'] as String?) == 'status');
    if (!hasStatus) {
      try {
        await _db!.execute(
            "ALTER TABLE orders ADD COLUMN status TEXT DEFAULT 'pending'");
      } catch (_) {}
    }

    final hasUid = cols.any((c) => (c['name'] as String?) == 'uid');
    if (!hasUid) {
      try {
        await _db!.execute("ALTER TABLE orders ADD COLUMN uid TEXT");
      } catch (_) {}
    }
    await _loadFromDb();
    await _loadCouponsAndEmit();

    // Bind auth changes (Android/iOS only in this app) so each account sees
    // its own cart on the same device.
    if (_cloudSupported) {
      _uid = FirebaseAuthService.instance.currentUser?.uid;
      _authSub ??=
          FirebaseAuthService.instance.authStateChanges().listen((user) async {
        await _bindUser(user?.uid);
      });
      await _bindUser(_uid);
    }
  }

  bool get _localOrdersSyncEnabled {
    final s = AppSettings();
    return s.localCatalogEnabled.value &&
        s.localCatalogBaseUrl.value.trim().isNotEmpty;
  }

  String get _localBaseUrl {
    final raw = AppSettings().localCatalogBaseUrl.value.trim();
    if (raw.endsWith('/')) return raw.substring(0, raw.length - 1);
    return raw;
  }

  Map<String, String> _localHeaders() {
    return <String, String>{'Content-Type': 'application/json'};
  }

  Future<void> _trySyncOrderToLocalServer({
    required String orderId,
    required int createdAtMs,
    required String status,
    required Map<String, dynamic> payload,
  }) async {
    if (!_localOrdersSyncEnabled) return;
    try {
      final uri = Uri.parse('$_localBaseUrl/orders');
      final ambassadorSummary = (payload['ambassadorSummary'] is Map)
          ? Map<String, dynamic>.from(payload['ambassadorSummary'] as Map)
          : const <String, dynamic>{};
      await http
          .post(
            uri,
            headers: _localHeaders(),
            body: jsonEncode({
              'orderId': orderId,
              'createdAtMs': createdAtMs,
              'status': status,
              'uid': _currentUidSafe(),
              'payload': payload,
              'ambassadorSummary': ambassadorSummary,
              'source': 'app',
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<Map<String, String>> getRemoteOrderStatuses({
    String? uid,
    int sinceMs = 0,
  }) async {
    if (!_localOrdersSyncEnabled) return const <String, String>{};
    try {
      final qp = <String, String>{
        'limit': '2000',
        if (sinceMs > 0) 'sinceMs': '$sinceMs',
        if ((uid ?? '').trim().isNotEmpty) 'uid': uid!.trim(),
      };
      final uri = Uri.parse('$_localBaseUrl/orders/statuses')
          .replace(queryParameters: qp);
      final res = await http.get(uri, headers: _localHeaders()).timeout(
            const Duration(seconds: 8),
          );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return const <String, String>{};
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return const <String, String>{};
      final items = decoded['items'];
      if (items is! List) return const <String, String>{};

      final out = <String, String>{};
      for (final raw in items) {
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);
        final id = (m['orderId'] ?? '').toString().trim();
        final st = (m['status'] ?? '').toString().trim();
        if (id.isEmpty || st.isEmpty) continue;
        out[id] = st;
      }
      return out;
    } catch (_) {
      return const <String, String>{};
    }
  }

  Future<int> syncLocalOrderStatusesFromServer({
    String? uid,
    int sinceMs = 0,
  }) async {
    if (!_localOrdersSyncEnabled) return 0;
    if (_db == null) {
      await init();
    }

    final statuses = await getRemoteOrderStatuses(uid: uid, sinceMs: sinceMs);
    if (statuses.isEmpty) return 0;

    var updated = 0;
    await _db!.transaction((txn) async {
      for (final e in statuses.entries) {
        final count = await txn.update(
          'orders',
          {'status': e.value},
          where: 'orderId = ? AND status != ?',
          whereArgs: [e.key, e.value],
        );
        updated += count;
      }
    });
    return updated;
  }

  Future<List<Map<String, dynamic>>> getRemoteOrdersForUser(String uid) async {
    final userUid = uid.trim();
    if (!_localOrdersSyncEnabled || userUid.isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    try {
      final uri = Uri.parse('$_localBaseUrl/orders/feed').replace(
        queryParameters: <String, String>{
          'uid': userUid,
          'limit': '300',
        },
      );
      final res = await http.get(uri, headers: _localHeaders()).timeout(
            const Duration(seconds: 10),
          );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return const <Map<String, dynamic>>[];
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        return const <Map<String, dynamic>>[];
      }
      final items = decoded['items'];
      if (items is! List) return const <Map<String, dynamic>>[];

      final out = <Map<String, dynamic>>[];
      for (final raw in items) {
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);
        final orderId = (m['orderId'] ?? '').toString().trim();
        if (orderId.isEmpty) continue;
        final payload = (m['payload'] is Map)
            ? Map<String, dynamic>.from(m['payload'] as Map)
            : <String, dynamic>{};
        final ambassadorSummary = (m['ambassadorSummary'] is Map)
            ? Map<String, dynamic>.from(m['ambassadorSummary'] as Map)
            : ((payload['ambassadorSummary'] is Map)
                ? Map<String, dynamic>.from(payload['ambassadorSummary'] as Map)
                : <String, dynamic>{});
        out.add({
          'orderId': orderId,
          'createdAt': (m['createdAtMs'] is num)
              ? (m['createdAtMs'] as num).toInt()
              : int.tryParse('${m['createdAtMs']}') ?? 0,
          'payload': payload,
          'ambassadorSummary': ambassadorSummary,
          'status': (m['status'] ?? 'pending').toString(),
          'uid': (m['uid'] ?? '').toString(),
        });
      }
      return out;
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  String _uidKey() => (_uid ?? '').trim();

  Future<void> _bindUser(String? nextUid) async {
    final next = (nextUid ?? '').trim();
    if (next == _uidKey()) {
      // Ensure we still load correctly on first init.
    } else {
      _uid = next.isEmpty ? null : next;
    }

    if (_db == null) return;

    // One-time local migration: if user signs in and their cart is empty but
    // anonymous cart has items, move them to the user.
    final uid = _uidKey();
    if (uid.isNotEmpty) {
      try {
        final userCnt = Sqflite.firstIntValue(await _db!.rawQuery(
                'SELECT COUNT(*) FROM cart_items WHERE uid = ?', [uid])) ??
            0;
        final anonCnt = Sqflite.firstIntValue(await _db!.rawQuery(
                "SELECT COUNT(*) FROM cart_items WHERE uid = ''", const [])) ??
            0;
        if (userCnt == 0 && anonCnt > 0) {
          await _db!.update(
            'cart_items',
            {'uid': uid},
            where: "uid = ''",
          );
        }
      } catch (_) {
        // Ignore.
      }
    }

    await _loadFromDb();
  }

  Future<void> _loadCouponsAndEmit() async {
    await _refreshCouponsIfStale(force: true);
    final rows = await _db!.query('coupons', orderBy: 'createdAt DESC');
    _couponsController.add(rows);
  }

  Future<void> _refreshCouponsIfStale({
    bool force = false,
    Duration maxAge = const Duration(seconds: 20),
  }) async {
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!force && (nowMs - _lastCouponsRefreshAtMs) <= maxAge.inMilliseconds) {
      return;
    }

    final inFlight = _couponsRefreshInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final task = _tryRefreshCouponsFromServer();
    _couponsRefreshInFlight = task;
    try {
      await task;
      _lastCouponsRefreshAtMs = DateTime.now().millisecondsSinceEpoch;
    } finally {
      _couponsRefreshInFlight = null;
    }
  }

  Future<void> _tryRefreshCouponsFromServer() async {
    if (kIsWeb) return;
    final settings = AppSettings();
    try {
      await settings.init();
    } catch (_) {}
    final base = settings.localCatalogBaseUrl.value.trim().isNotEmpty
        ? settings.localCatalogBaseUrl.value.trim()
        : _fallbackBackendBaseUrl;
    if (base.isEmpty) return;

    try {
      final uri = Uri.parse(
          '${base.endsWith('/') ? base.substring(0, base.length - 1) : base}/app/content');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode < 200 || res.statusCode >= 300) return;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return;
      final coupons = decoded['coupons'];
      if (coupons is! List) return;

      await _db!.transaction((txn) async {
        await txn.delete('coupons');
        for (final item in coupons) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          final code = (map['code'] ?? '').toString().trim().toUpperCase();
          if (code.isEmpty) continue;
          map['code'] = code;
          map.putIfAbsent('type', () => 'percent');
          map.putIfAbsent('value', () => 0.0);
          map.putIfAbsent('minSubtotal', () => 0.0);
          map.putIfAbsent('maxDiscount', () => 0.0);
          map.putIfAbsent('freeShipping', () => 0);
          map.putIfAbsent('enabled', () => 1);
          map.putIfAbsent(
              'createdAt', () => DateTime.now().millisecondsSinceEpoch);
          await txn.insert('coupons', map,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    } catch (_) {
      // Best effort only.
    }
  }

  Stream<List<Map<String, dynamic>>> couponsStream() async* {
    if (_db == null) {
      await init();
    }
    yield await _db!.query('coupons', orderBy: 'createdAt DESC');
    yield* _couponsController.stream;
  }

  Future<Map<String, dynamic>?> getCouponByCode(String code) async {
    if (_db == null) {
      await init();
    }
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return null;

    final rows = await _db!
        .query('coupons', where: 'code = ?', whereArgs: [c], limit: 1);
    if (rows.isEmpty) return null;

    final row = Map<String, dynamic>.from(rows.first);
    final enabled = ((row['enabled'] as num?)?.toInt() ?? 1) == 1;
    if (!enabled) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final startAt = (row['startAt'] as num?)?.toInt();
    final endAt = (row['endAt'] as num?)?.toInt();

    if (startAt != null && now < startAt) {
      // Not started yet.
      return null;
    }
    if (endAt != null && now > endAt) {
      // Expired.
      return null;
    }

    return row;
  }

  /// Returns a (row, message) pair for UX.
  /// - row: coupon row if valid & applicable (enabled and within validity dates)
  /// - message: human-readable reason if invalid (expired/not started/disabled/not found)
  Future<({Map<String, dynamic>? row, String? message})> validateCoupon(
      String code) async {
    if (_db == null) {
      await init();
    }
    await _refreshCouponsIfStale();

    final c = code.trim().toUpperCase();
    if (c.isEmpty) return (row: null, message: null);

    var rows = await _db!
        .query('coupons', where: 'code = ?', whereArgs: [c], limit: 1);
    if (rows.isEmpty) {
      await _refreshCouponsIfStale(force: true);
      rows = await _db!
          .query('coupons', where: 'code = ?', whereArgs: [c], limit: 1);
    }

    if (rows.isEmpty) return (row: null, message: 'الكوبون غير موجود');

    final row = Map<String, dynamic>.from(rows.first);
    final enabled = ((row['enabled'] as num?)?.toInt() ?? 1) == 1;
    if (!enabled) return (row: null, message: 'الكوبون غير مفعّل');

    final now = DateTime.now().millisecondsSinceEpoch;
    final startAt = (row['startAt'] as num?)?.toInt();
    final endAt = (row['endAt'] as num?)?.toInt();

    if (startAt != null && now < startAt) {
      final dt = DateTime.fromMillisecondsSinceEpoch(startAt).toLocal();
      return (row: null, message: 'الكوبون يبدأ في: $dt');
    }
    if (endAt != null && now > endAt) {
      final dt = DateTime.fromMillisecondsSinceEpoch(endAt).toLocal();
      return (row: null, message: 'انتهت صلاحية الكوبون في: $dt');
    }

    return (row: row, message: null);
  }

  Future<void> upsertCoupon(Map<String, dynamic> coupon) async {
    if (_db == null) {
      await init();
    }
    final c = Map<String, dynamic>.from(coupon);
    c['code'] = (c['code'] ?? '').toString().trim().toUpperCase();
    c.putIfAbsent('type', () => 'percent');
    c.putIfAbsent('value', () => 0.0);
    c.putIfAbsent('minSubtotal', () => 0.0);
    c.putIfAbsent('maxDiscount', () => 0.0);
    c.putIfAbsent('freeShipping', () => 0);
    c.putIfAbsent('enabled', () => 1);
    c.putIfAbsent('createdAt', () => DateTime.now().millisecondsSinceEpoch);
    await _db!
        .insert('coupons', c, conflictAlgorithm: ConflictAlgorithm.replace);
    await _loadCouponsAndEmit();
  }

  Future<void> deleteCoupon(String code) async {
    if (_db == null) {
      await init();
    }
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return;
    await _db!.delete('coupons', where: 'code = ?', whereArgs: [c]);
    await _loadCouponsAndEmit();
  }

  Future<void> setCouponEnabled(String code, bool enabled) async {
    if (_db == null) {
      await init();
    }
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return;
    await _db!.update('coupons', {'enabled': enabled ? 1 : 0},
        where: 'code = ?', whereArgs: [c]);
    await _loadCouponsAndEmit();
  }

  Stream<List<CartItem>> cartStream() async* {
    if (_db == null) {
      await init();
    }
    // Ensure we always emit the current state when a listener subscribes.
    final rows = await _db!
        .query('cart_items', where: 'uid = ?', whereArgs: [_uidKey()]);
    _items.clear();
    for (final r in rows) {
      final item = CartItem.fromMap(r);
      _items[item.lineId] = item;
    }
    yield _items.values.toList();
    yield* _controller.stream;
  }

  Future<void> _loadFromDb() async {
    final rows = await _db!
        .query('cart_items', where: 'uid = ?', whereArgs: [_uidKey()]);
    _items.clear();
    for (final r in rows) {
      final item = CartItem.fromMap(r);
      _items[item.lineId] = item;
    }
    _controller.add(_items.values.toList());
  }

  Future<void> _upsertItem(CartItem item) async {
    await _db!.insert('cart_items', {'uid': _uidKey(), ...item.toDbMap()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _deleteItem(String lineId) async {
    await _db!.delete('cart_items',
        where: 'uid = ? AND lineId = ?', whereArgs: [_uidKey(), lineId]);
  }

  void _emit() {
    _controller.add(_items.values.toList());
  }

  Future<void> addToCart(CartItem item) async {
    if (_db == null) {
      await init();
    }
    final key = item.lineId;
    if (_items.containsKey(key)) {
      final existing = _items[key]!;
      final nextQty = existing.quantity + item.quantity;

      // Keep existing options (they should match if lineId matches), but allow
      // newer metadata snapshots to fill missing fields.
      final nextCategory = (item.category ?? '').trim().isNotEmpty
          ? item.category
          : existing.category;
      final nextTags =
          (item.tags ?? '').trim().isNotEmpty ? item.tags : existing.tags;

      _items[key] = CartItem(
        id: existing.id,
        lineId: existing.lineId,
        name: existing.name,
        price: existing.price,
        imageUrl: existing.imageUrl,
        category: nextCategory,
        tags: nextTags,
        size: existing.size,
        length: existing.length,
        color: existing.color,
        commissionPercent: existing.commissionPercent,
        quantity: nextQty,
      );
    } else {
      _items[key] = item;
    }
    await _upsertItem(_items[key]!);
    _emit();
  }

  Future<void> removeFromCart(String lineId) async {
    if (_db == null) {
      await init();
    }
    _items.remove(lineId);
    await _deleteItem(lineId);
    _emit();
  }

  Future<void> updateQuantity(String lineId, int qty) async {
    if (_db == null) {
      await init();
    }
    if (_items.containsKey(lineId)) {
      if (qty <= 0) {
        await removeFromCart(lineId);
        return;
      }
      _items[lineId]!.quantity = qty;
      await _upsertItem(_items[lineId]!);
      _emit();
    }
  }

  double total() => _items.values.fold(0.0, (s, e) => s + e.price * e.quantity);

  /// Get current quantity of an item in the cart by lineId
  int currentQuantity(String lineId) {
    return _items[lineId]?.quantity ?? 0;
  }

  /// Check if adding one more unit would exceed available stock
  /// Returns true if we can add one more unit, false if stock limit would be exceeded
  bool canAddOneMore(String lineId, int availableStock) {
    if (availableStock <= 0) return false;
    final currentQty = currentQuantity(lineId);
    return currentQty < availableStock;
  }

  Map<String, dynamic> _buildAmbassadorSummary({
    required Map<String, dynamic> customerInfo,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> pricing,
  }) {
    final role = (customerInfo['accountRole'] ?? '').toString().trim();
    final placedAsAmbassador = customerInfo['placedAsAmbassador'] == true;
    final isAmbassadorOrder =
        placedAsAmbassador || role == AppSettings.roleAmbassador;

    var soldPieces = 0;
    var grossSales = 0.0;
    var commissionTotal = 0.0;

    for (final raw in items) {
      final m = Map<String, dynamic>.from(raw);
      final qty = (m['quantity'] is num)
          ? (m['quantity'] as num).toInt()
          : int.tryParse('${m['quantity']}') ?? 1;
      if (qty <= 0) continue;

      final price = (m['price'] is num)
          ? (m['price'] as num).toDouble()
          : double.tryParse('${m['price']}') ?? 0.0;
      final cp = (m['commissionPercent'] is num)
          ? (m['commissionPercent'] as num).toDouble().clamp(0.0, 100.0)
          : (double.tryParse('${m['commissionPercent']}') ?? 0.0)
              .clamp(0.0, 100.0);

      soldPieces += qty;
      final lineSales = price * qty;
      grossSales += lineSales;
      commissionTotal += lineSales * (cp / 100.0);
    }

    final grandTotal = (pricing['grandTotal'] is num)
        ? (pricing['grandTotal'] as num).toDouble()
        : grossSales;

    return {
      'isAmbassadorOrder': isAmbassadorOrder,
      'placedAsAmbassador': placedAsAmbassador,
      'accountRole': role,
      'submitterUid': (customerInfo['submitterUid'] ?? '').toString(),
      'submitterEmail': (customerInfo['submitterEmail'] ?? '').toString(),
      'soldPieces': soldPieces,
      'grossSales': grossSales,
      'grandTotal': grandTotal,
      'estimatedCommission': commissionTotal,
      'estimatedCommissionPercent':
          grossSales > 0 ? (commissionTotal / grossSales * 100.0) : 0.0,
    };
  }

  /// Returns a snapshot of items currently in memory.
  /// Useful for building UI/notifications before calling [clear].
  List<CartItem> itemsSnapshot() => _items.values.toList();

  Future<void> clear() async {
    if (_db == null) {
      await init();
    }
    _items.clear();
    await _db!.delete('cart_items', where: 'uid = ?', whereArgs: [_uidKey()]);
    _emit();
  }

  /// Deletes local orders created while [uid] was signed in.
  ///
  /// This is used for account deletion on shared devices.
  Future<void> deleteLocalOrdersForUid(String uid) async {
    final u = uid.trim();
    if (u.isEmpty) return;
    if (_db == null) {
      await init();
    }
    await _db!.delete('orders', where: 'uid = ?', whereArgs: [u]);
  }

  Future<String> createOrder(Map<String, dynamic> customerInfo,
      {Map<String, dynamic>? pricing}) async {
    if (_db == null) {
      await init();
    }
    final orderId = DateTime.now().millisecondsSinceEpoch.toString();

    final subtotal = total();
    final normalizedPricing = <String, dynamic>{
      'subtotal': subtotal,
      'shipping': 0.0,
      'discount': 0.0,
      'couponCode': null,
      'grandTotal': subtotal,
    };
    if (pricing != null) {
      normalizedPricing.addAll(pricing);
    }
    final grandTotal =
        (normalizedPricing['grandTotal'] as num?)?.toDouble() ?? subtotal;

    final orderItems = _items.values.map((e) => e.toOrderMap()).toList();
    final ambassadorSummary = _buildAmbassadorSummary(
      customerInfo: customerInfo,
      items: orderItems,
      pricing: normalizedPricing,
    );

    final orderPayload = <String, dynamic>{
      'customer': customerInfo,
      'items': orderItems,
      // Keep legacy field for older UI.
      'total': grandTotal,
      'pricing': normalizedPricing,
      'ambassadorSummary': ambassadorSummary,
    };
    final payload = jsonEncode(orderPayload);

    final createdAtMs = DateTime.now().millisecondsSinceEpoch;

    final uid = _currentUidSafe();
    await _db!.insert('orders', {
      'orderId': orderId,
      'payload': payload,
      'createdAt': createdAtMs,
      'status': 'pending',
      'uid': uid
    });

    // Best-effort: sync orders to Firestore per authenticated user.
    // IMPORTANT: do not block checkout UX on cloud sync.
    unawaited(_trySyncOrderToCloud(
      orderId: orderId,
      createdAtMs: createdAtMs,
      status: 'pending',
      payload: orderPayload,
    ));
    unawaited(_trySyncOrderToLocalServer(
      orderId: orderId,
      createdAtMs: createdAtMs,
      status: 'pending',
      payload: orderPayload,
    ));
    return orderId;
  }

  bool get _cloudSupported => FirebaseAuthService.instance.isSupported;

  String? _currentUidSafe() {
    if (!_cloudSupported) return null;
    try {
      return FirebaseAuthService.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  Future<void> _trySyncOrderToCloud({
    required String orderId,
    required int createdAtMs,
    required String status,
    required Map<String, dynamic> payload,
  }) async {
    final uid = _currentUidSafe();
    if (uid == null) return;
    final ambassadorSummary = (payload['ambassadorSummary'] is Map)
        ? Map<String, dynamic>.from(payload['ambassadorSummary'] as Map)
        : const <String, dynamic>{};
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('orders')
          .doc(orderId)
          .set({
        'orderId': orderId,
        'createdAtMs': createdAtMs,
        'createdAt': FieldValue.serverTimestamp(),
        'status': status,
        'payload': payload,
        'ambassadorSummary': ambassadorSummary,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Mirror for admin dashboard across all users/devices.
      await FirebaseFirestore.instance
          .collection('orders_admin')
          .doc(orderId)
          .set({
        'orderId': orderId,
        'uid': uid,
        'createdAtMs': createdAtMs,
        'createdAt': FieldValue.serverTimestamp(),
        'status': status,
        'payload': payload,
        'ambassadorSummary': ambassadorSummary,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      assert(() {
        debugPrint(
            '[CartRepository] Cloud order sync failed (${e.code}): ${e.message}');
        return true;
      }());
      // Ignore in UI flow: checkout remains local-first.
    } catch (e) {
      assert(() {
        debugPrint('[CartRepository] Cloud order sync failed: $e');
        return true;
      }());
      // Ignore in UI flow: checkout remains local-first.
    }
  }

  Future<List<Map<String, dynamic>>> getOrdersForUserFromCloud(
      String uid) async {
    final qs = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('orders')
        .orderBy('createdAtMs', descending: true)
        .get();

    final out = <Map<String, dynamic>>[];
    for (final d in qs.docs) {
      final data = d.data();
      final payload = (data['payload'] is Map)
          ? Map<String, dynamic>.from(data['payload'] as Map)
          : <String, dynamic>{};
      final ambassadorSummary = (data['ambassadorSummary'] is Map)
          ? Map<String, dynamic>.from(data['ambassadorSummary'] as Map)
          : ((payload['ambassadorSummary'] is Map)
              ? Map<String, dynamic>.from(payload['ambassadorSummary'] as Map)
              : <String, dynamic>{});
      out.add({
        'orderId': (data['orderId'] ?? d.id).toString(),
        'createdAt': (data['createdAtMs'] is num)
            ? (data['createdAtMs'] as num).toInt()
            : int.tryParse('${data['createdAtMs']}') ?? 0,
        'payload': payload,
        'ambassadorSummary': ambassadorSummary,
        'status': (data['status'] ?? 'pending').toString(),
      });
    }
    return out;
  }

  Future<void> updateOrderStatusForUserInCloud(
      String uid, String orderId, String status) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('orders')
        .doc(orderId)
        .set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> cancelCurrentUserOrder(
    String orderId, {
    bool asAmbassador = false,
  }) async {
    final user = FirebaseAuthService.instance.currentUser;
    if (user == null) {
      throw Exception('سجّلي الدخول لإلغاء الطلب');
    }
    final token = (await user.getIdToken() ?? '').trim();
    if (token.isEmpty) {
      throw Exception('تعذر التحقق من الحساب. حاولي تسجيل الدخول مجددًا.');
    }
    final settings = AppSettings();
    final configured = settings.localCatalogBaseUrl.value.trim();
    final base = (configured.isNotEmpty ? configured : _fallbackBackendBaseUrl)
        .replaceFirst(RegExp(r'/$'), '');
    final ownerPath = asAmbassador ? 'ambassadors' : 'customers';
    final response = await http.post(
      Uri.parse(
          '$base/$ownerPath/me/orders/${Uri.encodeComponent(orderId)}/cancel'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 20));
    Map<String, dynamic> payload = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['ok'] == false) {
      throw Exception((payload['error'] ?? 'تعذر إلغاء الطلب الآن').toString());
    }

    if (_db == null) await init();
    await _db!.update(
      'orders',
      {'status': 'canceled'},
      where: 'orderId = ?',
      whereArgs: [orderId],
    );
    if (_cloudSupported) {
      try {
        await updateOrderStatusForUserInCloud(user.uid, orderId, 'canceled');
      } catch (_) {
        // The backend is authoritative; Firestore is only an offline mirror.
      }
    }
  }

  Future<List<Map<String, dynamic>>> getAdminOrdersFromCloud() async {
    final qs = await FirebaseFirestore.instance
        .collection('orders_admin')
        .orderBy('createdAtMs', descending: true)
        .get();

    final out = <Map<String, dynamic>>[];
    for (final d in qs.docs) {
      final data = d.data();
      final payload = (data['payload'] is Map)
          ? Map<String, dynamic>.from(data['payload'] as Map)
          : <String, dynamic>{};
      final ambassadorSummary = (data['ambassadorSummary'] is Map)
          ? Map<String, dynamic>.from(data['ambassadorSummary'] as Map)
          : ((payload['ambassadorSummary'] is Map)
              ? Map<String, dynamic>.from(payload['ambassadorSummary'] as Map)
              : <String, dynamic>{});
      out.add({
        'orderId': (data['orderId'] ?? d.id).toString(),
        'createdAt': (data['createdAtMs'] is num)
            ? (data['createdAtMs'] as num).toInt()
            : int.tryParse('${data['createdAtMs']}') ?? 0,
        'payload': payload,
        'ambassadorSummary': ambassadorSummary,
        'status': (data['status'] ?? 'pending').toString(),
        'uid': (data['uid'] ?? '').toString(),
      });
    }
    return out;
  }

  Future<void> updateAdminOrderStatusInCloud(
    String orderId,
    String status,
  ) async {
    await FirebaseFirestore.instance
        .collection('orders_admin')
        .doc(orderId)
        .set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateAdminOrderCustomerInCloud(
    String orderId,
    Map<String, dynamic> customerUpdates,
  ) async {
    final ref =
        FirebaseFirestore.instance.collection('orders_admin').doc(orderId);
    final snap = await ref.get();
    final data = snap.data() ?? <String, dynamic>{};
    final payload = (data['payload'] is Map)
        ? Map<String, dynamic>.from(data['payload'] as Map)
        : <String, dynamic>{};
    final existingCustomer = (payload['customer'] is Map)
        ? Map<String, dynamic>.from(payload['customer'] as Map)
        : <String, dynamic>{};
    payload['customer'] = {...existingCustomer, ...customerUpdates};

    await ref.set({
      'payload': payload,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> dispose() async {
    await _controller.close();
    await _couponsController.close();
    await _authSub?.cancel();
    await _db?.close();
  }

  Future<List<Map<String, dynamic>>> getOrders() async {
    return getOrdersForLocalUser(uid: null);
  }

  /// Local orders filtered by uid.
  ///
  /// Privacy behavior:
  /// - When [uid] is non-null, we return only orders created while that user
  ///   was signed in.
  /// - When [uid] is null, we return only anonymous orders (uid IS NULL).
  /// - Admin tooling can still query the raw table if needed.
  Future<List<Map<String, dynamic>>> getOrdersForLocalUser(
      {String? uid}) async {
    if (_db == null) {
      await init();
    }
    final rows = await _db!.query(
      'orders',
      where: uid == null ? 'uid IS NULL' : 'uid = ?',
      whereArgs: uid == null ? null : [uid],
      orderBy: 'createdAt DESC',
    );
    final out = <Map<String, dynamic>>[];
    for (final r in rows) {
      final payloadRaw = r['payload'] as String?;
      Map<String, dynamic>? payload;
      try {
        payload = jsonDecode(payloadRaw ?? '{}') as Map<String, dynamic>;
      } catch (_) {
        payload = {'raw': payloadRaw};
      }
      out.add({
        'orderId': r['orderId'],
        'createdAt': r['createdAt'],
        'payload': payload,
        'status': r['status']
      });
    }
    return out;
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    if (_db == null) {
      await init();
    }
    await _db!.update('orders', {'status': status},
        where: 'orderId = ?', whereArgs: [orderId]);
    unawaited(_resyncOrderRowToLocalServer(orderId));
  }

  Future<void> updateOrderCustomer(
      String orderId, Map<String, dynamic> customerUpdates) async {
    if (_db == null) {
      await init();
    }
    final rows = await _db!
        .query('orders', where: 'orderId = ?', whereArgs: [orderId], limit: 1);
    if (rows.isEmpty) return;

    final payloadRaw = rows.first['payload'] as String?;
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(payloadRaw ?? '{}') as Map<String, dynamic>;
    } catch (_) {
      payload = {'raw': payloadRaw};
    }

    final existingCustomer = (payload['customer'] as Map?) != null
        ? Map<String, dynamic>.from(payload['customer'] as Map)
        : <String, dynamic>{};
    final nextCustomer = {...existingCustomer, ...customerUpdates};
    payload['customer'] = nextCustomer;

    await _db!.update(
      'orders',
      {'payload': jsonEncode(payload)},
      where: 'orderId = ?',
      whereArgs: [orderId],
    );
    unawaited(_resyncOrderRowToLocalServer(orderId));
  }

  Future<void> _resyncOrderRowToLocalServer(String orderId) async {
    if (!_localOrdersSyncEnabled) return;
    if (_db == null) {
      await init();
    }

    try {
      final rows = await _db!.query(
        'orders',
        where: 'orderId = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (rows.isEmpty) return;

      final r = rows.first;
      final createdAtMs = (r['createdAt'] is num)
          ? (r['createdAt'] as num).toInt()
          : int.tryParse('${r['createdAt']}') ??
              DateTime.now().millisecondsSinceEpoch;
      final status = (r['status'] ?? 'pending').toString();

      final payloadRaw = (r['payload'] ?? '').toString();
      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(payloadRaw) as Map<String, dynamic>;
      } catch (_) {
        payload = <String, dynamic>{};
      }

      await _trySyncOrderToLocalServer(
        orderId: orderId,
        createdAtMs: createdAtMs,
        status: status,
        payload: payload,
      );
    } catch (_) {
      // Best-effort only.
    }
  }

  /// Aggregates sold quantities per product id from orders payload.
  ///
  /// Notes:
  /// - Orders are stored locally in `orders.payload` as JSON.
  /// - We count quantities from `payload.items[]`.
  /// - By default canceled orders are excluded.
  Future<Map<String, int>> getSoldQuantitiesByProductId(
      {bool excludeCanceled = true}) async {
    if (_db == null) {
      await init();
    }

    final rows = await _db!.query('orders', columns: ['payload', 'status']);
    final out = <String, int>{};

    for (final r in rows) {
      final status = (r['status'] ?? 'pending').toString();
      if (excludeCanceled && status == 'canceled') continue;

      final payloadRaw = (r['payload'] ?? '').toString();
      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(payloadRaw) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }

      final items = (payload['items'] as List?)?.cast<dynamic>() ?? const [];
      for (final it in items) {
        if (it is! Map) continue;
        final m = Map<String, dynamic>.from(it);
        final id = (m['id'] ?? '').toString();
        if (id.trim().isEmpty) continue;

        final qty = (m['quantity'] is num)
            ? (m['quantity'] as num).toInt()
            : int.tryParse((m['quantity'] ?? '1').toString()) ?? 1;
        out[id] = (out[id] ?? 0) + (qty <= 0 ? 0 : qty);
      }
    }

    return out;
  }
}
