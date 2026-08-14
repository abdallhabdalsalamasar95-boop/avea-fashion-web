// -----------------------------------------------------------------------------
// Clean rewrite (24/12/2025): Home page according to the provided AVEA FASHION
// homepage scenario.
// -----------------------------------------------------------------------------

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/cart_repository.dart';
import '../services/app_settings.dart';
import '../services/app_shell_nav.dart';
import '../services/favorites_service.dart';
import '../services/home_offers_service.dart';
import '../services/notifications_service.dart';
import '../services/products_repository.dart';
import '../services/recent_viewed_service.dart';
import '../services/rewards_service.dart';
import '../utils/category_normalizer.dart';
import '../utils/money.dart';
import '../utils/product_categories.dart';
import '../utils/product_images.dart';
import '../utils/product_inventory.dart';
import '../utils/product_routes.dart';
import '../utils/smooth_page_route.dart';
import '../widgets/empty_state.dart';
import '../widgets/network_or_placeholder_image.dart';
import '../widgets/product_card.dart';
import 'faq.dart';
import 'legal_document.dart';
import 'return_policy.dart';
import '../widgets/skeleton.dart';
import '../widgets/trust_bar.dart';
import '../widgets/bouncy_card.dart';
import '../widgets/ad_banner.dart';
import 'cart.dart';
import 'filtered_products.dart';
import 'rewards.dart';
import 'size_guide.dart';

enum _SortMode { newest, priceLow, priceHigh }

