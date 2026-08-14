import 'package:flutter/widgets.dart';

class AdSenseBannerSurface extends StatelessWidget {
  final String adClient;
  final String adSlot;

  const AdSenseBannerSurface({
    super.key,
    required this.adClient,
    required this.adSlot,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
