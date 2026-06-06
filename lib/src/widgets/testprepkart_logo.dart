import 'package:flutter/material.dart';

/// Horizontal TestprepKart wordmark (blue + gold) for admin chrome.
class TestprepKartLogo extends StatelessWidget {
  const TestprepKartLogo({
    super.key,
    this.height = 36,
    this.maxWidth = 168,
  });

  static const assetPath = 'assets/images/testprepkart_logo.png';

  final double height;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: height,
      width: maxWidth,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      filterQuality: FilterQuality.high,
      semanticLabel: 'TestprepKart',
    );
  }
}
