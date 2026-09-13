import 'package:carmen_karla_admin/admin_analytics.dart';
import 'package:carmen_karla_admin/admin_api.dart';
import 'package:carmen_karla_admin/admin_models.dart';
import 'package:carmen_karla_admin/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('native admin models', () {
    test('parses product inventory and image gallery', () {
      final product = AdminProduct.fromJson({
        'id': 'p1',
        'name': 'فستان',
        'price': '120.5',
        'purchasePrice': '65.25',
        'commissionPercent': '12.5',
        'imageUrl': 'https://example.com/main.jpg',
        'imageUrls': '["https://example.com/second.jpg"]',
        'sizes': 'S,M,L',
        'sizeQuantities': {'S': 2, 'M': '5', 'L': 3},
      });

      expect(product.price, 120.5);
      expect(product.purchasePrice, 65.25);
      expect(product.commissionPercent, 12.5);
      expect(product.imageUrls, hasLength(2));
      expect(product.sizes, ['S', 'M', 'L']);
      expect(product.availableStock, 10);
    });

    test('uses general stock when no per-size quantities exist', () {
      final product = AdminProduct.fromJson({
        'id': 'p2',
        'name': 'حقيبة',
        'stockQuantity': 17,
      });
      expect(product.availableStock, 17);
    });

    test('clamps invalid product ambassador commission percentages', () {
      expect(
        AdminProduct.fromJson({'commissionPercent': -5}).commissionPercent,
        0,
      );
      expect(
        AdminProduct.fromJson({'commissionPercent': 150}).commissionPercent,
        100,
      );
    });

    test('cleans legacy bracketed sizes and their quantities', () {
      final product = AdminProduct.fromJson({
        'id': 'legacy',
        'sizes': '''["['S'", "'M'", "'L'", "'XL']"]''',
        'sizeQuantities': {"['S'": 2, "'M'": 3, "'L'": 1, "'XL']": 4},
      });

      expect(product.sizes, ['S', 'M', 'L', 'XL']);
      expect(product.sizeQuantities, {'S': 2, 'M': 3, 'L': 1, 'XL': 4});
      expect(product.availableStock, 10);
    });

    test('adds enabled website sections to product category options', () {
      final products = [
        AdminProduct.fromJson({'id': 'p1', 'category': 'تصنيف سابق'}),
      ];
      final options = buildProductCategoryOptions(products, {
        'config': {
          'websiteHome': {
            'categories': [
              {
                'title': 'قسم مرتبط',
                'productCategoryFilter': 'فلتر المنتجات',
                'enabled': true,
                'sortOrder': 2,
              },
              {
                'title': 'قسم بالاسم',
                'productCategoryFilter': '  ',
                'enabled': true,
                'sortOrder': 1,
              },
              {'title': 'قسم معطل', 'enabled': false, 'sortOrder': 0},
              {
                'title': 'عنوان مكرر',
                'productCategoryFilter': 'فلتر المنتجات',
                'enabled': true,
                'sortOrder': 3,
              },
            ],
          },
        },
      });

      expect(options[0].label, 'قسم بالاسم');
      expect(options[0].value, 'قسم بالاسم');
      expect(options[1].label, 'قسم مرتبط');
      expect(options[1].value, 'فلتر المنتجات');
      expect(
        options.where((option) => option.value == 'فلتر المنتجات'),
        hasLength(1),
      );
      expect(options.any((option) => option.label == 'قسم معطل'), isFalse);
      expect(options.any((option) => option.value == 'تصنيف سابق'), isTrue);
    });

    test('recognizes ambassador order payloads', () {
      final order = AdminOrder.fromJson({
        'orderId': 'o1',
        'payload': {
          'customer': {'placedAsAmbassador': true},
        },
      });
      expect(order.isAmbassador, isTrue);
    });

    test('separates line count from total purchased pieces', () {
      final order = AdminOrder.fromJson({
        'orderId': 'o2',
        'payload': {
          'items': [
            {'name': 'فستان', 'quantity': 3, 'price': 100},
            {'name': 'حقيبة', 'quantity': 2, 'price': 50},
          ],
          'pricing': {'grandTotal': 400},
        },
      });

      expect(order.lines, hasLength(2));
      expect(order.totalPieces, 5);
      expect(order.effectiveTotal, 400);
    });

    test('parses Darb Al Sabeel shipment tracking state', () {
      final created = AdminOrder.fromJson({
        'orderId': 'delivery-1',
        'externalDelivery': {
          'provider': 'darb_sabeel',
          'status': 'created',
          'shipmentId': 'shipment-7',
          'trackingNumber': 'TRACK-7',
        },
      });
      final failed = AdminOrder.fromJson({
        'orderId': 'delivery-2',
        'externalDelivery': {'status': 'failed', 'lastError': 'تعذر الاتصال'},
      });

      expect(created.hasCreatedShipment, isTrue);
      expect(created.trackingNumber, 'TRACK-7');
      expect(failed.hasCreatedShipment, isFalse);
      expect(failed.deliveryError, 'تعذر الاتصال');
    });

    test('calculates per-product ambassador commission like website', () {
      final order = AdminOrder.fromJson({
        'orderId': 'o3',
        'status': 'delivered',
        'payload': {
          'customer': {
            'placedAsAmbassador': true,
            'submitterUid': 'amb-1',
            'submitterName': 'سارة',
          },
          'items': [
            {
              'name': 'فستان',
              'quantity': 2,
              'price': 100,
              'commissionPercent': 10,
            },
          ],
        },
      });

      expect(order.commission(defaultPercent: 7, perProductEnabled: true), 20);
      expect(order.commission(defaultPercent: 7, perProductEnabled: false), 14);
    });

    test('aggregates each ambassador into a separate precise profile', () {
      AdminOrder order(String id, String uid, int quantity) =>
          AdminOrder.fromJson({
            'orderId': id,
            'status': 'delivered',
            'payload': {
              'customer': {
                'placedAsAmbassador': true,
                'submitterUid': uid,
                'submitterName': uid == 'a1' ? 'سارة' : 'مريم',
              },
              'items': [
                {'name': 'منتج', 'quantity': quantity, 'price': 10},
              ],
              'pricing': {'grandTotal': quantity * 10},
            },
          });

      final profiles = buildAmbassadorProfiles(
        [order('1', 'a1', 2), order('2', 'a1', 3), order('3', 'a2', 4)],
        defaultPercent: 7,
        perProductEnabled: true,
      );

      expect(profiles, hasLength(2));
      expect(profiles.firstWhere((item) => item.uid == 'a1').pieces, 5);
      expect(profiles.firstWhere((item) => item.uid == 'a2').pieces, 4);
    });

    test('includes registered ambassador before first order', () {
      final profiles = buildAmbassadorProfiles(
        const [],
        defaultPercent: 7,
        perProductEnabled: true,
        registeredProfiles: const [
          {
            'uid': 'new-ambassador',
            'ambassadorName': 'مريم',
            'ambassadorPhone': '0912345678',
            'ambassadorAddress': 'طرابلس',
            'email': 'maryam@example.com',
            'status': 'active',
            'joinedAt': 123,
          },
        ],
      );

      expect(profiles, hasLength(1));
      expect(profiles.single.name, 'مريم');
      expect(profiles.single.ordersCount, 0);
      expect(profiles.single.address, 'طرابلس');
      expect(profiles.single.status, 'active');
      expect(profiles.single.joinedAtMs, 123);
    });

    test('parses ambassador withdrawal and exposes safe transitions', () {
      final withdrawal = AmbassadorWithdrawalRequest.fromJson({
        'id': 'w1',
        'ambassadorUid': 'amb-1',
        'ambassadorName': 'سارة',
        'ambassadorPhone': '0912345678',
        'amount': '125.75',
        'status': 'pending',
        'createdAtMs': 1000,
        'updatedAtMs': 2000,
      });

      expect(withdrawal.amount, 125.75);
      expect(withdrawal.statusLabel, 'قيد المراجعة');
      expect(withdrawal.allowedNextStatuses, ['approved', 'rejected']);
    });

    test('withdrawal status flow prevents invalid direct payment', () {
      AmbassadorWithdrawalRequest request(String status) =>
          AmbassadorWithdrawalRequest.fromJson({'id': 'w1', 'status': status});

      expect(request('pending').allowedNextStatuses, isNot(contains('paid')));
      expect(request('approved').allowedNextStatuses, ['paid', 'rejected']);
      expect(request('paid').allowedNextStatuses, isEmpty);
      expect(request('rejected').allowedNextStatuses, isEmpty);
    });

    test('parses precise accounting and inventory totals', () {
      final summary = AccountingSummary.fromJson({
        'deliveredOrders': 4,
        'soldPieces': 7,
        'revenue': 1000,
        'costOfGoods': 400,
        'grossProfit': 600,
        'ambassadorCommissions': 50,
        'expenses': 100,
        'netProfit': 450,
        'inventoryPieces': 20,
        'inventoryCostValue': 800,
        'inventorySaleValue': 2000,
        'inventoryPotentialProfit': 1200,
        'missingCostProducts': 1,
        'missingCostSoldPieces': 2,
        'topProducts': [
          {
            'productId': 'p1',
            'name': 'فستان',
            'pieces': 3,
            'sales': 300,
            'cost': 120,
            'profit': 180,
          },
        ],
      });

      expect(summary.netProfit, 450);
      expect(summary.inventoryPotentialProfit, 1200);
      expect(summary.topProducts.single.profit, 180);
      expect(summary.missingCostProducts, 1);
    });
  });

  testWidgets('renders a native Flutter administration shell', (tester) async {
    await tester.pumpWidget(const CarmenKarlaAdminApp());
    expect(find.text('CARMEN KARLA'), findsOneWidget);
    expect(find.byType(NativeAdminShell), findsOneWidget);
    expect(find.text('منتج جديد'), findsOneWidget);
  });
}
