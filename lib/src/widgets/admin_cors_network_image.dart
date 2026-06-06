import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Network image for admin web previews.
///
/// Flutter web's default [Image.network] fetches bytes via XHR (CORS required).
/// Many CDNs (e.g. `data.testprepkart.com`) allow mobile/app loads but block
/// admin origins — statusCode 0 in the browser. On web we prefer an HTML
/// `<img>` element, which can display the asset without a CORS preflight.
class AdminCorsNetworkImage extends StatelessWidget {
  const AdminCorsNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.height,
    this.width,
    this.errorLabel = 'Could not load preview',
  });

  final String url;
  final BoxFit fit;
  final double? height;
  final double? width;
  final String errorLabel;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      height: height,
      width: width,
      fit: fit,
      webHtmlElementStrategy: kIsWeb
          ? WebHtmlElementStrategy.prefer
          : WebHtmlElementStrategy.never,
      errorBuilder: (_, __, ___) => SizedBox(
        height: height,
        width: width,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              errorLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ),
      ),
    );
  }
}