class HomeScreen extends StatefulWidget {
  final bool favoritesOnly;
  const HomeScreen({super.key, this.favoritesOnly = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _gold = Color(0xFFD4AF37);
  static const _black = Color(0xFF222222);
  static const _lightGrey = Color(0xFFF8F8F8);
  static const List<String> _customerTestimonials = [
    'الفستان وصل بنفس الصورة وخياطة ممتازة، شكراً لكم 🤍',
    'الخامة فخمة والمقاس مضبوط جدًا، التجربة كانت رائعة.',
    'التوصيل سريع والتغليف مرتب، أكيد بكرر الطلب مرة ثانية.',
    'أحلى متجر تعاملت معاه من ناحية الجودة والذوق.',
    'القطعة طلعت أجمل من المتوقع، تفاصيلها جميلة جداً.',
  ];

  static final List<({String label, String mode})> _quickCategories =
      ProductCategories.homeShowcase
          .map((c) => (label: c, mode: 'category'))
          .toList(growable: false);

  bool get _isArabic => _settings.locale.value.languageCode == 'ar';
  String _tr(String ar, String en) => _isArabic ? ar : en;

  IconData _categoryIcon(String label) {
    // Use CategoryNormalizer so spelling variants still map to the same icon.
    if (CategoryNormalizer.equals(label, 'قسم السهرة') ||
        CategoryNormalizer.equals(label, 'قسم فساتين السهرة')) {
      // Requested: evening dresses icon should be a dress-like icon.
      return Icons.dry_cleaning_rounded;
    }
    if (CategoryNormalizer.equals(label, 'قسم ناعمة وانيقة')) {
      return Icons.auto_awesome_outlined;
    }
    if (CategoryNormalizer.equals(label, 'قسم رمضان')) {
      return Icons.brightness_2_rounded;
    }
    if (CategoryNormalizer.equals(label, 'قسم الاكثر طلبا')) {
      return Icons.workspace_premium_rounded;
    }
    if (CategoryNormalizer.equals(label, 'قسم جمبسوت')) {
      return Icons.checkroom_outlined;
    }
    if (CategoryNormalizer.equals(label, 'قسم العيد')) {
      return Icons.celebration_outlined;
    }
    return Icons.category_outlined;
  }

  String _quickCategoryLabel(String label) {
    if (CategoryNormalizer.equals(label, 'قسم السهرة') ||
        CategoryNormalizer.equals(label, 'قسم فساتين السهرة')) {
      return _tr('فساتين السهرة', 'Evening Dresses');
    }
    if (CategoryNormalizer.equals(label, 'قسم ناعمة وانيقة')) {
      return _tr('ناعمة وانيقة', 'Soft & Elegant');
    }
    if (CategoryNormalizer.equals(label, 'قسم رمضان')) {
      return _tr('رمضان', 'Ramadan');
    }
    if (CategoryNormalizer.equals(label, 'قسم الاكثر طلبا')) {
      return _tr('الأكثر طلبًا', 'Most Wanted');
    }
    if (CategoryNormalizer.equals(label, 'قسم جمبسوت')) {
      return _tr('جمبسوت', 'Jumpsuits');
    }
    if (CategoryNormalizer.equals(label, 'قسم العيد')) {
      return _tr('العيد', 'Eid');
    }
    if (label.startsWith('قسم ')) {
      return label.replaceFirst('قسم ', '').trim();
    }
    return label;
  }

  Future<void> _showFeatureDetails(
      {required String title, required String subtitle}) async {
    final cs = Theme.of(context).colorScheme;

    List<String> bulletsFor(String t) {
      switch (t) {
        case 'شحن سريع':
          return const [
            'توصيل داخل ليبيا خلال 2–4 أيام عمل (حسب المدينة).',
            'إشعار برقم التتبع عند شحن الطلب.',
            'تغليف آمن لحماية القطعة أثناء الشحن.',
          ];
        case 'تغليف هدايا':
          return const [
            'تغليف VIP أنيق مناسب للمناسبات.',
            'إمكانية إضافة رسالة قصيرة (قريباً).',
            'حماية إضافية للقطعة داخل التغليف.',
          ];
        case 'دفع آمن':
          return const [
            'دفع عند الاستلام (متاح لبعض المناطق).',
            'بطاقات: Visa • Mastercard.',
            'طرق دفع متنوعة حسب المتاح.',
          ];
        case 'إرجاع سهل':
          return const [
            'إرجاع خلال 14 يوماً من الاستلام وفق الشروط.',
            'يجب أن تكون القطعة بحالتها الأصلية وغير مستخدمة.',
            'استرجاع المبلغ خلال 3–7 أيام عمل بعد قبول الإرجاع.',
          ];
        default:
          return const [];
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final bullets = bulletsFor(title);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      height: 1.35),
                ),
                if (bullets.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final b in bullets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  ',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                          Expanded(
                              child: Text(b,
                                  style: Theme.of(ctx)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          height: 1.35))),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('تمام'),
                    ),
                    if (title == 'إرجاع سهل')
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'للمساعدة: 9200 1234 11 • info@carmencarla.com')));
                        },
                        child: const Text('تواصل معنا'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  final _searchCtl = TextEditingController();
  late final VoidCallback _searchRequestListener;
  final _scrollCtl = ScrollController();
  static const double _scrollCacheExtent = 700;
  bool _isPrimaryScrolling = false;
  // Smaller cards in the "إطلالات لا تُقاوم" carousel (requested).
  late final PageController _looksCarouselCtl =
      PageController(viewportFraction: 0.72);

  // Hero (top best-sellers) auto-rotating carousel.
  late final PageController _heroCarouselCtl = PageController();
  Timer? _heroCarouselTimer;
  Timer? _heroCarouselResumeTimer;
  bool _heroCarouselAutoPaused = false;
  List<String> _heroCarouselImages = const [];
  final ValueNotifier<int> _heroCarouselIndex = ValueNotifier<int>(0);
  bool _heroSyncScheduled = false;
  List<String>? _heroSyncPendingImages;
  final _productsHeaderKey = GlobalKey();
  final _newCollectionKey = GlobalKey();

  bool _showScrollToTop = false;
  Timer? _searchDebounceTimer;

  final ProductsRepository _repo = ProductsRepository();
  final RewardsService _rewards = RewardsService();
  final RecentViewedService _recentViewed = RecentViewedService();
  final AppSettings _settings = AppSettings();
  late Stream<List<Map<String, dynamic>>> _productsStream;

  _SortMode _sort = _SortMode.newest;
  String _category = 'الكل';
  int _visibleCount = 20;
  bool _onlyDiscounts = false;
  bool _onlyTopRated = false;
  bool _onlyNewArrivals = false;
  double _minDiscountPct = 40.0;
  double? _priceMin;
  double? _priceMax;

  Map<String, int> _soldByProductId = const {};
  bool _soldLoading = false;
  int _soldRevision = 0;
  List<Map<String, dynamic>> _completeLooks = const [];

  // Cache derived collections so we don't re-sort large lists on unrelated
  // rebuilds (e.g., hero carousel index updates).
  List<Map<String, dynamic>>? _derivedAllDocsRef;
  int _derivedSoldRevision = -1;
  List<Map<String, dynamic>> _derivedNewestAll = const [];
  List<Map<String, dynamic>> _derivedBest6All = const [];
  List<String> _derivedHeroImages = const [];

  late DateTime _offersEndsAt;
  Timer? _offersTimer;
  final ValueNotifier<Duration> _offersRemaining =
      ValueNotifier<Duration>(Duration.zero);

  List<ValueNotifier<bool>> get _homeToggleNotifiers => [
        _settings.homeShowSmartFilters,
        _settings.homeShowWalletStrip,
        _settings.homeShowSocialProof,
        _settings.homeShowPickOfDay,
        _settings.homeShowStyleReel,
        _settings.homeShowNew48h,
        _settings.homeShowBundle,
        _settings.homeShowRecent,
        _settings.homeShowLowStock,
      ];

  void _onHomeTogglesChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _searchRequestListener = () {
      if (!mounted) return;
      _openStoreSearch();
    };
    AppShellNav.searchRequest.addListener(_searchRequestListener);
    _productsStream = _repo.productsStream();
    _visibleCount = 20;
    _loadSoldCounts();
    _loadCompleteLooks();

    // Editable marketing offers (local-first + best-effort cloud sync).
    unawaited(HomeOffersService.instance.init());
    unawaited(_settings.init());
    unawaited(_rewards.init());
    unawaited(_recentViewed.init());

    for (final n in _homeToggleNotifiers) {
      n.addListener(_onHomeTogglesChanged);
    }

    _scrollCtl.addListener(_handleScroll);

    _offersEndsAt =
        DateTime.now().add(const Duration(hours: 2, minutes: 15, seconds: 30));
    _offersRemaining.value = _offersEndsAt.difference(DateTime.now());
    _offersTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isPrimaryScrolling) return;
      final d = _offersEndsAt.difference(DateTime.now());
      _offersRemaining.value = d.isNegative ? Duration.zero : d;
    });
  }

  @override
  void dispose() {
    AppShellNav.searchRequest.removeListener(_searchRequestListener);
    _scrollCtl.removeListener(_handleScroll);
    _searchDebounceTimer?.cancel();
    _offersTimer?.cancel();
    _offersRemaining.dispose();
    _heroCarouselIndex.dispose();

    for (final n in _homeToggleNotifiers) {
      n.removeListener(_onHomeTogglesChanged);
    }

    _searchCtl.dispose();
    _scrollCtl.dispose();
    _looksCarouselCtl.dispose();

    _heroCarouselTimer?.cancel();
    _heroCarouselResumeTimer?.cancel();
    _heroCarouselCtl.dispose();
    super.dispose();
  }

  Future<void> _openStoreSearch() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          MediaQuery.viewInsetsOf(ctx).bottom + 16,
        ),
        child: TextField(
          controller: _searchCtl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (_) {
            _searchDebounceTimer?.cancel();
            _searchDebounceTimer = Timer(
              const Duration(milliseconds: 250),
              () {
                if (!mounted) return;
                setState(() => _resetVisible());
              },
            );
          },
          onSubmitted: (_) {
            Navigator.pop(ctx);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _scrollToKey(_productsHeaderKey);
            });
          },
          decoration: InputDecoration(
            hintText: _tr(
              'ابحثي عن فستان أو موديل...',
              'Search for a dress or style...',
            ),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchCtl.text.trim().isEmpty
                ? null
                : IconButton(
                    tooltip: 'مسح',
                    onPressed: () {
                      _searchCtl.clear();
                      setState(() => _resetVisible());
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            border: const UnderlineInputBorder(),
          ),
        ),
      ),
    );
  }

  void _handleScroll() {
    if (!_scrollCtl.hasClients) return;
    final shouldShowTop = _scrollCtl.offset > 650;
    if (shouldShowTop == _showScrollToTop) return;
    if (!mounted) return;
    setState(() => _showScrollToTop = shouldShowTop);
  }

  Future<void> _scrollToTop() async {
    if (!_scrollCtl.hasClients) return;
    await _scrollCtl.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  void _pauseHeroCarouselAuto(
      {Duration resumeAfter = const Duration(seconds: 3)}) {
    _heroCarouselAutoPaused = true;
    _heroCarouselTimer?.cancel();
    _heroCarouselTimer = null;

    _heroCarouselResumeTimer?.cancel();
    _heroCarouselResumeTimer = Timer(resumeAfter, () {
      if (!mounted) return;
      _heroCarouselAutoPaused = false;
      if (_heroCarouselImages.length >= 2) {
        _startHeroCarouselTimer();
      }
    });
  }

  void _prefetchHeroImage(BuildContext context, String url) {
    final u = url.trim();
    if (u.isEmpty) return;

    final lower = u.toLowerCase();
    if (lower.endsWith('.avif') ||
        lower.contains('.avif?') ||
        lower.endsWith('.heic') ||
        lower.contains('.heic?') ||
        lower.endsWith('.heif') ||
        lower.contains('.heif?')) {
      return;
    }

    ImageProvider? provider;
    if (u.startsWith('http://') || u.startsWith('https://')) {
      provider = NetworkImage(u);
    }

    if (provider == null) return;
    // Best-effort; don't block UI.
    unawaited(
      precacheImage(provider, context).catchError((_, __) {
        // Ignore bad/unsupported image data during opportunistic prefetch.
      }),
    );
  }

  bool _sameStringList(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _scheduleHeroCarouselSync(List<String> images) {
    // IMPORTANT: We must not call controller methods (jumpToPage/animate) or
    // start timers during build, because they can synchronously trigger
    // PageView's onPageChanged -> setState, which causes:
    // "setState() called during build".
    final same = _sameStringList(_heroCarouselImages, images);
    final needsTimerStop =
        same && images.length < 2 && _heroCarouselTimer != null;
    final needsTimerStart = same &&
        images.length >= 2 &&
        _heroCarouselTimer == null &&
        !_heroCarouselAutoPaused;
    final needsSync = !same || needsTimerStop || needsTimerStart;
    if (!needsSync) return;

    _heroSyncPendingImages = List<String>.from(images);
    if (_heroSyncScheduled) return;
    _heroSyncScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _heroSyncScheduled = false;
      if (!mounted) return;
      final pending = _heroSyncPendingImages;
      _heroSyncPendingImages = null;
      if (pending == null) return;
      _syncHeroCarousel(pending);
    });
  }

  void _syncHeroCarousel(List<String> images) {
    if (_sameStringList(_heroCarouselImages, images)) {
      // Keep timer state correct even if images stayed the same.
      if (images.length < 2) {
        _heroCarouselTimer?.cancel();
        _heroCarouselTimer = null;
      } else if (_heroCarouselTimer == null && !_heroCarouselAutoPaused) {
        _startHeroCarouselTimer();
      }
      return;
    }

    setState(() {
      _heroCarouselImages = List<String>.from(images);
    });
    _heroCarouselIndex.value = 0;
    if (_heroCarouselCtl.hasClients) {
      // Reset to first page when data changes.
      _heroCarouselCtl.jumpToPage(0);
    }

    _heroCarouselTimer?.cancel();
    _heroCarouselTimer = null;
    if (images.length >= 2 && !_heroCarouselAutoPaused) {
      _startHeroCarouselTimer();
    }
  }

  void _startHeroCarouselTimer() {
    _heroCarouselTimer?.cancel();
    _heroCarouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (_heroCarouselAutoPaused) return;
      final imgs = _heroCarouselImages;
      if (imgs.length < 2) return;
      if (!_heroCarouselCtl.hasClients) return;
      final next = (_heroCarouselIndex.value + 1) % imgs.length;
      _heroCarouselCtl.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Future<void> _loadSoldCounts() async {
    if (_soldLoading) return;
    setState(() => _soldLoading = true);
    try {
      final map = await CartRepository()
          .getSoldQuantitiesByProductId(excludeCanceled: true);
      if (!mounted) return;
      setState(() {
        _soldByProductId = map;
        _soldRevision++;
      });
    } catch (_) {
      // Non-fatal.
    } finally {
      if (mounted) setState(() => _soldLoading = false);
    }
  }

  Future<void> _loadCompleteLooks() async {
    try {
      final looks = await _repo.completeLooks();
      if (!mounted) return;
      setState(() => _completeLooks = looks);
    } catch (_) {
      // Best-effort only; fallback bundle remains available.
    }
  }

  void _ensureDerivedCollections(List<Map<String, dynamic>> allDocs) {
    final sameDocs = identical(_derivedAllDocsRef, allDocs);
    final sameSold = _derivedSoldRevision == _soldRevision;
    if (sameDocs && sameSold) return;

    _derivedAllDocsRef = allDocs;
    _derivedSoldRevision = _soldRevision;

    final newest = List<Map<String, dynamic>>.from(allDocs)
      ..sort((a, b) => ((b['createdAt'] as num?)?.toInt() ?? 0)
          .compareTo(((a['createdAt'] as num?)?.toInt() ?? 0)));
    _derivedNewestAll = newest;

    final best = List<Map<String, dynamic>>.from(allDocs)
      ..sort((a, b) {
        final sa = _soldByProductId[(a['id'] ?? '').toString()] ?? 0;
        final sb = _soldByProductId[(b['id'] ?? '').toString()] ?? 0;
        return sb.compareTo(sa);
      });
    _derivedBest6All = best.take(6).toList(growable: false);

    final heroImages = <String>[..._pickBestSellerHeroImages(best, max: 6)];
    if (heroImages.isEmpty && allDocs.isNotEmpty) {
      final fallback = (getPrimaryProductImage(allDocs.first) ??
              allDocs.first['imageUrl']?.toString() ??
              '')
          .trim();
      if (fallback.isNotEmpty) heroImages.add(fallback);
    }
    _derivedHeroImages = heroImages;
  }

  void _resetVisible() => _visibleCount = 20;

  void _loadMoreProducts(int totalCount) {
    if (!mounted || _visibleCount >= totalCount) return;
    setState(() {
      _visibleCount = math.min(_visibleCount + 20, totalCount);
    });
  }

  String _sortLabel() {
    switch (_sort) {
      case _SortMode.newest:
        return _tr('الأحدث', 'Newest');
      case _SortMode.priceLow:
        return _tr('الأرخص', 'Lowest price');
      case _SortMode.priceHigh:
        return _tr('الأغلى', 'Highest price');
    }
  }

  int _activeFiltersCount() {
    var n = 0;
    if (_searchCtl.text.trim().isNotEmpty) n++;
    if (_category != 'الكل') n++;
    if (_onlyDiscounts) n++;
    if (_onlyTopRated) n++;
    if (_onlyNewArrivals) n++;
    if (_priceMin != null || _priceMax != null) n++;
    if (_sort != _SortMode.newest) n++;
    return n;
  }

  Future<void> _openUnifiedFiltersSheet({
    required List<String> categories,
    required Map<String, int> catCount,
    required Map<String, String?> catImage,
    required double? minPriceBound,
    required double? maxPriceBound,
  }) async {
    // Local draft (apply on confirm).
    var draftSort = _sort;
    var draftCategory = _category;
    var draftOnlyDiscounts = _onlyDiscounts;
    var draftOnlyTopRated = _onlyTopRated;
    var draftOnlyNewArrivals = _onlyNewArrivals;
    var draftMinDiscountPct = _minDiscountPct;

    final hasPriceBounds = minPriceBound != null &&
        maxPriceBound != null &&
        maxPriceBound > minPriceBound;
    final minBound = minPriceBound ?? 0.0;
    final maxBound = maxPriceBound ?? 0.0;

    var draftUsePriceRange =
        hasPriceBounds && (_priceMin != null || _priceMax != null);
    var draftPriceRange = RangeValues(minBound, maxBound);
    if (hasPriceBounds) {
      final lo = (_priceMin ?? minBound).clamp(minBound, maxBound);
      final hi = (_priceMax ?? maxBound).clamp(minBound, maxBound);
      draftPriceRange = RangeValues(lo, hi);
    }

    int draftActiveCount() {
      var n = 0;
      if (_searchCtl.text.trim().isNotEmpty) n++;
      if (draftCategory != 'الكل') n++;
      if (draftOnlyDiscounts) n++;
      if (draftOnlyTopRated) n++;
      if (draftOnlyNewArrivals) n++;
      if (draftUsePriceRange) n++;
      if (draftSort != _SortMode.newest) n++;
      return n;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx2, setLocal) {
              final active = draftActiveCount();
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx2).viewInsets.bottom,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      title: const Text(
                        'الفرز والفلاتر',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        active == 0
                            ? 'لا توجد فلاتر نشطة'
                            : 'فلاتر نشطة: $active',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      trailing: _searchCtl.text.trim().isEmpty
                          ? null
                          : TextButton.icon(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                _searchCtl.clear();
                                setState(() => _resetVisible());
                                setLocal(() {});
                              },
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text('مسح البحث'),
                            ),
                    ),
                    const Divider(height: 1),
                    ExpansionTile(
                      initiallyExpanded: true,
                      title: const Text('الفرز',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      children: [
                        RadioGroup<_SortMode>(
                          groupValue: draftSort,
                          onChanged: (v) {
                            if (v == null) return;
                            setLocal(() {
                              draftSort = v;
                            });
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              RadioListTile<_SortMode>(
                                value: _SortMode.newest,
                                title: Text('الأحدث'),
                              ),
                              RadioListTile<_SortMode>(
                                value: _SortMode.priceLow,
                                title: Text('الأرخص أولاً'),
                              ),
                              RadioListTile<_SortMode>(
                                value: _SortMode.priceHigh,
                                title: Text('الأغلى أولاً'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    ExpansionTile(
                      title: const Text('فلترة',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      children: [
                        SwitchListTile(
                          value: draftOnlyDiscounts,
                          onChanged: (v) => setLocal(() {
                            draftOnlyDiscounts = v;
                            if (v) {
                              draftOnlyTopRated = false;
                              draftCategory = 'الكل';
                            }
                          }),
                          title: const Text('التخفيضات فقط'),
                          subtitle: const Text('عرض المنتجات التي عليها خصم'),
                        ),
                        if (draftOnlyDiscounts)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'حد الخصم الأدنى',
                                  style: Theme.of(ctx2)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final v in const [20, 30, 40, 50, 60])
                                      ChoiceChip(
                                        label: Text('+$v%'),
                                        selected:
                                            draftMinDiscountPct.round() == v,
                                        onSelected: (_) => setLocal(() =>
                                            draftMinDiscountPct = v.toDouble()),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'مثال: +40% يعني عرض المنتجات بخصم 40% أو أكثر.',
                                  style: Theme.of(ctx2)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                          color: cs.onSurfaceVariant,
                                          fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        SwitchListTile(
                          value: draftOnlyTopRated,
                          onChanged: (v) => setLocal(() {
                            draftOnlyTopRated = v;
                            if (v) {
                              draftOnlyDiscounts = false;
                            }
                          }),
                          title: const Text('تقييم عالي'),
                          subtitle: const Text('عرض المنتجات ذات تقييم 4.2+'),
                        ),
                        SwitchListTile(
                          value: draftOnlyNewArrivals,
                          onChanged: (v) =>
                              setLocal(() => draftOnlyNewArrivals = v),
                          title: const Text('وصل حديثاً'),
                          subtitle: const Text('آخر 30 يوم'),
                        ),
                        if (hasPriceBounds) ...[
                          SwitchListTile(
                            value: draftUsePriceRange,
                            onChanged: (v) =>
                                setLocal(() => draftUsePriceRange = v),
                            title: const Text('تحديد نطاق السعر'),
                            subtitle: Text(
                              draftUsePriceRange
                                  ? '${Money.lyd2(draftPriceRange.start)} — ${Money.lyd2(draftPriceRange.end)}'
                                  : 'اختياري',
                            ),
                          ),
                          if (draftUsePriceRange)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                              child: RangeSlider(
                                values: draftPriceRange,
                                min: minBound,
                                max: maxBound,
                                divisions: 20,
                                labels: RangeLabels(
                                  Money.lyd2(draftPriceRange.start),
                                  Money.lyd2(draftPriceRange.end),
                                ),
                                onChanged: (r) =>
                                    setLocal(() => draftPriceRange = r),
                              ),
                            ),
                        ],
                      ],
                    ),
                    if (!widget.favoritesOnly) ...[
                      const Divider(height: 1),
                      ExpansionTile(
                        title: const Text('التصنيف',
                            style: TextStyle(fontWeight: FontWeight.w900)),
                        children: [
                          ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            leading: Icon(
                              draftCategory == 'الكل'
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                            ),
                            title: const Text('الكل'),
                            subtitle: Text(
                                '${catCount.values.fold<int>(0, (s, v) => s + v)} منتج'),
                            onTap: () => setLocal(() {
                              draftCategory = 'الكل';
                              // keep other toggles as-is
                            }),
                          ),
                          const Divider(height: 1),
                          for (final c in categories)
                            ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              leading: Icon(
                                draftCategory == c
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                              ),
                              titleAlignment: ListTileTitleAlignment.center,
                              title: Text(_quickCategoryLabel(c),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              subtitle: Text('${catCount[c] ?? 0} منتج'),
                              trailing: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: cs.outlineVariant
                                        .withValues(alpha: 0.75),
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: () {
                                  final preview = _resolveCategoryPreviewImage(
                                    c,
                                    catImage,
                                  );
                                  if (preview == null ||
                                      preview.trim().isEmpty) {
                                    return ColoredBox(
                                      color: cs.surfaceContainerHighest
                                          .withValues(alpha: 0.55),
                                      child: Icon(
                                        _categoryIcon(c),
                                        size: 18,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    );
                                  }
                                  return Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      NetworkOrPlaceholderImage(
                                        url: preview,
                                        borderRadius: 0,
                                        fit: BoxFit.cover,
                                        showLoadingSpinner: false,
                                      ),
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.18),
                                        ),
                                      ),
                                      Center(
                                        child: Icon(
                                          _categoryIcon(c),
                                          size: 16,
                                          color: Colors.white,
                                          shadows: const [
                                            Shadow(
                                              color: Color(0x66000000),
                                              blurRadius: 2,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }(),
                              ),
                              onTap: () => setLocal(() {
                                draftCategory = c;
                                draftOnlyDiscounts = false;
                                draftOnlyTopRated = false;
                              }),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                setLocal(() {
                                  draftSort = _SortMode.newest;
                                  draftCategory = 'الكل';
                                  draftOnlyDiscounts = false;
                                  draftOnlyTopRated = false;
                                  draftOnlyNewArrivals = false;
                                  draftMinDiscountPct = 40.0;
                                  draftUsePriceRange = false;
                                  if (hasPriceBounds) {
                                    draftPriceRange =
                                        RangeValues(minBound, maxBound);
                                  }
                                });
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('إعادة ضبط'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                setState(() {
                                  _sort = draftSort;
                                  _category = draftCategory;
                                  _onlyDiscounts = draftOnlyDiscounts;
                                  _onlyTopRated = draftOnlyTopRated;
                                  _onlyNewArrivals = draftOnlyNewArrivals;
                                  _minDiscountPct = draftMinDiscountPct;
                                  if (hasPriceBounds && draftUsePriceRange) {
                                    _priceMin = draftPriceRange.start;
                                    _priceMax = draftPriceRange.end;
                                  } else {
                                    _priceMin = null;
                                    _priceMax = null;
                                  }
                                  _resetVisible();
                                });
                                Navigator.pop(ctx);
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  _scrollToKey(_productsHeaderKey);
                                });
                              },
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('تطبيق'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _floatingFiltersButton(
    BuildContext context, {
    required List<String> categories,
    required Map<String, int> catCount,
    required Map<String, String?> catImage,
    required double? minPriceBound,
    required double? maxPriceBound,
  }) {
    final cs = Theme.of(context).colorScheme;
    final active = _activeFiltersCount();

    Widget circleButton({
      required String tooltip,
      required IconData icon,
      required VoidCallback onTap,
      int badge = 0,
    }) {
      const size = 44.0;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            elevation: 5,
            color: cs.surface,
            shadowColor: Colors.black.withValues(alpha: 0.20),
            shape: const CircleBorder(),
            child: ClipOval(
              child: Ink(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.surface,
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.70),
                  ),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTap();
                  },
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Tooltip(
                      message: tooltip,
                      child: Icon(icon, size: 20, color: cs.onSurface),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (badge > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Badge(label: Text('$badge')),
            ),
        ],
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showScrollToTop) ...[
            circleButton(
              tooltip: 'أعلى الصفحة',
              icon: Icons.arrow_upward_rounded,
              onTap: _scrollToTop,
            ),
            const SizedBox(height: 10),
          ],
          circleButton(
            tooltip: active == 0
                ? '${_tr('الفلاتر', 'Filters')} • ${_sortLabel()} • ${_category == 'الكل' ? _tr('كل التصنيفات', 'All categories') : _quickCategoryLabel(_category)}'
                : '${_tr('الفلاتر', 'Filters')} ($active) • ${_sortLabel()} • ${_category == 'الكل' ? _tr('كل التصنيفات', 'All categories') : _quickCategoryLabel(_category)}',
            icon: Icons.tune_rounded,
            badge: active,
            onTap: () => _openUnifiedFiltersSheet(
              categories: categories,
              catCount: catCount,
              catImage: catImage,
              minPriceBound: minPriceBound,
              maxPriceBound: maxPriceBound,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _scrollToKey(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: 0.04,
    );
  }

  String _fmt2(int v) => v.toString().padLeft(2, '0');

  Widget _countdownPill(BuildContext context,
      {required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  List<String> _pickBestSellerHeroImages(
    List<Map<String, dynamic>> best, {
    int max = 6,
  }) {
    final out = <String>[];
    final seen = <String>{};
    for (final p in best) {
      final raw = getPrimaryProductImage(p) ?? p['imageUrl']?.toString();
      final img = (raw ?? '').trim();
      if (img.isEmpty) continue;
      if (!seen.add(img)) continue;
      out.add(img);
      if (out.length >= max) break;
    }
    return out;
  }

  List<String> _previewCategoryAliases(String label) {
    final out = <String>[label];

    if (CategoryNormalizer.equals(label, 'قسم السهرة') ||
        CategoryNormalizer.equals(label, 'قسم فساتين السهرة')) {
      out.addAll(const [
        'قسم السهرة',
        'قسم فساتين السهرة',
        'فساتين السهرة',
        'السهره',
        'سهرة',
      ]);
    }

    if (CategoryNormalizer.equals(label, 'قسم رمضان')) {
      out.addAll(const ['قسم رمضان', 'رمضان']);
    }

    if (label.startsWith('قسم ')) {
      final stripped = label.replaceFirst('قسم ', '').trim();
      if (stripped.isNotEmpty) out.add(stripped);
    }

    final unique = <String>[];
    for (final v in out) {
      if (!unique.any((e) => CategoryNormalizer.equals(e, v))) {
        unique.add(v);
      }
    }
    return unique;
  }

  String? _resolveCategoryPreviewImage(
      String label, Map<String, String?> catImage) {
    final curated = _curatedCategoryImage(label);
    if (curated != null) {
      return curated;
    }

    final aliases = _previewCategoryAliases(label);

    for (final alias in aliases) {
      for (final entry in catImage.entries) {
        if (CategoryNormalizer.equals(entry.key, alias)) {
          final v = (entry.value ?? '').trim();
          if (v.isNotEmpty) return v;
        }
      }
    }

    final docs = _derivedAllDocsRef ?? const <Map<String, dynamic>>[];
    for (final p in docs) {
      final c = (p['category'] ?? '').toString().trim();
      if (c.isEmpty) continue;
      if (!aliases.any((a) => CategoryNormalizer.equals(c, a))) continue;
      final v = ((getPrimaryProductImage(p) ?? p['imageUrl']?.toString()) ?? '')
          .trim();
      if (v.isNotEmpty) return v;
    }
    return _categoryFallbackImage(label);
  }

  String? _curatedCategoryImage(String label) {
    if (CategoryNormalizer.equals(label, 'قسم السهرة') ||
        CategoryNormalizer.equals(label, 'قسم فساتين السهرة')) {
      return 'assets/categories/evening.webp';
    }
    if (CategoryNormalizer.equals(label, 'قسم ناعمة وانيقة')) {
      return 'assets/categories/soft.webp';
    }
    if (CategoryNormalizer.equals(label, 'قسم رمضان')) {
      return 'assets/categories/ramadan.webp';
    }
    if (CategoryNormalizer.equals(label, 'قسم الاكثر طلبا')) {
      return 'assets/categories/best_sellers.webp';
    }
    if (CategoryNormalizer.equals(label, 'قسم جمبسوت')) {
      return 'assets/categories/jumpsuit.webp';
    }
    if (CategoryNormalizer.equals(label, 'قسم العيد')) {
      return 'assets/categories/eid.webp';
    }
    return null;
  }

  String _categoryFallbackImage(String label) {
    if (CategoryNormalizer.equals(label, 'قسم السهرة') ||
        CategoryNormalizer.equals(label, 'قسم فساتين السهرة')) {
      return 'assets/categories/evening.webp';
    }
    if (CategoryNormalizer.equals(label, 'قسم ناعمة وانيقة')) {
      return 'assets/categories/soft.webp';
    }
    if (CategoryNormalizer.equals(label, 'قسم رمضان')) {
      return 'assets/categories/ramadan.webp';
    }
    if (CategoryNormalizer.equals(label, 'قسم الاكثر طلبا')) {
      return 'assets/categories/best_sellers.webp';
    }
    if (CategoryNormalizer.equals(label, 'قسم جمبسوت')) {
      return 'assets/categories/jumpsuit.webp';
    }
    if (CategoryNormalizer.equals(label, 'قسم العيد')) {
      return 'assets/categories/eid.webp';
    }
    return 'assets/categories/evening.webp';
  }

  Color _categoryOverlayColor(String label) {
    if (CategoryNormalizer.equals(label, 'قسم رمضان')) {
      return const Color(0xFF315C4B);
    }
    if (CategoryNormalizer.equals(label, 'قسم الاكثر طلبا')) {
      return const Color(0xFFB58A3A);
    }
    if (CategoryNormalizer.equals(label, 'قسم جمبسوت')) {
      return const Color(0xFF465A76);
    }
    if (CategoryNormalizer.equals(label, 'قسم العيد')) {
      return const Color(0xFF986B32);
    }
    return const Color(0xFF7B3F5C);
  }

  SliverToBoxAdapter _quickCategoriesBar(
    BuildContext context, {
    required Map<String, String?> catImage,
  }) {
    final cs = Theme.of(context).colorScheme;
    final items = _quickCategories.take(9).toList(growable: false);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (ctx, i) {
            final it = items[i];
            final label = it.label;
            final shortLabel = _quickCategoryLabel(label);
            final previewImage = _categoryFallbackImage(label);
            final overlay = _categoryOverlayColor(label);

            return InkWell(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(52),
              ),
              onTap: () {
                HapticFeedback.selectionClick();
                if (CategoryNormalizer.equals(label, 'قسم الاكثر طلبا')) {
                  Navigator.push(
                    context,
                    FadeSlidePageRoute(
                      builder: (_) => const FilteredProductsScreen(
                        mode: FilteredProductsMode.best,
                        title: 'الأكثر مبيعاً',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  FadeSlidePageRoute(
                    builder: (_) => FilteredProductsScreen(
                      mode: FilteredProductsMode.category,
                      title: label,
                      category: label,
                    ),
                  ),
                );
              },
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(52),
                        ),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.55),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          NetworkOrPlaceholderImage(
                            url: previewImage,
                            borderRadius: 0,
                            fit: BoxFit.cover,
                            showLoadingSpinner: false,
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  overlay.withValues(alpha: 0.04),
                                  overlay.withValues(alpha: 0.24),
                                ],
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            top: 8,
                            end: 8,
                            child: Container(
                              width: 27,
                              height: 27,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.88),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _categoryIcon(label),
                                size: 15,
                                color: overlay,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    shortLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _applyQuery(List<Map<String, dynamic>> input) {
    final q = _searchCtl.text.trim();
    var out = List<Map<String, dynamic>>.from(input);

    if (q.isNotEmpty) {
      final qq = q.toLowerCase();
      out = out.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final desc = (p['description'] ?? '').toString().toLowerCase();
        return name.contains(qq) || desc.contains(qq);
      }).toList();
    }

    out.sort((a, b) {
      switch (_sort) {
        case _SortMode.priceLow:
          return ((a['price'] as num?)?.toDouble() ?? 0)
              .compareTo(((b['price'] as num?)?.toDouble() ?? 0));
        case _SortMode.priceHigh:
          return (((b['price'] as num?)?.toDouble() ?? 0))
              .compareTo(((a['price'] as num?)?.toDouble() ?? 0));
        case _SortMode.newest:
          return ((b['createdAt'] as num?)?.toInt() ?? 0)
              .compareTo(((a['createdAt'] as num?)?.toInt() ?? 0));
      }
    });

    return out;
  }

  Future<void> _notifyAddedToCart(Map<String, dynamic> p) async {
    final settings = AppSettings();
    if (!settings.inAppNotifyCart.value) return;

    await NotificationsService.instance.add(
      title: 'تمت إضافة منتج للسلة',
      body: 'تمت إضافة "${(p['name'] ?? '').toString()}" إلى السلة.',
      target: 'cart',
    );
  }

  Future<void> _pickSizeAndAddToCart(Map<String, dynamic> p) async {
    final sizes = parseProductStringList(p['sizes']);
    final lengths = parseProductStringList(p['lengths']);
    if (sizes.isEmpty && lengths.isEmpty) {
      final cart = CartRepository();
      await cart.addToCart(
        CartItem.fromProduct(
          {...p, 'imageUrl': getPrimaryProductImage(p) ?? p['imageUrl']},
        ),
      );
      await _notifyAddedToCart(p);
      if (!mounted) return;
      final nav = Navigator.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تمت الإضافة للسلة بنجاح! ✓'),
          action: SnackBarAction(
            label: 'عرض السلة',
            onPressed: () => nav
                .push(FadeSlidePageRoute(builder: (_) => const CartScreen())),
          ),
        ),
      );
      return;
    }

    String? picked;
    String? pickedLength;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: StatefulBuilder(
              builder: (ctx2, setLocal) {
                final canSubmit = (sizes.isEmpty ||
                        (picked ?? '').trim().isNotEmpty) &&
                    (lengths.isEmpty || (pickedLength ?? '').trim().isNotEmpty);

                Widget optionButton({
                  required String label,
                  required bool selected,
                  required VoidCallback onTap,
                }) {
                  final cs = Theme.of(ctx2).colorScheme;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTap();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      constraints:
                          const BoxConstraints(minWidth: 76, minHeight: 52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? cs.primary.withValues(alpha: 0.12)
                            : cs.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? cs.primary : cs.outlineVariant,
                          width: selected ? 1.8 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected) ...[
                            Icon(Icons.check_circle_rounded,
                                size: 18, color: cs.primary),
                            const SizedBox(width: 6),
                          ],
                          Text(label,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('اختيار الخيارات',
                        style: Theme.of(ctx2)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text((p['name'] ?? '').toString(),
                        style: Theme.of(ctx2)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    if (sizes.isNotEmpty) ...[
                      Text('المقاس',
                          style: Theme.of(ctx2)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in sizes)
                            optionButton(
                              label: s,
                              selected: picked == s,
                              onTap: () => setLocal(() => picked = s),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final nav = Navigator.of(ctx);
                          final rec = await nav.push<String?>(
                            FadeSlidePageRoute<String?>(
                              builder: (_) => SizeGuideScreen(
                                availableSizes: sizes,
                                productName: (p['name'] ?? '').toString(),
                                productCategory:
                                    (p['category'] ?? '').toString(),
                                excludeProductId: p['id']?.toString(),
                              ),
                            ),
                          );
                          if (!nav.mounted) return;
                          if (rec != null && rec.trim().isNotEmpty) {
                            setLocal(() => picked = rec.trim());
                          }
                        },
                        icon: const Icon(Icons.monitor_weight_outlined),
                        label: const Text('اقترحي لي مقاس بالوزن'),
                      ),
                    ],
                    if (lengths.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('الطول',
                          style: Theme.of(ctx2)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final l in lengths)
                            optionButton(
                              label: l,
                              selected: pickedLength == l,
                              onTap: () => setLocal(() => pickedLength = l),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: Colors.white),
                      onPressed:
                          canSubmit ? () => Navigator.pop(ctx, true) : null,
                      child: Text(canSubmit
                          ? 'إضافة للسلة'
                          : 'اختاري الخيارات المطلوبة'),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    final okSize =
        sizes.isEmpty || (picked != null && picked!.trim().isNotEmpty);
    final okLen = lengths.isEmpty ||
        (pickedLength != null && pickedLength!.trim().isNotEmpty);
    if (ok != true || !okSize || !okLen) return;

    await CartRepository().addToCart(
      CartItem.fromProduct(
        {...p, 'imageUrl': getPrimaryProductImage(p) ?? p['imageUrl']},
        size: picked,
        length: pickedLength,
      ),
    );
    await _notifyAddedToCart(p);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت الإضافة للسلة بنجاح! ✓')));
  }

  Widget _sectionHeader(BuildContext context,
      {required String title, VoidCallback? onMore}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFD4AF37), Color(0xFFFFD76A)],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.16,
                    height: 1.2,
                  ),
            ),
          ),
          if (onMore != null)
            TextButton(
              onPressed: onMore,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'عرض الكل',
                    style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_left_rounded,
                      size: 18, color: cs.onSurfaceVariant),
                ],
              ),
            ),
        ],
      ),
    );
  }

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim()) ?? fallback;
  }

  void _applySmartPreset({
    bool discounts = false,
    bool topRated = false,
    bool newest = false,
  }) {
    HapticFeedback.selectionClick();
    setState(() {
      _sort = newest ? _SortMode.newest : _sort;
      _category = 'الكل';
      _onlyDiscounts = discounts;
      _onlyTopRated = topRated;
      _onlyNewArrivals = newest;
      if (discounts && _minDiscountPct < 40) {
        _minDiscountPct = 40;
      }
      _resetVisible();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToKey(_productsHeaderKey);
    });
  }

  SliverToBoxAdapter _smartFiltersRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget chip({
      required IconData icon,
      required String text,
      required bool active,
      required VoidCallback onTap,
    }) {
      return FilterChip(
        selected: active,
        showCheckmark: false,
        avatar: Icon(
          icon,
          size: 16,
          color: active ? cs.onSurface : cs.onSurfaceVariant,
        ),
        label: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: active ? cs.onSurface : cs.onSurface,
          ),
        ),
        side: BorderSide(
          color: active
              ? cs.onSurface.withValues(alpha: 0.35)
              : cs.outlineVariant.withValues(alpha: 0.9),
        ),
        backgroundColor: cs.surface,
        selectedColor: cs.primary.withValues(alpha: 0.10),
        onSelected: (_) => onTap(),
      );
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              chip(
                icon: Icons.percent_rounded,
                text: 'خصومات +40%',
                active: _onlyDiscounts,
                onTap: () => _applySmartPreset(discounts: !_onlyDiscounts),
              ),
              const SizedBox(width: 8),
              chip(
                icon: Icons.local_fire_department_rounded,
                text: 'الأكثر طلبًا',
                active: _onlyTopRated,
                onTap: () => _applySmartPreset(topRated: !_onlyTopRated),
              ),
              const SizedBox(width: 8),
              chip(
                icon: Icons.new_releases_outlined,
                text: 'وصل حديثًا',
                active: _onlyNewArrivals,
                onTap: () => _applySmartPreset(newest: !_onlyNewArrivals),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _walletCreditStrip(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: ValueListenableBuilder<double>(
          valueListenable: _rewards.walletLyd,
          builder: (context, wallet, _) {
            return ValueListenableBuilder<int>(
              valueListenable: _rewards.points,
              builder: (context, points, __) {
                final hasCredit = wallet > 0.0001;
                final canConvert = points >= RewardsService.minPointsToConvert;

                return Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.9)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.account_balance_wallet_outlined,
                              size: 18, color: cs.onSurface),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            hasCredit
                                ? 'عندك ${wallet.toStringAsFixed(2)} د.ل جاهزة للخصم الآن'
                                : canConvert
                                    ? 'نقاطك جاهزة للتحويل إلى رصيد فوري'
                                    : 'اجمعي نقاط أكثر وفعّلي خصمك القادم',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            FadeSlidePageRoute(
                              builder: (_) => const RewardsScreen(),
                            ),
                          ),
                          child: const Text('النقاط'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  SliverToBoxAdapter _socialProofStrip(
    BuildContext context, {
    required List<Map<String, dynamic>> allDocs,
  }) {
    final cs = Theme.of(context).colorScheme;
    final totalSold = _soldByProductId.values.fold<int>(0, (s, v) => s + v);
    final totalReviews = allDocs.fold<int>(
        0, (s, p) => s + _asInt(p['reviewsCount'], fallback: 0));
    final ratingVals = allDocs
        .map((e) => (e['rating'] as num?)?.toDouble() ?? 0)
        .where((v) => v > 0)
        .toList(growable: false);
    final avgRating = ratingVals.isEmpty
        ? 0
        : ratingVals.reduce((a, b) => a + b) / ratingVals.length;

    Widget pill(IconData icon, String text) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.85)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              text,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            pill(Icons.shopping_bag_outlined, '+$totalSold طلب'),
            if (avgRating > 0)
              pill(Icons.star_rounded, '${avgRating.toStringAsFixed(1)} تقييم'),
            if (totalReviews > 0)
              pill(Icons.reviews_outlined, '$totalReviews مراجعة'),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _editorPickOfDay(
    BuildContext context, {
    required List<Map<String, dynamic>> allDocs,
  }) {
    if (allDocs.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final docs = List<Map<String, dynamic>>.from(allDocs)
      ..sort((a, b) {
        final ra = (a['rating'] as num?)?.toDouble() ?? 0;
        final rb = (b['rating'] as num?)?.toDouble() ?? 0;
        final da = (((a['oldPrice'] as num?)?.toDouble() ?? 0) -
                ((a['price'] as num?)?.toDouble() ?? 0))
            .clamp(0, 1e9);
        final db = (((b['oldPrice'] as num?)?.toDouble() ?? 0) -
                ((b['price'] as num?)?.toDouble() ?? 0))
            .clamp(0, 1e9);
        final scoreA = (ra * 10) + da;
        final scoreB = (rb * 10) + db;
        return scoreB.compareTo(scoreA);
      });

    final p = docs.first;
    final img = getPrimaryProductImage(p) ?? p['imageUrl']?.toString();
    final price = (p['price'] as num?)?.toDouble() ?? 0;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => ProductRoutes.openProduct(context, p),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.85),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: NetworkOrPlaceholderImage(
                    url: img,
                    borderRadius: 0,
                    fit: BoxFit.cover,
                    showLoadingSpinner: false,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.48),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'اختيار اليوم',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  left: 12,
                  bottom: 12,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          (p['name'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        Money.lyd2(price),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _styleReelSection(
    BuildContext context, {
    required List<Map<String, dynamic>> items,
  }) {
    final picks = items.take(6).toList(growable: false);
    if (picks.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, title: '🎬 ستايل موشن'),
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              itemCount: picks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final p = picks[i];
                final img =
                    getPrimaryProductImage(p) ?? p['imageUrl']?.toString();
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => ProductRoutes.openProduct(context, p),
                  child: SizedBox(
                    width: 132,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: NetworkOrPlaceholderImage(
                              url: img,
                              borderRadius: 0,
                              fit: BoxFit.cover,
                              showLoadingSpinner: false,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.42),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: Icon(Icons.play_circle_fill_rounded,
                              color: Colors.white, size: 22),
                        ),
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: Text(
                            (p['name'] ?? '').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _newIn48HoursRail(
    BuildContext context, {
    required List<Map<String, dynamic>> items,
  }) {
    final threshold = DateTime.now()
        .subtract(const Duration(hours: 48))
        .millisecondsSinceEpoch;
    final picks = items
        .where((p) => _asInt(p['createdAt']) >= threshold)
        .take(6)
        .toList(growable: false);
    if (picks.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, title: '🕒 وصل حديثًا خلال 48 ساعة'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                for (int i = 0; i < picks.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14),
                  SizedBox(
                    width: 188,
                    child: ProductCard(
                      product: picks[i],
                      style: ProductCardStyle.commerceGrid,
                      badgeText: 'وصل الآن',
                      badgeBackgroundColor: const Color(0xFFFF3B30),
                      badgeForegroundColor: Colors.white,
                      soldCount:
                          _soldByProductId[(picks[i]['id'] ?? '').toString()] ??
                              0,
                      onTap: () => ProductRoutes.openProduct(context, picks[i]),
                      onAdd: () => _pickSizeAndAddToCart(picks[i]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _bundleLookSection(
    BuildContext context, {
    required List<Map<String, dynamic>> items,
  }) {
    final byId = {
      for (final p in items) (p['id'] ?? '').toString(): p,
    };
    Map<String, dynamic>? syncedLook;
    List<Map<String, dynamic>> syncedPicks = const [];
    List<String> syncedIds = const [];
    for (final look in _completeLooks) {
      final hidden = look['isHidden'];
      final isHidden = hidden is bool
          ? hidden
          : (hidden is num ? hidden.toInt() != 0 : false);
      if (isHidden) continue;
      final ids = (look['productIds'] as List?)
              ?.map((e) => (e ?? '').toString())
              .where((e) => e.trim().isNotEmpty && byId.containsKey(e))
              .toList(growable: false) ??
          const <String>[];
      final picks = ids
          .map((id) => byId[id])
          .whereType<Map<String, dynamic>>()
          .take(4)
          .toList(growable: false);
      if (picks.length >= 2) {
        syncedLook = look;
        syncedIds = ids;
        syncedPicks = picks;
        break;
      }
    }
    if (syncedLook != null) {
      return _cloudCompleteLookSection(
        context,
        look: syncedLook,
        picks: syncedPicks,
        ids: syncedIds,
      );
    }

    if (items.length < 3) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final picks = items.take(3).toList(growable: false);
    final ids = picks
        .map((e) => (e['id'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList();
    if (ids.length < 3) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final total = picks.fold<double>(
        0, (s, p) => s + ((p['price'] as num?)?.toDouble() ?? 0));
    final oldTotal = picks.fold<double>(
        0, (s, p) => s + ((p['oldPrice'] as num?)?.toDouble() ?? 0));
    final hasOld = oldTotal > total && oldTotal > 0;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.9),
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '👗 إطلالة كاملة',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (int i = 0; i < picks.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.add_rounded,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 58,
                        height: 58,
                        child: NetworkOrPlaceholderImage(
                          url: getPrimaryProductImage(picks[i]) ??
                              picks[i]['imageUrl']?.toString(),
                          borderRadius: 0,
                          fit: BoxFit.cover,
                          showLoadingSpinner: false,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                hasOld
                    ? 'بدل ${Money.lyd2(oldTotal)} • الآن ${Money.lyd2(total)}'
                    : 'الإجمالي ${Money.lyd2(total)}',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.push(
                  context,
                  FadeSlidePageRoute(
                    builder: (_) => FilteredProductsScreen(
                      mode: FilteredProductsMode.ids,
                      title: 'إطلالة كاملة',
                      ids: ids,
                    ),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: const Text('تسوق الإطلالة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _cloudCompleteLookSection(
    BuildContext context, {
    required Map<String, dynamic> look,
    required List<Map<String, dynamic>> picks,
    required List<String> ids,
  }) {
    final discount = (look['discountPercent'] is num)
        ? (look['discountPercent'] as num).toDouble().clamp(0.0, 100.0)
        : (double.tryParse('${look['discountPercent'] ?? ''}') ?? 0.0)
            .clamp(0.0, 100.0);
    final total = picks.fold<double>(
      0,
      (s, p) => s + ((p['price'] as num?)?.toDouble() ?? 0),
    );
    final finalTotal = discount > 0 ? total * (1 - discount / 100.0) : total;
    final title = (look['title'] ?? 'إطلالة كاملة').toString().trim();
    final subtitle = (look['subtitle'] ?? '').toString().trim();
    final cta = (look['ctaLabel'] ?? 'تسوق الإطلالة').toString().trim();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.28),
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '👗 ${title.isEmpty ? 'إطلالة كاملة' : title}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < picks.length; i++) ...[
                      if (i > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.add_rounded,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 58,
                          height: 58,
                          child: NetworkOrPlaceholderImage(
                            url: getPrimaryProductImage(picks[i]) ??
                                picks[i]['imageUrl']?.toString(),
                            borderRadius: 0,
                            fit: BoxFit.cover,
                            showLoadingSpinner: false,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                discount > 0
                    ? 'بدل ${Money.lyd2(total)} • الآن ${Money.lyd2(finalTotal)}'
                    : 'الإجمالي ${Money.lyd2(total)}',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.push(
                  context,
                  FadeSlidePageRoute(
                    builder: (_) => FilteredProductsScreen(
                      mode: FilteredProductsMode.ids,
                      title: title.isEmpty ? 'إطلالة كاملة' : title,
                      ids: ids,
                    ),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: Text(cta.isEmpty ? 'تسوق الإطلالة' : cta),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _recentlyViewedRail(
    BuildContext context, {
    required List<Map<String, dynamic>> allDocs,
  }) {
    final byId = {
      for (final p in allDocs) (p['id'] ?? '').toString(): p,
    };

    return SliverToBoxAdapter(
      child: ValueListenableBuilder<List<String>>(
        valueListenable: _recentViewed.recentIds,
        builder: (context, ids, _) {
          final picks = ids
              .map((id) => byId[id])
              .whereType<Map<String, dynamic>>()
              .take(6)
              .toList(growable: false);

          if (picks.isEmpty) {
            return const SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(context, title: '👀 تابعتي آخر مرة'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Row(
                  children: [
                    for (int i = 0; i < picks.length; i++) ...[
                      if (i > 0) const SizedBox(width: 14),
                      SizedBox(
                        width: 188,
                        child: ProductCard(
                          product: picks[i],
                          style: ProductCardStyle.commerceGrid,
                          badgeText: 'شوهد مؤخراً',
                          badgeBackgroundColor: const Color(0xFF5C6BC0),
                          badgeForegroundColor: Colors.white,
                          soldCount: _soldByProductId[
                                  (picks[i]['id'] ?? '').toString()] ??
                              0,
                          onTap: () =>
                              ProductRoutes.openProduct(context, picks[i]),
                          onAdd: () => _pickSizeAndAddToCart(picks[i]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int? _remainingStock(Map<String, dynamic> p) {
    final stockRaw = p['stock'] ?? p['quantity'] ?? p['stockQty'];
    final stock = _asInt(stockRaw, fallback: -1);
    if (stock <= 0) return null;
    final sold = _soldByProductId[(p['id'] ?? '').toString()] ?? 0;
    final rem = stock - sold;
    if (rem < 0) return 0;
    return rem;
  }

  SliverToBoxAdapter _lowStockRail(
    BuildContext context, {
    required List<Map<String, dynamic>> allDocs,
  }) {
    final picks = allDocs
        .where((p) {
          final rem = _remainingStock(p);
          return rem != null && rem > 0 && rem <= 5;
        })
        .take(6)
        .toList(growable: false);

    if (picks.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, title: '⏳ آخر القطع'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                for (int i = 0; i < picks.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14),
                  SizedBox(
                    width: 190,
                    child: ProductCard(
                      product: picks[i],
                      style: ProductCardStyle.commerceGrid,
                      badgeText: 'باقي ${_remainingStock(picks[i])} قطع',
                      badgeBackgroundColor: const Color(0xFFD32F2F),
                      badgeForegroundColor: Colors.white,
                      soldCount:
                          _soldByProductId[(picks[i]['id'] ?? '').toString()] ??
                              0,
                      onTap: () => ProductRoutes.openProduct(context, picks[i]),
                      onAdd: () => _pickSizeAndAddToCart(picks[i]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  SliverPadding _heroSection(BuildContext context,
      {required List<String> images}) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final year = DateTime.now().year;

    return SliverPadding(
      padding: EdgeInsets.zero,
      sliver: SliverToBoxAdapter(
        child: Container(
          height: 300,
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: images.isEmpty
                    ? ColoredBox(
                        color: isDark ? cs.surfaceContainerHighest : _lightGrey,
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          // Pause auto-rotation while the user is interacting.
                          if (n is ScrollStartNotification) {
                            _pauseHeroCarouselAuto(
                                resumeAfter: const Duration(seconds: 3));
                          } else if (n is ScrollEndNotification) {
                            _pauseHeroCarouselAuto(
                                resumeAfter: const Duration(seconds: 2));
                          }
                          return false;
                        },
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapDown: (_) => _pauseHeroCarouselAuto(
                              resumeAfter: const Duration(seconds: 3)),
                          child: PageView.builder(
                            controller: _heroCarouselCtl,
                            itemCount: images.length,
                            onPageChanged: (i) {
                              _heroCarouselIndex.value = i;
                              if (images.isNotEmpty) {
                                final next = images[(i + 1) % images.length];
                                _prefetchHeroImage(context, next);
                              }
                            },
                            itemBuilder: (context, i) {
                              return Semantics(
                                label:
                                    'صورة ${i + 1} من ${images.length} للأكثر مبيعاً',
                                image: true,
                                child: NetworkOrPlaceholderImage(
                                  url: images[i],
                                  borderRadius: 0,
                                  fit: BoxFit.cover,
                                  showLoadingSpinner: false,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
              ),

              // Subtle overlay to keep the label readable.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          cs.surface.withValues(alpha: 0.10),
                          cs.surface.withValues(alpha: 0.02),
                          cs.surface.withValues(alpha: 0.10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Editorial label box with the season message.
              PositionedDirectional(
                top: 12,
                end: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.34),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _tr('أحدث التشكيلات ✨', 'New Collection ✨'),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _tr(
                          'موسم $year • قطع مميزة',
                          'Season $year • Signature pieces',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.84),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              // Editorial call-to-action panel over the hero image.
              PositionedDirectional(
                bottom: 18,
                start: 18,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.34),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tr('أحدث التشكيلات ✨', 'New Collection ✨'),
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.2,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _tr(
                            'اختيارات مختارة بلمسة راقية لكل مناسبة.',
                            'Curated elegance for every occasion.',
                          ),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.86),
                                    fontWeight: FontWeight.w700,
                                    height: 1.35,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Dots indicator (professional cue + quick navigation).
              if (images.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        child: ValueListenableBuilder<int>(
                          valueListenable: _heroCarouselIndex,
                          builder: (context, currentIndex, _) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(images.length, (i) {
                              final selected = i == currentIndex;
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    _pauseHeroCarouselAuto(
                                        resumeAfter:
                                            const Duration(seconds: 4));
                                    if (_heroCarouselCtl.hasClients) {
                                      _heroCarouselCtl.animateToPage(
                                        i,
                                        duration:
                                            const Duration(milliseconds: 280),
                                        curve: Curves.easeOut,
                                      );
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    width: selected ? 18 : 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: selected
                                          ? Colors.white
                                          : Colors.white
                                              .withValues(alpha: 0.38),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _editorialIntro(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.surfaceContainerLow,
                cs.surfaceContainer,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: cs.outlineVariant.withValues(alpha: 0.72)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.82)),
                      ),
                      child: Text(
                        'مجموعة مختارة ✨',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                              color: cs.onSurface,
                            ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'أناقتك تبدأ من هنا ✨',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.3,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'تشكيلات مناسبات، قطع فاخرة، وأسعار واضحة بتجربة تسوق سريعة على الجوال.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonal(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            _scrollToKey(_productsHeaderKey);
                          },
                          child: const Text('تسوقي الآن'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            _scrollToKey(_newCollectionKey);
                          },
                          child: const Text('أحدث المنتجات'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cs.surfaceContainerHighest, cs.surface],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.74)),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 30,
                  color: cs.tertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _storefrontTabsStrip(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget tabChip({
      required String label,
      required IconData icon,
      required VoidCallback onTap,
    }) {
      return ActionChip(
        avatar: Icon(icon, size: 16, color: cs.onSurfaceVariant),
        label: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.85)),
        backgroundColor: cs.surface,
      );
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              tabChip(
                label: 'أحدث المنتجات',
                icon: Icons.auto_awesome_outlined,
                onTap: () => _scrollToKey(_newCollectionKey),
              ),
              const SizedBox(width: 8),
              tabChip(
                label: 'الأكثر مبيعاً',
                icon: Icons.local_fire_department_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    FadeSlidePageRoute(
                      builder: (_) => const FilteredProductsScreen(
                        mode: FilteredProductsMode.best,
                        title: 'الأكثر مبيعاً',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              tabChip(
                label: 'فساتين مناسبات',
                icon: Icons.checkroom_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    FadeSlidePageRoute(
                      builder: (_) => const FilteredProductsScreen(
                        mode: FilteredProductsMode.category,
                        title: 'قسم السهرة',
                        category: 'قسم السهرة',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _testimonialsSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, title: 'آراء العميلات'),
          SizedBox(
            height: 152,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              itemBuilder: (context, i) {
                return Container(
                  width: 280,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.78),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(
                          5,
                          (_) => const Icon(Icons.star_rounded,
                              size: 15, color: Color(0xFFD4AF37)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Text(
                          _customerTestimonials[i],
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    height: 1.45,
                                    color: cs.onSurface,
                                  ),
                        ),
                      ),
                      Text(
                        'عميلة موثقة',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemCount: _customerTestimonials.length,
            ),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _featuredCollectionStrip(BuildContext context,
      {required List<Map<String, dynamic>> items}) {
    final cs = Theme.of(context).colorScheme;
    final take = items.take(3).toList(growable: false);
    if (take.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: cs.outlineVariant.withValues(alpha: 0.72)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مختارات البوتيك',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.2,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'قطع منتقاة بعناية لواجهة أنيقة أقرب لأسلوب جورجينا.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                    height: 1.35,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _scrollToKey(_productsHeaderKey);
                    },
                    child: const Text('تصفّح الكل'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final p in take)
                    Builder(
                      builder: (ctx) {
                        final image = getPrimaryProductImage(p) ??
                            p['imageUrl']?.toString() ??
                            '';
                        final price =
                            double.tryParse((p['price'] ?? '').toString()) ??
                                0.0;
                        final oldPrice =
                            double.tryParse((p['oldPrice'] ?? '').toString()) ??
                                0.0;
                        final hasDiscount = oldPrice > 0 && oldPrice > price;
                        return GestureDetector(
                          onTap: () => ProductRoutes.openProduct(ctx, p),
                          child: Container(
                            width: MediaQuery.sizeOf(context).width > 600
                                ? 180
                                : 148,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color:
                                      cs.outlineVariant.withValues(alpha: 0.7)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: AspectRatio(
                                        aspectRatio: 0.86,
                                        child: NetworkOrPlaceholderImage(
                                          url: image,
                                          borderRadius: 0,
                                          fit: BoxFit.cover,
                                          showLoadingSpinner: false,
                                        ),
                                      ),
                                    ),
                                    if (hasDiscount)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: cs.error,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            '-${((1 - (price / oldPrice)) * 100).clamp(1, 90).round()}%',
                                            style: TextStyle(
                                              color: cs.onError,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  (p['name'] ?? '').toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  Money.lyd(price, decimals: 0),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: cs.primary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                if (hasDiscount)
                                  Text(
                                    Money.lyd(oldPrice, decimals: 0),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: cs.onSurfaceVariant,
                                          fontWeight: FontWeight.w800,
                                          decoration:
                                              TextDecoration.lineThrough,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _brandStoryStrip(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: cs.outlineVariant.withValues(alpha: 0.72)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 15,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'لأنكِ تستحقين الأجمل ✨',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'فساتين وموديلات مختارة بعناية تجمع بين الأناقة والأنوثة واللمسة الراقية في كل ظهور.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill(context, 'جودة تليق بكِ'),
                  _pill(context, 'موديلات متجددة'),
                  _pill(context, 'شحن سريع وآمن'),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.72),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.workspace_premium_rounded,
                          color: cs.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'كل قطعة في الواجهة مختارة لتظهر المتجر بشكل أنثوي فخم وواضح على الهاتف.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                              height: 1.35,
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
    );
  }

  Widget _pill(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
      ),
    );
  }

  SliverToBoxAdapter _trustBarSliver(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: TrustBar(
          onTapDetails: () => showTrustDetailsSheet(context),
        ),
      ),
    );
  }

  SliverToBoxAdapter _newCollectionRail(BuildContext context,
      {required List<Map<String, dynamic>> items}) {
    final take = items.take(6).toList(growable: false);
    if (take.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    final w = MediaQuery.of(context).size.width;
    final compact = w < 390;
    // Adaptive rail metrics to keep cards elegant on both compact and large phones.
    final double cardW =
        (w * (compact ? 0.60 : 0.53)).clamp(162.0, 232.0).toDouble();
    final double featuredW = (cardW * 1.10).clamp(176.0, 252.0).toDouble();
    final railGap = compact ? 12.0 : 18.0;
    return SliverToBoxAdapter(
      child: Column(
        key: _newCollectionKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, title: 'أحدث المنتجات'),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Text(
              'وصل حديثاً — موديلات الموسم بتفاصيل أنيقة.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < take.length; i++) ...[
                  if (i > 0) SizedBox(width: railGap),
                  Builder(
                    builder: (ctx) {
                      final p = take[i];
                      final sold =
                          _soldByProductId[(p['id'] ?? '').toString()] ?? 0;
                      final bool featured = i < 2;
                      return SizedBox(
                        width: featured ? featuredW : cardW,
                        child: ProductCard(
                          product: p,
                          large: false,
                          style: ProductCardStyle.commerceGrid,
                          soldCount: sold,
                          badgeText: featured ? 'وصل حديثًا' : 'جديد',
                          badgeBackgroundColor: const Color(0xFFFF3B30),
                          badgeForegroundColor: Colors.white,
                          onTap: () => ProductRoutes.openProduct(ctx, p),
                          onAdd: () => _pickSizeAndAddToCart(p),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _bestSellersRail(BuildContext context,
      {required List<Map<String, dynamic>> items}) {
    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final w = MediaQuery.of(context).size.width;
    final compact = w < 390;
    final double cardW =
        (w * (compact ? 0.60 : 0.53)).clamp(162.0, 232.0).toDouble();
    final double featuredW = (cardW * 1.10).clamp(176.0, 252.0).toDouble();
    final railGap = compact ? 12.0 : 18.0;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, title: 'الأكثر مبيعًا'),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Text(
              'اختيارات العميلات الأعلى طلبًا هذا الأسبوع.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0) SizedBox(width: railGap),
                  Builder(
                    builder: (ctx) {
                      final p = items[i];
                      final sold =
                          _soldByProductId[(p['id'] ?? '').toString()] ?? 0;
                      final bool featured = i < 2;
                      return SizedBox(
                        width: featured ? featuredW : cardW,
                        child: ProductCard(
                          product: p,
                          large: false,
                          style: ProductCardStyle.commerceGrid,
                          soldCount: sold,
                          badgeText: featured
                              ? 'اختيار العميلات'
                              : 'الأكثر مبيعًا #${i + 1}',
                          badgeBackgroundColor: const Color(0xFF4CAF50),
                          badgeForegroundColor: Colors.white,
                          onTap: () => ProductRoutes.openProduct(ctx, p),
                          onAdd: () => _pickSizeAndAddToCart(p),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _specialOffers(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : _black;

    return SliverToBoxAdapter(
      child: ValueListenableBuilder<HomeOffersConfig>(
        valueListenable: HomeOffersService.instance.config,
        builder: (context, cfg, _) {
          final items = cfg.items.where((e) => e.enabled).toList();
          final linkedIds = <String>{
            for (final it in items) ...it.productIds,
          };
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: isDark
                      ? const [Color(0xFF9A7A1C), Color(0xFF2B1B24)]
                      : const [Color(0xFFD4AF37), Color(0xFFFFB6C1)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color:
                        Colors.white.withValues(alpha: isDark ? 0.12 : 0.28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cfg.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900, color: fg),
                    ),
                    const SizedBox(height: 8),
                    for (final it in items)
                      _offerLine(
                        it,
                        onTap: it.productIds.isNotEmpty
                            ? () {
                                Navigator.push(
                                  context,
                                  FadeSlidePageRoute(
                                    builder: (_) => FilteredProductsScreen(
                                      mode: FilteredProductsMode.ids,
                                      title: 'منتجات العرض',
                                      ids: it.productIds,
                                    ),
                                  ),
                                );
                              }
                            : null,
                      ),
                    if (items.isEmpty)
                      Text(
                        'لا توجد عروض حالياً.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: fg,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    const SizedBox(height: 2),
                    if (cfg.subtitle.trim().isNotEmpty)
                      Text(
                        cfg.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: fg.withValues(alpha: 0.82),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.35 : 0.85),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'ينتهي العرض خلال:',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800),
                            ),
                          ),
                          ValueListenableBuilder<Duration>(
                            valueListenable: _offersRemaining,
                            builder: (context, d, _) {
                              final total = d.inSeconds.clamp(0, 24 * 3600);
                              final h = total ~/ 3600;
                              final m = (total % 3600) ~/ 60;
                              final s = total % 60;
                              return Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _countdownPill(context,
                                      value: _fmt2(h), label: 'ساعة'),
                                  _countdownPill(context,
                                      value: _fmt2(m), label: 'دقيقة'),
                                  _countdownPill(context,
                                      value: _fmt2(s), label: 'ثانية'),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: isDark
                                ? cs.surfaceContainerHighest
                                : Colors.white,
                            foregroundColor: isDark ? cs.onSurface : _black),
                        onPressed: () {
                          final ids = linkedIds.toList(growable: false);
                          Navigator.push(
                            context,
                            FadeSlidePageRoute(
                              builder: (_) => FilteredProductsScreen(
                                mode: ids.isNotEmpty
                                    ? FilteredProductsMode.ids
                                    : FilteredProductsMode.sale,
                                title: cfg.title,
                                ids: ids.isNotEmpty ? ids : null,
                              ),
                            ),
                          );
                        },
                        child: Text(cfg.ctaLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  SliverToBoxAdapter _adStrip(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: cs.outlineVariant.withValues(alpha: 0.72)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'إعلان ممول',
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
        ),
      ),
    );
  }

  SliverToBoxAdapter _campaignsSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget card(MarketingCampaignItem item) {
      final accent =
          item.kind == MarketingCampaignKind.gift ? cs.tertiary : cs.primary;
      final label = item.kind == MarketingCampaignKind.gift ? 'هدية' : 'مسابقة';
      final sideText = item.kind == MarketingCampaignKind.gift
          ? (item.giftValue.isEmpty ? 'مفاجأة' : item.giftValue)
          : (item.prize.isEmpty ? 'سحب' : item.prize);

      return Container(
        width: 280,
        margin: const EdgeInsetsDirectional.only(end: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: .85)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    item.kind == MarketingCampaignKind.gift
                        ? Icons.card_giftcard_rounded
                        : Icons.emoji_events_outlined,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        sideText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              item.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
            ),
            if (item.badge.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.badge,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return SliverToBoxAdapter(
      child: ValueListenableBuilder<List<MarketingCampaignItem>>(
        valueListenable: HomeOffersService.instance.gifts,
        builder: (context, gifts, _) {
          return ValueListenableBuilder<List<MarketingCampaignItem>>(
            valueListenable: HomeOffersService.instance.competitions,
            builder: (context, competitions, __) {
              final all = <MarketingCampaignItem>[
                ...gifts.where((e) => e.enabled),
                ...competitions.where((e) => e.enabled),
              ];
              if (all.isEmpty) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(context, title: '🎁 الهدايا والمسابقات'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Text(
                      'فرص إضافية للخصم والهدايا والمشاركة داخل التطبيق.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 0, 0, 10),
                    child: Row(
                      children: [for (final item in all) card(item)],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _offerLine(HomeOfferItem it, {VoidCallback? onTap}) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final text = it.text;

    final isDiscount =
        it.kind == HomeOfferKind.discount || text.contains('خصم');
    final isVip = it.kind == HomeOfferKind.vip ||
        text.toUpperCase().contains('VIP') ||
        text.contains('تغليف');
    final isShipping =
        it.kind == HomeOfferKind.shipping || text.contains('شحن');
    final isPayment = it.kind == HomeOfferKind.payment || text.contains('دفع');

    IconData icon = Icons.check_circle_outline;
    if (isDiscount) icon = Icons.percent_rounded;
    if (isVip) icon = Icons.card_giftcard_rounded;
    if (isShipping) icon = Icons.local_shipping_outlined;
    if (isPayment) icon = Icons.lock_outline_rounded;

    String? tag;
    if (isDiscount) tag = 'خصم';
    if (isVip) tag = 'VIP';
    if (isShipping) tag = 'شحن';
    if (isPayment) tag = 'دفع';

    final bg = isDark
        ? Colors.black.withValues(alpha: 0.26)
        : Colors.white.withValues(alpha: 0.72);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.55);

    final iconBg = (isDiscount
            ? cs.primaryContainer
            : isVip
                ? cs.tertiaryContainer
                : isShipping
                    ? cs.secondaryContainer
                    : isPayment
                        ? cs.secondaryContainer
                        : cs.surfaceContainerHighest)
        .withValues(alpha: 0.75);

    final iconFg = isDiscount
        ? cs.onPrimaryContainer
        : isVip
            ? cs.onTertiaryContainer
            : isShipping
                ? cs.onSecondaryContainer
                : isPayment
                    ? cs.onSecondaryContainer
                    : cs.onSurface;

    final interactive = onTap != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: 0.10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: iconFg),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white : _black,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                  ),
                ),
                if (tag != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : _black.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: (isDark ? Colors.white : _black)
                              .withValues(alpha: 0.14)),
                    ),
                    child: Text(
                      tag,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isDark ? Colors.white : _black,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                    ),
                  ),
                ],
                if (interactive) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_left_rounded,
                    size: 20,
                    color: (isDark ? Colors.white : _black)
                        .withValues(alpha: 0.85),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _featuresSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = const [
      {
        'icon': Icons.local_shipping_outlined,
        'title': 'شحن سريع',
        'subtitle': 'توصيل خلال 2-4 أيام داخل ليبيا'
      },
      {
        'icon': Icons.card_giftcard_outlined,
        'title': 'تغليف هدايا',
        'subtitle': 'تغليف VIP فاخر مجاني لكل الطلبات'
      },
      {
        'icon': Icons.lock_outline,
        'title': 'دفع آمن',
        'subtitle': 'دفع عند الاستلام أو بالبطاقة'
      },
      {
        'icon': Icons.cached_rounded,
        'title': 'إرجاع سهل',
        'subtitle': 'إرجاع مجاني خلال 14 يوماً'
      },
    ];
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, title: 'مميزات المتجر'),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: LayoutBuilder(
              builder: (ctx, c) {
                final cols = c.maxWidth >= 900 ? 4 : 2;
                const crossSpacing = 10.0;
                const mainSpacing = 10.0;
                // Give tiles more vertical room to avoid RenderFlex overflow
                // on compact devices / large text scales.
                final baseRatio = cols == 4 ? 0.96 : 1.02;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: crossSpacing,
                    mainAxisSpacing: mainSpacing,
                    childAspectRatio: baseRatio,
                  ),
                  itemBuilder: (ctx2, i) {
                    final it = items[i];
                    final title = (it['title'] as String?) ?? '';
                    final subtitle = (it['subtitle'] as String?) ?? '';
                    final icon = it['icon'] as IconData;
                    final bool compactTile = c.maxWidth < 420;

                    // Small tint per tile to feel premium but calm.
                    final Color iconBg = switch (icon) {
                      Icons.local_shipping_outlined =>
                        cs.secondaryContainer.withValues(alpha: 0.75),
                      Icons.card_giftcard_outlined =>
                        cs.tertiaryContainer.withValues(alpha: 0.75),
                      Icons.lock_outline =>
                        cs.primaryContainer.withValues(alpha: 0.75),
                      _ => cs.surfaceContainerHighest.withValues(alpha: 0.75),
                    };
                    final Color iconFg = switch (icon) {
                      Icons.local_shipping_outlined => cs.onSecondaryContainer,
                      Icons.card_giftcard_outlined => cs.onTertiaryContainer,
                      Icons.lock_outline => cs.onPrimaryContainer,
                      _ => cs.onSurface,
                    };

                    return BouncyCard(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.75),
                      ),
                      padding: const EdgeInsets.all(10),
                      onTap: () =>
                          _showFeatureDetails(title: title, subtitle: subtitle),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: compactTile ? 38 : 42,
                            height: compactTile ? 38 : 42,
                            decoration: BoxDecoration(
                              color: iconBg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              icon,
                              color: iconFg,
                              size: compactTile ? 20 : 22,
                            ),
                          ),
                          SizedBox(height: compactTile ? 6 : 8),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          SizedBox(height: compactTile ? 3 : 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                          ),
                          const Spacer(),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'تفاصيل',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: cs.primary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.chevron_left,
                                    size: 16, color: cs.primary),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _footer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: isDark ? cs.surfaceContainer : const Color(0xFF141518),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (isDark ? cs.outlineVariant : Colors.white)
                  .withValues(alpha: 0.20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AVEA FASHION',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'تجربة تسوّق نسائية فاخرة بواجهة سريعة وآمنة، مع شحن ودعم مستمر.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _footerLink(context, 'سياسة الإرجاع'),
                  _footerLink(context, 'سياسة الخصوصية'),
                  _footerLink(context, 'الشروط والأحكام'),
                  _footerLink(context, 'الأسئلة الشائعة'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footerLink(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.02),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.26)),
      ),
      onPressed: () {
        Widget? screen;
        if (label == 'سياسة الإرجاع') {
          screen = const ReturnPolicyScreen();
        } else if (label == 'سياسة الخصوصية') {
          screen = const LegalDocumentScreen(
            title: 'سياسة الخصوصية',
            assetPath: 'PRIVACY_POLICY.md',
          );
        } else if (label == 'الشروط والأحكام') {
          screen = const LegalDocumentScreen(
            title: 'الشروط والأحكام',
            assetPath: 'TERMS_OF_SERVICE.md',
          );
        } else if (label == 'الأسئلة الشائعة') {
          screen = const FaqScreen();
        }

        if (screen == null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$label (قريباً)')));
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen!),
        );
      },
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favs = FavoritesService();

    return ValueListenableBuilder<Set<String>>(
      valueListenable: favs.favorites,
      builder: (context, favSet, _) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _productsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              // Keep the UI friendly, but log the real error for debugging.
              debugPrint(
                  'Home productsStream error: ${snapshot.error}\n${snapshot.stackTrace}');
              return EmptyState(
                icon: Icons.wifi_off_outlined,
                title: 'تعذر تحميل المنتجات',
                subtitle: 'تحققي من الاتصال أو أعيدي المحاولة.',
                action: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.tonal(
                      onPressed: () {
                        // If the stream terminated with an error, create a fresh stream.
                        setState(
                            () => _productsStream = _repo.productsStream());
                        _repo.refresh();
                      },
                      child: const Text('إعادة المحاولة'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        try {
                          await _repo.resetDemoData();
                          if (!context.mounted) return;
                          setState(
                              () => _productsStream = _repo.productsStream());
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('تمت إعادة تهيئة بيانات المنتجات')));
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('تعذر إعادة التهيئة: $e')));
                        }
                      },
                      child: const Text('إعادة تهيئة البيانات'),
                    ),
                  ],
                ),
              );
            }
            if (!snapshot.hasData) return const ProductGridSkeleton();

            final allDocs = snapshot.data ?? const <Map<String, dynamic>>[];

            // Categories meta.
            final categories = <String>{};
            final catImage = <String, String?>{};
            final catCount = <String, int>{};
            for (final p in allDocs) {
              final c = (p['category'] ?? '').toString().trim();
              if (c.isEmpty) continue;
              categories.add(c);
              catImage.putIfAbsent(c,
                  () => getPrimaryProductImage(p) ?? p['imageUrl']?.toString());
              catCount[c] = (catCount[c] ?? 0) + 1;
            }
            final categoryList = categories.toList()..sort();
            final hasCategory = _category == 'الكل' ||
                categoryList
                    .any((c) => CategoryNormalizer.equals(c, _category));
            if (!hasCategory) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final stillHas = _category == 'الكل' ||
                    categoryList
                        .any((c) => CategoryNormalizer.equals(c, _category));
                if (!stillHas) {
                  setState(() => _category = 'الكل');
                }
              });
            }

            var docs = _applyQuery(allDocs);

            if (widget.favoritesOnly) {
              docs = docs
                  .where((p) => favSet.contains(p['id']?.toString() ?? ''))
                  .toList();
            }

            // Price bounds (for the filter sheet) based on the current base result set
            // (search + favorites), before additional toggles are applied.
            double? minPriceBound;
            double? maxPriceBound;
            for (final p in docs) {
              final price = (p['price'] as num?)?.toDouble();
              if (price == null || price <= 0) continue;
              minPriceBound = math.min(minPriceBound ?? price, price);
              maxPriceBound = math.max(maxPriceBound ?? price, price);
            }

            if (_priceMin != null || _priceMax != null) {
              final lo = _priceMin ?? double.negativeInfinity;
              final hi = _priceMax ?? double.infinity;
              docs = docs.where((p) {
                final price = (p['price'] as num?)?.toDouble() ?? 0.0;
                return price >= lo && price <= hi;
              }).toList();
            }

            if (_onlyDiscounts) {
              docs = docs.where((p) {
                final price = (p['price'] as num?)?.toDouble() ?? 0.0;
                final oldPrice = (p['oldPrice'] as num?)?.toDouble() ?? 0.0;
                if (oldPrice <= 0) return false;
                if (price >= oldPrice) return false;
                final pct = ((oldPrice - price) / oldPrice) * 100.0;
                return pct >= _minDiscountPct;
              }).toList();
            }

            if (_onlyTopRated) {
              docs = docs.where((p) {
                final rating = (p['rating'] as num?)?.toDouble() ?? 0.0;
                return rating >= 4.2;
              }).toList();
            }

            if (_onlyNewArrivals) {
              final threshold = DateTime.now()
                  .subtract(const Duration(days: 30))
                  .millisecondsSinceEpoch;
              docs = docs.where((p) {
                final createdAt = (p['createdAt'] as num?)?.toInt() ?? 0;
                return createdAt >= threshold;
              }).toList();
            }

            if (_category != 'الكل') {
              docs = docs
                  .where((p) => CategoryNormalizer.equals(
                        (p['category'] ?? '').toString(),
                        _category,
                      ))
                  .toList();
            }

            // Build derived collections from the full catalog (not the filtered docs)
            // so the Home layout stays rich even when filters return 0 results.
            _ensureDerivedCollections(allDocs);
            final newest = _derivedNewestAll;
            final best6 = _derivedBest6All;
            final heroImages = _derivedHeroImages;

            // Keep the hero carousel controller/timer in sync with the computed images.
            // Do it AFTER this frame to avoid setState during build.
            _scheduleHeroCarouselSync(heroImages);

            if (docs.isEmpty) {
              // Instead of replacing the whole Home with an empty page, keep the
              // main layout visible and show an in-page empty message.
              return RefreshIndicator(
                onRefresh: () async {
                  _repo.refresh();
                  await _loadSoldCounts();
                },
                child: CustomScrollView(
                  controller: _scrollCtl,
                  cacheExtent: _scrollCacheExtent,
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    if (!widget.favoritesOnly) ...[
                      _heroSection(context, images: heroImages),
                      _quickCategoriesBar(context, catImage: catImage),
                      _editorialIntro(context),
                      _storefrontTabsStrip(context),
                      _featuredCollectionStrip(context, items: newest),
                      _brandStoryStrip(context),
                      if (_settings.homeShowSmartFilters.value)
                        _smartFiltersRow(context),
                      if (_settings.homeShowWalletStrip.value)
                        _walletCreditStrip(context),
                      if (_settings.homeShowSocialProof.value)
                        _socialProofStrip(context, allDocs: allDocs),
                      if (_settings.homeShowPickOfDay.value)
                        _editorPickOfDay(context, allDocs: allDocs),
                      if (_settings.homeShowStyleReel.value)
                        _styleReelSection(context, items: newest),
                      _trustBarSliver(context),
                      if (_settings.homeShowNew48h.value)
                        _newIn48HoursRail(context, items: newest),
                      if (_settings.homeShowBundle.value)
                        _bundleLookSection(context, items: newest),
                      if (_settings.homeShowRecent.value)
                        _recentlyViewedRail(context, allDocs: allDocs),
                      if (_settings.homeShowLowStock.value)
                        _lowStockRail(context, allDocs: allDocs),
                      _newCollectionRail(context, items: newest),
                      _bestSellersRail(context, items: best6),
                      _testimonialsSection(context),
                      _specialOffers(context),
                      _adStrip(context),
                      _campaignsSection(context),
                      _featuresSection(context),
                    ],
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: EmptyState(
                            icon: Icons.search_off_outlined,
                            title: allDocs.isEmpty
                                ? 'لا توجد منتجات'
                                : 'لا توجد نتائج',
                            subtitle: allDocs.isEmpty
                                ? 'أضيفي منتجات من لوحة التحكم أو أعيدي المحاولة.'
                                : 'جرّبي تغيير البحث أو التصنيف، أو امسحي الفلاتر.',
                            action: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: [
                                FilledButton.tonal(
                                  onPressed: () {
                                    _searchCtl.clear();
                                    setState(() {
                                      _category = 'الكل';
                                      _onlyDiscounts = false;
                                      _onlyTopRated = false;
                                      _onlyNewArrivals = false;
                                      _minDiscountPct = 40.0;
                                      _priceMin = null;
                                      _priceMax = null;
                                      _resetVisible();
                                    });
                                  },
                                  child: const Text('مسح الفلاتر'),
                                ),
                                OutlinedButton(
                                  onPressed: () {
                                    setState(() => _productsStream =
                                        _repo.productsStream());
                                    _repo.refresh();
                                  },
                                  child: const Text('إعادة المحاولة'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!widget.favoritesOnly) _footer(context),
                  ],
                ),
              );
            }

            final visibleDocs =
                docs.take(_visibleCount).toList(growable: false);

            final screenW = MediaQuery.of(context).size.width;
            final gridSpacing = screenW < 390 ? 6.0 : 8.0;
            final gridCols = screenW >= 1100 ? 4 : (screenW >= 760 ? 3 : 2);

            return RefreshIndicator(
              onRefresh: () async {
                _repo.refresh();
                await _loadSoldCounts();
              },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLowest,
                              Theme.of(context).colorScheme.surface,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.depth == 0 && n is ScrollStartNotification) {
                        _isPrimaryScrolling = true;
                        _pauseHeroCarouselAuto(
                          resumeAfter: const Duration(seconds: 4),
                        );
                      } else if (n.depth == 0 && n is ScrollEndNotification) {
                        _isPrimaryScrolling = false;
                        final d = _offersEndsAt.difference(DateTime.now());
                        _offersRemaining.value =
                            d.isNegative ? Duration.zero : d;
                        _pauseHeroCarouselAuto(
                          resumeAfter: const Duration(seconds: 2),
                        );
                      }
                      if (n is ScrollUpdateNotification &&
                          n.metrics.extentAfter < 500 &&
                          _visibleCount < docs.length) {
                        _loadMoreProducts(docs.length);
                      }
                      return false;
                    },
                    child: CustomScrollView(
                      controller: _scrollCtl,
                      cacheExtent: _scrollCacheExtent,
                      physics: const ClampingScrollPhysics(),
                      slivers: [
                        if (!widget.favoritesOnly) ...[
                          _heroSection(context, images: heroImages),
                          _quickCategoriesBar(context, catImage: catImage),
                          _editorialIntro(context),
                          _storefrontTabsStrip(context),
                          _featuredCollectionStrip(context, items: newest),
                          _brandStoryStrip(context),
                          if (_settings.homeShowSmartFilters.value)
                            _smartFiltersRow(context),
                          if (_settings.homeShowWalletStrip.value)
                            _walletCreditStrip(context),
                          if (_settings.homeShowSocialProof.value)
                            _socialProofStrip(context, allDocs: allDocs),
                          if (_settings.homeShowPickOfDay.value)
                            _editorPickOfDay(context, allDocs: allDocs),
                          if (_settings.homeShowStyleReel.value)
                            _styleReelSection(context, items: newest),

                          // Trust bar: show key benefits right after the hero.
                          _trustBarSliver(context),

                          if (_settings.homeShowNew48h.value)
                            _newIn48HoursRail(context, items: newest),
                          if (_settings.homeShowBundle.value)
                            _bundleLookSection(context, items: newest),
                          if (_settings.homeShowRecent.value)
                            _recentlyViewedRail(context, allDocs: allDocs),
                          if (_settings.homeShowLowStock.value)
                            _lowStockRail(context, allDocs: allDocs),
                          _newCollectionRail(context, items: newest),
                          _bestSellersRail(context, items: best6),
                          _testimonialsSection(context),
                          _specialOffers(context),
                          _adStrip(context),
                          _campaignsSection(context),
                          _featuresSection(context),
                        ],
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                            child: Row(
                              key: _productsHeaderKey,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.favoritesOnly
                                            ? 'المفضلة'
                                            : 'إطلالات لا تُقاوم',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.favoritesOnly
                                            ? 'كل القطع التي أضفتِها للمفضلة في مكان واحد.'
                                            : 'مختارات يومية بتصميمات عصرية وأسعار واضحة.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.09),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.18),
                                    ),
                                  ),
                                  child: Text(
                                    '${docs.length} منتج',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                  ),
                                ),
                                if (_soldLoading)
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          sliver: widget.favoritesOnly
                              ? SliverGrid.builder(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: gridCols,
                                    mainAxisSpacing: gridSpacing,
                                    crossAxisSpacing: gridSpacing,
                                    childAspectRatio: 0.55,
                                  ),
                                  itemCount: visibleDocs.length,
                                  addAutomaticKeepAlives: false,
                                  addRepaintBoundaries: false,
                                  addSemanticIndexes: false,
                                  itemBuilder: (context, index) {
                                    final data = visibleDocs[index];
                                    final sold = _soldByProductId[
                                            (data['id'] ?? '').toString()] ??
                                        0;
                                    return ProductCard(
                                      key: ValueKey(
                                        (data['id'] ?? index).toString(),
                                      ),
                                      product: data,
                                      large: false,
                                      style: ProductCardStyle.commerceGrid,
                                      hideOptionsSummary: _onlyDiscounts,
                                      soldCount: sold,
                                      onTap: () => ProductRoutes.openProduct(
                                          context, data),
                                      onAdd: () => _pickSizeAndAddToCart(data),
                                    );
                                  },
                                )
                              : SliverGrid.builder(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: gridCols,
                                    mainAxisSpacing: gridSpacing,
                                    crossAxisSpacing: gridSpacing,
                                    childAspectRatio: 0.55,
                                  ),
                                  itemCount: visibleDocs.length,
                                  addAutomaticKeepAlives: false,
                                  addRepaintBoundaries: false,
                                  addSemanticIndexes: false,
                                  itemBuilder: (context, index) {
                                    final data = visibleDocs[index];
                                    final sold = _soldByProductId[
                                            (data['id'] ?? '').toString()] ??
                                        0;
                                    return ProductCard(
                                      key: ValueKey(
                                        (data['id'] ?? index).toString(),
                                      ),
                                      product: data,
                                      large: false,
                                      style: ProductCardStyle.commerceGrid,
                                      hideOptionsSummary: _onlyDiscounts,
                                      extraBottomPadding: 6,
                                      soldCount: sold,
                                      onTap: () => ProductRoutes.openProduct(
                                          context, data),
                                      onAdd: () => _pickSizeAndAddToCart(data),
                                    );
                                  },
                                ),
                        ),
                        if (visibleDocs.length < docs.length)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                              child: Center(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _loadMoreProducts(docs.length),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                  ),
                                  label: Text(
                                    'عرض المزيد (${docs.length - visibleDocs.length})',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (!widget.favoritesOnly) _footer(context),
                        const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: _floatingFiltersButton(
                      context,
                      categories: categoryList,
                      catCount: catCount,
                      catImage: catImage,
                      minPriceBound: minPriceBound,
                      maxPriceBound: maxPriceBound,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
