import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'admin_api.dart';
import 'admin_models.dart';

class ProductEditorScreen extends StatefulWidget {
  const ProductEditorScreen({super.key, this.product});
  final AdminProduct? product;

  @override
  State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends State<ProductEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _price;
  late final TextEditingController _oldPrice;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _commissionPercent;
  late final TextEditingController _description;
  late final TextEditingController _threshold;
  late final TextEditingController _tags;
  late final TextEditingController _lengths;
  late final TextEditingController _colors;
  late List<String> _sizes;
  late Map<String, int> _quantities;
  late List<String> _remoteImages;
  final List<PlatformFile> _localImages = [];
  bool _hidden = false;
  bool _saving = false;
  String _sizeType = 'clothing';
  UploadProgress? _progress;
  List<ProductCategoryOption> _categories = const [
    ProductCategoryOption(label: 'قسم السهرة', value: 'قسم السهرة'),
    ProductCategoryOption(label: 'قسم ناعمة وانيقة', value: 'قسم ناعمة وانيقة'),
    ProductCategoryOption(label: 'قسم رمضان', value: 'قسم رمضان'),
    ProductCategoryOption(label: 'قسم الاكثر طلبا', value: 'قسم الاكثر طلبا'),
    ProductCategoryOption(label: 'قسم جمبسوت', value: 'قسم جمبسوت'),
    ProductCategoryOption(label: 'قسم الحوامل', value: 'قسم الحوامل'),
    ProductCategoryOption(label: 'قسم العيد', value: 'قسم العيد'),
  ];
  late String _category;

