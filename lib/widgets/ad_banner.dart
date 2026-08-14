import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ads_service.dart';
import 'ad_banner_web_surface_stub.dart'
    if (dart.library.html) 'ad_banner_web_surface.dart';

class AdBanner extends StatefulWidget {
  /// If false, the widget always renders nothing.
  final bool enabled;

  const AdBanner({super.key, this.enabled = true});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _loading = false;
  String? _lastError;

  void _showDebugDetails(String title, String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _maybeLoad();
    }
  }

  Future<void> _maybeLoad() async {
    final ads = AdsService.instance;
    if (!widget.enabled || !ads.isEnabled || _loading) return;

    setState(() {
      _loading = true;
      _lastError = null;
    });

    // Ensure SDK is initialized.
    await ads.init();

    final unitId = ads.bannerUnitId;
    if (unitId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _lastError = 'لم يتم ضبط رقم وحدة إعلان البانر.';
      });
      return;
    }

    assert(() {
      debugPrint('[AdBanner] Loading banner. unitId=$unitId');
      return true;
    }());

    final ad = BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          assert(() {
            debugPrint('[AdBanner] Banner loaded. unitId=$unitId');
            return true;
          }());
          if (!mounted) return;
          setState(() {
            _loaded = true;
            _loading = false;
            _lastError = null;
            _ad = ad as BannerAd;
          });
        },
        onAdFailedToLoad: (ad, err) {
          assert(() {
            debugPrint(
                '[AdBanner] Banner failed to load. unitId=$unitId error=$err');
            return true;
          }());
          ad.dispose();
          if (!mounted) return;
          final details =
              'LoadAdError(code: ${err.code}, domain: ${err.domain}, message: ${err.message})';
          setState(() {
            _loaded = false;
            _loading = false;
            _ad = null;
            _lastError = details;
          });
        },
      ),
    );

    // Assign early so dispose can clean it up even if load is slow.
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    if (kIsWeb) {
      final adClient = (dotenv.env['ADSENSE_CLIENT'] ??
              const String.fromEnvironment('ADSENSE_CLIENT', defaultValue: ''))
          .trim();
      final adSlot = (dotenv.env['ADSENSE_SLOT'] ??
              const String.fromEnvironment('ADSENSE_SLOT', defaultValue: ''))
          .trim();
      final hasClient = adClient.startsWith('ca-pub-');
      final hasSlot = RegExp(r'^\d{6,}$').hasMatch(adSlot);
      final bannerConfigured = hasClient && hasSlot;

      final cs = Theme.of(context).colorScheme;
      return Container(
        alignment: Alignment.center,
        width: double.infinity,
        height: bannerConfigured ? 98 : 66,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              cs.primary.withValues(alpha: 0.14),
              cs.tertiary.withValues(alpha: 0.10),
            ],
          ),
          border: Border(
            top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.75)),
            bottom:
                BorderSide(color: cs.outlineVariant.withValues(alpha: 0.75)),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: cs.primary.withValues(alpha: 0.32)),
              ),
              child: Text(
                'إعلان',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: bannerConfigured
                  ? AdSenseBannerSurface(adClient: adClient, adSlot: adSlot)
                  : Text(
                      hasClient
                          ? '✨ Auto Ads مفعّلة — أضيفي ADSENSE_SLOT فقط لو تبين بانر ثابت داخل التطبيق'
                          : '✨ أضيفي ADSENSE_CLIENT و ADSENSE_SLOT لتفعيل الربح الحقيقي على الويب',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
            ),
            if (!bannerConfigured) ...[
              const SizedBox(width: 8),
              Icon(Icons.campaign_outlined, size: 18, color: cs.onSurface),
            ],
          ],
        ),
      );
    }

    final ad = _ad;
    if (!AdsService.instance.isEnabled) return const SizedBox.shrink();
    if (!_loaded || ad == null) {
      final cs = Theme.of(context).colorScheme;
      final error = (_lastError ?? '').trim();
      final title =
          error.isEmpty ? 'جاري تحميل الإعلان...' : 'الإعلان غير متاح حالياً';
      final subtitle = error.isEmpty
          ? 'سيظهر الإعلان هنا عند توفره.'
          : (kDebugMode
              ? error
              : 'قد يحتاج AdMob بعض الوقت أو لا يوجد إعلان مناسب الآن.');
      return InkWell(
        onTap: error.isEmpty
            ? null
            : () {
                if (kDebugMode) {
                  _showDebugDetails('AdMob Banner', error);
                } else {
                  _maybeLoad();
                }
              },
        child: Container(
          alignment: Alignment.center,
          width: double.infinity,
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
            border: Border(
              top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.7)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                error.isEmpty
                    ? Icons.hourglass_top_rounded
                    : Icons.campaign_outlined,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              if (error.isNotEmpty) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'إعادة المحاولة',
                  visualDensity: VisualDensity.compact,
                  onPressed: _maybeLoad,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
