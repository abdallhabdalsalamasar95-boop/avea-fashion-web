import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import 'admin_models.dart';

class AdminApiException implements Exception {
  const AdminApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class UploadProgress {
  const UploadProgress({
    required this.completed,
    required this.total,
    required this.fileName,
  });
  final int completed;
  final int total;
  final String fileName;
}

class ProductCategoryOption {
  const ProductCategoryOption({required this.label, required this.value});

  final String label;
  final String value;
}

List<ProductCategoryOption> buildProductCategoryOptions(
  List<AdminProduct> products,
  Map<String, dynamic> marketingEnvelope,
) {
  const websiteCategories = [
    'قسم السهرة',
    'قسم ناعمة وانيقة',
    'قسم رمضان',
    'قسم الاكثر طلبا',
    'قسم جمبسوت',
    'قسم الحوامل',
    'قسم العيد',
  ];
  final config = marketingEnvelope['config'] is Map
      ? Map<String, dynamic>.from(marketingEnvelope['config'] as Map)
      : marketingEnvelope;
  final websiteHome = config['websiteHome'] is Map
      ? Map<String, dynamic>.from(config['websiteHome'] as Map)
      : <String, dynamic>{};
  final managedCategories = websiteHome['categories'] is List
      ? (websiteHome['categories'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => item['enabled'] != false)
            .toList()
      : <Map<String, dynamic>>[];
  managedCategories.sort(
    (a, b) => asInt(a['sortOrder']).compareTo(asInt(b['sortOrder'])),
  );

  final options = <ProductCategoryOption>[];
  final seenValues = <String>{};
  void add(String label, String value) {
    final normalizedLabel = label.trim();
    final normalizedValue = value.trim();
    if (normalizedLabel.isEmpty ||
        normalizedValue.isEmpty ||
        !seenValues.add(normalizedValue)) {
      return;
    }
    options.add(
      ProductCategoryOption(label: normalizedLabel, value: normalizedValue),
    );
  }

  for (final item in managedCategories) {
    final title = '${item['title'] ?? ''}'.trim();
    final filter = '${item['productCategoryFilter'] ?? ''}'.trim();
    add(title, filter.isEmpty ? title : filter);
  }
  for (final category in websiteCategories) {
    add(category, category);
  }
  for (final product in products) {
    add(product.category, product.category);
  }
  return options;
}

class AdminApi {
  AdminApi._();
  static final AdminApi instance = AdminApi._();

  static const defaultBaseUrl = 'https://carmenkarla-backend.onrender.com';
  static const defaultToken = 'ck_9f6e3b42d14a4c4f8ea8a4fb6f6f0e11';

  String baseUrl = defaultBaseUrl;
  String token = defaultToken;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Map<String, String> _headers({bool json = true}) => {
    if (json) 'Content-Type': 'application/json',
    if (token.trim().isNotEmpty) 'Authorization': 'Bearer ${token.trim()}',
  };

  Future<Map<String, dynamic>> _decode(http.Response response) async {
    Map<String, dynamic> body = {};
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['ok'] == false) {
      final fallback = response.statusCode == 401
          ? 'رمز الإدارة غير صحيح'
          : 'تعذر الاتصال بالخادم (${response.statusCode})';
      throw AdminApiException(
        '${body['error'] ?? body['message'] ?? fallback}',
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    final response = await http
        .get(
          _uri(path, query),
          headers: authenticated ? _headers(json: false) : const {},
        )
        .timeout(const Duration(seconds: 30));
    return _decode(response);
  }

  Future<Map<String, dynamic>> send(
    String method,
    String path, [
    Map<String, dynamic>? payload,
  ]) async {
    final body = payload == null ? null : jsonEncode(payload);
    final response = switch (method) {
      'POST' => await http.post(_uri(path), headers: _headers(), body: body),
      'PUT' => await http.put(_uri(path), headers: _headers(), body: body),
      'DELETE' => await http.delete(
        _uri(path),
        headers: _headers(),
        body: body,
      ),
      _ => throw ArgumentError.value(method, 'method'),
    };
    return _decode(response);
  }

  Future<bool> health() async {
    final result = await get('/health', authenticated: false);
    return result['ok'] == true;
  }

  Future<DashboardSummary> dashboardSummary() async =>
      DashboardSummary.fromJson(await get('/dashboard/summary'));

  Future<List<AdminProduct>> products() async {
    final data = await get('/products', query: const {'includeHidden': '1'});
    final items = data['items'];
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((item) => AdminProduct.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<ProductCategoryOption>> productCategoryOptions() async {
    final results = await Future.wait([products(), marketingConfig()]);
    return buildProductCategoryOptions(
      results[0] as List<AdminProduct>,
      results[1] as Map<String, dynamic>,
    );
  }

  Future<AdminProduct> saveProduct(
    Map<String, dynamic> payload, {
    String? id,
  }) async {
    final result = await send(
      id == null ? 'POST' : 'PUT',
      id == null ? '/products' : '/products/$id',
      payload,
    );
    return AdminProduct.fromJson(
      Map<String, dynamic>.from(result['item'] as Map),
    );
  }

  Future<void> deleteProduct(String id) async =>
      send('DELETE', '/products/$id');

  Future<void> setProductHidden(AdminProduct product, bool hidden) async =>
      send('PUT', '/products/${product.id}', {'isHidden': hidden ? 1 : 0});

  Future<String> uploadImage(PlatformFile file) async {
    final hasPath = file.path != null && file.path!.isNotEmpty;
    final hasBytes = file.bytes != null && file.bytes!.isNotEmpty;
    if (!hasPath && !hasBytes) {
      throw const AdminApiException('تعذر قراءة الصورة من الهاتف');
    }
    final rawExtension = (file.extension ?? 'jpg').toLowerCase();
    final extension = RegExp(r'^[a-z0-9]{2,5}$').hasMatch(rawExtension)
        ? rawExtension
        : 'jpg';
    final safeName =
        'product_${DateTime.now().millisecondsSinceEpoch}.$extension';
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final request = http.MultipartRequest('POST', _uri('/products/upload'));
        request.headers.addAll(_headers(json: false));
        request.files.add(
          hasPath
              ? await http.MultipartFile.fromPath(
                  'image',
                  file.path!,
                  filename: safeName,
                )
              : http.MultipartFile.fromBytes(
                  'image',
                  file.bytes!,
                  filename: safeName,
                ),
        );
        final streamed = await request.send().timeout(
          const Duration(seconds: 60),
        );
        final response = await http.Response.fromStream(streamed);
        final body = await _decode(response);
        final url = body['url'] is String ? (body['url'] as String).trim() : '';
        if (url.isEmpty) {
          throw const AdminApiException('الخادم لم يرجع رابط الصورة');
        }
        return url;
      } catch (error) {
        lastError = error;
        if (attempt < 3)
          await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    throw AdminApiException('فشل رفع الصورة: $lastError');
  }

  Future<List<String>> uploadImages(
    List<PlatformFile> files, {
    void Function(UploadProgress progress)? onProgress,
  }) async {
    final urls = <String>[];
    for (var index = 0; index < files.length; index++) {
      onProgress?.call(
        UploadProgress(
          completed: index,
          total: files.length,
          fileName: files[index].name,
        ),
      );
      urls.add(await uploadImage(files[index]));
    }
    onProgress?.call(
      UploadProgress(
        completed: files.length,
        total: files.length,
        fileName: '',
      ),
    );
    return urls;
  }

  Future<List<AdminOrder>> orders({String? status}) async {
    final query = <String, String>{
      'limit': '1000',
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final data = await get('/orders', query: query);
    final items = data['items'];
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((item) => AdminOrder.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> updateOrderStatus(String id, String status) async =>
      send('PUT', '/orders/$id/status', {'status': status});

  Future<Map<String, dynamic>> darbSabeelStatus() async {
    final result = await get('/admin/delivery/darb-sabeel/status');
    return result['config'] is Map
        ? Map<String, dynamic>.from(result['config'] as Map)
        : const {};
  }

  Future<AdminOrder> sendOrderToDarbSabeel(
    String id, {
    bool force = false,
  }) async {
    final result = await send('POST', '/orders/$id/delivery/darb-sabeel', {
      'force': force,
    });
    if (result['item'] is! Map) {
      throw const AdminApiException('الخادم لم يرجع بيانات الطلب المحدثة');
    }
    return AdminOrder.fromJson(
      Map<String, dynamic>.from(result['item'] as Map),
    );
  }

  Future<List<Map<String, dynamic>>> ambassadors() async {
    Map<String, dynamic> data;
    try {
      data = await get('/admin/ambassadors');
    } on AdminApiException catch (error) {
      if (error.statusCode == 404) return [];
      rethrow;
    }
    final items = data['items'];
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<AmbassadorWithdrawalRequest>> ambassadorWithdrawals() async {
    final data = await get('/admin/ambassador-withdrawals');
    final items = data['items'];
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map(
          (item) => AmbassadorWithdrawalRequest.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<void> updateWithdrawalStatus(String id, String status) async => send(
    'PUT',
    '/admin/ambassador-withdrawals/$id/status',
    {'status': status},
  );

  Future<AccountingSummary> accountingSummary({
    int fromMs = 0,
    int toMs = 0,
  }) async {
    final result = await get(
      '/admin/accounting/summary',
      query: {
        if (fromMs > 0) 'fromMs': '$fromMs',
        if (toMs > 0) 'toMs': '$toMs',
      },
    );
    return AccountingSummary.fromJson(
      result['summary'] is Map
          ? Map<String, dynamic>.from(result['summary'] as Map)
          : const {},
    );
  }

  Future<List<AdminExpense>> expenses() async {
    final result = await get('/admin/expenses');
    final items = result['items'];
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((item) => AdminExpense.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<AdminExpense> addExpense({
    required double amount,
    required String category,
    required String description,
    required int expenseAtMs,
  }) async {
    final result = await send('POST', '/admin/expenses', {
      'amount': amount,
      'category': category,
      'description': description,
      'expenseAtMs': expenseAtMs,
    });
    return AdminExpense.fromJson(
      Map<String, dynamic>.from(result['item'] as Map),
    );
  }

  Future<void> deleteExpense(String id) async =>
      send('DELETE', '/admin/expenses/$id');

  Future<Map<String, dynamic>> deviceStats() =>
      get('/devices/stats', query: const {'days': '30', 'limit': '1000'});

  Future<Map<String, dynamic>> marketingConfig() => get('/marketing/config');

  Future<Map<String, dynamic>> saveMarketingConfig(
    Map<String, dynamic> config,
  ) async {
    final result = await send('PUT', '/marketing/config', config);
    if (result['config'] is! Map) {
      throw const AdminApiException(
        'الخادم لم يرجع الإعدادات المحفوظة. أعيدي المحاولة.',
      );
    }
    return Map<String, dynamic>.from(result['config'] as Map);
  }

  Future<int> sendNotification({
    required String title,
    required String body,
    String imageUrl = '',
  }) async {
    final result = await send('POST', '/notifications/send', {
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'audience': 'all',
      'limit': 2000,
    });
    return asInt(result['sent']);
  }
}