  static const _sizePresets = {
    'clothing': ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'],
    'abaya': ['48', '50', '52', '54', '56', '58', '60', '62'],
    'shoes': ['35', '36', '37', '38', '39', '40', '41', '42', '43'],
    'oneSize': ['موحد'],
  };

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _code = TextEditingController(text: p?.productCode ?? '');
    _price = TextEditingController(text: p == null ? '' : '${p.price}');
    _oldPrice = TextEditingController(
      text: p == null || p.oldPrice == 0 ? '' : '${p.oldPrice}',
    );
    _purchasePrice = TextEditingController(
      text: p == null || p.purchasePrice == 0 ? '' : '${p.purchasePrice}',
    );
    _commissionPercent = TextEditingController(
      text: p == null || p.commissionPercent == 0
          ? ''
          : '${p.commissionPercent}',
    );
    _category = p?.category.trim().isNotEmpty == true
        ? p!.category
        : _categories.first.value;
    _description = TextEditingController(text: p?.description ?? '');
    _threshold = TextEditingController(text: '${p?.lowStockThreshold ?? 3}');
    _tags = TextEditingController(text: p?.tags.join(', ') ?? '');
    _lengths = TextEditingController(text: p?.lengths.join(', ') ?? '');
    _colors = TextEditingController(text: p?.colors.join(', ') ?? '');
    _sizes = [...?p?.sizes];
    _quantities = {...?p?.sizeQuantities};
    _remoteImages = [...?p?.imageUrls];
    _hidden = p?.isHidden ?? false;
    _sizeType = _sizePresets.containsKey(p?.sizeType)
        ? p!.sizeType
        : 'clothing';
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await AdminApi.instance.productCategoryOptions();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        if (!_categories.any((option) => option.value == _category)) {
          _categories = [
            ProductCategoryOption(label: _category, value: _category),
            ..._categories,
          ];
        }
      });
    } catch (_) {
      // Website defaults remain available when the network is temporarily down.
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _code,
      _price,
      _oldPrice,
      _purchasePrice,
      _commissionPercent,
      _description,
      _threshold,
      _tags,
      _lengths,
      _colors,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _split(String value) => value
      .split(RegExp(r'[,،\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || !mounted) return;
    setState(() {
      for (final file in result.files) {
        final readable =
            (file.path?.isNotEmpty ?? false) ||
            (file.bytes?.isNotEmpty ?? false);
        final duplicate = _localImages.any(
          (item) => item.path == file.path && item.name == file.name,
        );
        if (readable && !duplicate) {
          _localImages.add(file);
        }
      }
    });
  }

  void _toggleSize(String size) {
    setState(() {
      if (_sizes.contains(size)) {
        _sizes.remove(size);
        _quantities.remove(size);
      } else {
        _sizes.add(size);
        _quantities[size] = 0;
      }
    });
  }

  Future<void> _addCustomSize() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مقاس'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'مثال: 52 أو طويل'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty || !mounted) return;
    if (!_sizes.contains(value))
      setState(() {
        _sizes.add(value);
        _quantities[value] = 0;
      });
  }

  void _changeQuantity(String size, int delta) {
    setState(
      () => _quantities[size] = ((_quantities[size] ?? 0) + delta).clamp(
        0,
        999999,
      ),
    );
  }

  void _setQuantity(String size, int quantity) {
    setState(() => _quantities[size] = quantity.clamp(0, 999999));
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _progress = null;
    });
    try {
      final uploaded = await AdminApi.instance.uploadImages(
        _localImages,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      final images = [..._remoteImages, ...uploaded];
      final stock = _sizes.isEmpty
          ? 0
          : _sizes.fold<int>(0, (sum, size) => sum + (_quantities[size] ?? 0));
      await AdminApi.instance.saveProduct({
        if (widget.product != null) 'productCode': _code.text.trim(),
        'name': _name.text.trim(),
        'price': double.parse(_price.text.trim()),
        'oldPrice': double.tryParse(_oldPrice.text.trim()) ?? 0,
        'purchasePrice': double.parse(_purchasePrice.text.trim()),
        'commissionPercent':
            double.tryParse(_commissionPercent.text.trim()) ?? 0,
        'category': _category,
        'tags': _split(_tags.text),
        'description': _description.text.trim(),
        'imageUrl': images.isEmpty ? '' : images.first,
        'imageUrls': images,
        'isHidden': _hidden ? 1 : 0,
        'sizes': _sizes,
        'sizeType': _sizeType,
        'lengths': _split(_lengths.text),
        'colors': _split(_colors.text),
        'stockQuantity': stock,
        'lowStockThreshold': int.tryParse(_threshold.text.trim()) ?? 3,
        'sizeQuantities': {
          for (final size in _sizes) size: _quantities[size] ?? 0,
        },
        'colorQuantities': widget.product?.colorQuantities ?? {},
        'rating': widget.product?.rating ?? 0,
        'reviewsCount': widget.product?.reviewsCount ?? 0,
      }, id: widget.product?.id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _sizes.fold<int>(
      0,
      (sum, size) => sum + (_quantities[size] ?? 0),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'إضافة منتج' : 'تعديل المنتج'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('حفظ'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Section(
              title: 'المعلومات الأساسية',
              icon: Icons.inventory_2_outlined,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'اسم المنتج'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'اسم المنتج مطلوب'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _code,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'كود المنتج',
                          hintText: 'سيُولد تلقائياً عند الحفظ',
                          prefixIcon: const Icon(Icons.qr_code_2_outlined),
                          helperText: widget.product == null
                              ? 'توليد آمن من الخادم بصيغة CKP'
                              : 'كود ثابت للمنتج',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            _categories.any(
                              (option) => option.value == _category,
                            )
                            ? _category
                            : _categories.first.value,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'التصنيف'),
                        items: _categories
                            .map(
                              (option) => DropdownMenuItem(
                                value: option.value,
                                child: Text(
                                  option.label == option.value
                                      ? option.label
                                      : '${option.label} — ${option.value}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _category = value ?? _category),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'السعر',
                          suffixText: 'د.ل',
                        ),
                        validator: (value) =>
                            (double.tryParse(value ?? '') ?? 0) <= 0
                            ? 'أدخل سعراً صحيحاً'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _oldPrice,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'السعر السابق',
                          suffixText: 'د.ل',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _purchasePrice,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'سعر شراء القطعة',
                    hintText: 'التكلفة الفعلية للقطعة',
                    suffixText: 'د.ل',
                    prefixIcon: Icon(Icons.shopping_cart_checkout_rounded),
                    helperText: 'يُستخدم لحساب تكلفة المخزون والربح الصافي',
                  ),
                  validator: (value) {
                    final cost = double.tryParse(value?.trim() ?? '');
                    if (cost == null || cost <= 0) {
                      return 'أدخلي سعر شراء صحيحًا';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _commissionPercent,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'نسبة عمولة المندوبة',
                    hintText: 'مثال: 10',
                    suffixText: '%',
                    prefixIcon: Icon(Icons.percent_rounded),
                    helperText: 'تُحسب هذه النسبة لهذا المنتج فقط',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'أدخلي نسبة عمولة المنتج';
                    final percent = double.tryParse(text);
                    if (percent == null || percent < 0 || percent > 100) {
                      return 'النسبة يجب أن تكون بين 0 و100';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'الوصف'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tags,
                  decoration: const InputDecoration(
                    labelText: 'الوسوم',
                    hintText: 'جديد، عرض، مميز',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'صور المنتج',
              icon: Icons.photo_library_outlined,
              children: [
                if (_remoteImages.isEmpty && _localImages.isEmpty)
                  Container(
                    height: 130,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 38),
                        SizedBox(height: 8),
                        Text('لم يتم اختيار صور'),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 106,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _remoteImages.length + _localImages.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        if (index < _remoteImages.length) {
                          return _ImageTile(
                            image: NetworkImage(_remoteImages[index]),
                            primary: index == 0,
                            onDelete: () =>
                                setState(() => _remoteImages.removeAt(index)),
                          );
                        }
                        final file = _localImages[index - _remoteImages.length];
                        return _ImageTile(
                          image: file.path?.isNotEmpty == true
                              ? FileImage(File(file.path!))
                              : MemoryImage(file.bytes!),
                          primary:
                              _remoteImages.isEmpty &&
                              _localImages.first == file,
                          onDelete: () =>
                              setState(() => _localImages.remove(file)),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: _saving ? null : _pickImages,
                  icon: const Icon(Icons.collections_outlined),
                  label: const Text('اختيار عدة صور من الهاتف'),
                ),
                if (_progress != null) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _progress!.total == 0
                        ? null
                        : _progress!.completed / _progress!.total,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _progress!.completed == _progress!.total
                        ? 'اكتمل رفع الصور'
                        : 'رفع ${_progress!.fileName} (${_progress!.completed + 1}/${_progress!.total})',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'المقاسات والكميات',
              icon: Icons.straighten_outlined,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _sizeType,
                  decoration: const InputDecoration(labelText: 'نوع المقاسات'),
                  items: const [
                    DropdownMenuItem(
                      value: 'clothing',
                      child: Text('ملابس (XS - XXXL)'),
                    ),
                    DropdownMenuItem(
                      value: 'abaya',
                      child: Text('عبايات وأرقام'),
                    ),
                    DropdownMenuItem(value: 'shoes', child: Text('أحذية')),
                    DropdownMenuItem(
                      value: 'oneSize',
                      child: Text('مقاس موحد'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _sizeType = value ?? 'clothing'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final size in _sizePresets[_sizeType]!)
                      FilterChip(
                        label: Text(size),
                        selected: _sizes.contains(size),
                        onSelected: (_) => _toggleSize(size),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('مقاس آخر'),
                      onPressed: _addCustomSize,
                    ),
                  ],
                ),
                if (_sizes.isNotEmpty) ...[
                  const Divider(height: 28),
                  for (final size in _sizes)
                    _QuantityRow(
                      size: size,
                      quantity: _quantities[size] ?? 0,
                      onMinus: () => _changeQuantity(size, -1),
                      onPlus: () => _changeQuantity(size, 1),
                      onPreset: (value) => _setQuantity(size, value),
                    ),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_outlined),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'إجمالي المخزون',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          '$total قطعة',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _threshold,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'حد تنبيه المخزون المنخفض',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lengths,
                  decoration: const InputDecoration(
                    labelText: 'الأطوال',
                    hintText: 'قصير، عادي، طويل',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _colors,
                  decoration: const InputDecoration(
                    labelText: 'الألوان',
                    hintText: 'أسود، أبيض، أحمر',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              value: _hidden,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _hidden = value),
              title: const Text('إخفاء المنتج عن المتجر'),
              subtitle: const Text('يبقى محفوظاً في لوحة التحكم'),
              secondary: const Icon(Icons.visibility_off_outlined),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              tileColor: theme.colorScheme.surfaceContainerLow,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ المنتج'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.image,
    required this.primary,
    required this.onDelete,
  });
  final ImageProvider image;
  final bool primary;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image(image: image, width: 92, height: 102, fit: BoxFit.cover),
      ),
      if (primary)
        PositionedDirectional(
          start: 5,
          bottom: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'رئيسية',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      PositionedDirectional(
        end: 2,
        top: 2,
        child: IconButton.filledTonal(
          onPressed: onDelete,
          icon: const Icon(Icons.close, size: 16),
          visualDensity: VisualDensity.compact,
        ),
      ),
    ],
  );
}

class _QuantityRow extends StatelessWidget {
  const _QuantityRow({
    required this.size,
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
    required this.onPreset,
  });
  final String size;
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<int> onPreset;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 58,
                child: Text(
                  size,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: onMinus,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Text(
                  '$quantity',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton.filled(onPressed: onPlus, icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              for (final value in [0, 5, 10, 20])
                ActionChip(
                  label: Text('$value'),
                  onPressed: () => onPreset(value),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
