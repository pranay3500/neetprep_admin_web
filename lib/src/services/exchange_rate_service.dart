import 'dart:convert';

import 'package:http/http.dart' as http;

class AdminExchangeRateService {
  static const double fallbackInrPerUsd = 83.5;

  static Future<double> fetchInrToUsdRate() async {
    try {
      final response = await http
          .get(Uri.parse('https://open.er-api.com/v6/latest/INR'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rates = body['rates'];
        if (rates is Map<String, dynamic>) {
          final usd = rates['USD'];
          final value = usd is num ? usd.toDouble() : double.tryParse('$usd');
          if (value != null && value > 0) return value;
        }
      }
    } catch (_) {}
    return 1 / fallbackInrPerUsd;
  }

  static int inrToUsd(int inr, double rate) {
    if (inr <= 0) return 0;
    return (inr * rate).round();
  }
}
