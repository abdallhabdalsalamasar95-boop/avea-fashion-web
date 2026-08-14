// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class AdSenseBannerSurface extends StatefulWidget {
  final String adClient;
  final String adSlot;

  const AdSenseBannerSurface({
    super.key,
    required this.adClient,
    required this.adSlot,
  });

  @override
  State<AdSenseBannerSurface> createState() => _AdSenseBannerSurfaceState();
}

class _AdSenseBannerSurfaceState extends State<AdSenseBannerSurface> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType =
        'adsense-banner-${widget.adClient}-${widget.adSlot}-${DateTime.now().microsecondsSinceEpoch}';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final wrapper = html.DivElement()
        ..style.width = '100%'
        ..style.height = '90px'
        ..style.display = 'flex'
        ..style.alignItems = 'center'
        ..style.justifyContent = 'center'
        ..style.overflow = 'hidden';

      final host = html.DivElement()
        ..style.width = '100%'
        ..style.height = '90px'
        ..style.position = 'relative'
        ..style.display = 'block';

      final ins = html.Element.tag('ins')
        ..className = 'adsbygoogle'
        ..setAttribute('style',
            'display:inline-block;width:100%;height:90px;text-align:center;')
        ..setAttribute('data-ad-client', widget.adClient)
        ..setAttribute('data-ad-slot', widget.adSlot)
        ..setAttribute('data-ad-format', 'auto')
        ..setAttribute('data-full-width-responsive', 'true');

      final fallback = html.DivElement()
        ..setAttribute('aria-label', 'adsense-fallback')
        ..style.position = 'absolute'
        ..style.top = '0'
        ..style.right = '0'
        ..style.bottom = '0'
        ..style.left = '0'
        ..style.display = 'none'
        ..style.alignItems = 'center'
        ..style.justifyContent = 'center'
        ..style.background = 'rgba(250,250,250,0.92)'
        ..style.border = '1px solid rgba(0,0,0,0.08)'
        ..style.borderRadius = '10px'
        ..style.fontFamily =
            'system-ui, -apple-system, Segoe UI, Roboto, sans-serif'
        ..style.fontSize = '12px'
        ..style.fontWeight = '600'
        ..style.color = '#555'
        ..text = 'يجري تجهيز الإعلان…';

      void showFallback(String message) {
        fallback.text = message;
        fallback.style.display = 'flex';
      }

      void hideFallback() {
        fallback.style.display = 'none';
      }

      // Initial state while AdSense resolves fill.
      showFallback('يجري تجهيز الإعلان…');

      // Watch AdSense fill status on the ins tag.
      html.MutationObserver((mutations, observer) {
        final status = (ins.getAttribute('data-ad-status') ?? '').trim();
        if (status == 'filled') {
          hideFallback();
          return;
        }
        if (status == 'unfilled') {
          showFallback('لا يوجد إعلان مناسب حالياً — تصفحي أحدث المنتجات ✨');
        }
      }).observe(
        ins,
        attributes: true,
        attributeFilter: ['data-ad-status'],
      );

      host.children
        ..add(ins)
        ..add(fallback)
        ..add(
          html.ScriptElement()
            ..type = 'text/javascript'
            ..text =
                'try {(adsbygoogle = window.adsbygoogle || []).push({});} catch (_) {}',
        );
      wrapper.children.add(host);

      Future<void>.delayed(const Duration(seconds: 10), () {
        if (!mounted) return;
        final status = (ins.getAttribute('data-ad-status') ?? '').trim();
        if (status.isEmpty) {
          // The script may be blocked by privacy tools or unavailable.
          showFallback('تعذر تحميل الإعلان حالياً.');
        }
      });

      return wrapper;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 90,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
