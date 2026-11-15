// lib/services/prakriti_api.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PrakritiApi {
  static const String _base = "https://sih-backend-oiz6.onrender.com";
  static const String _doshaPath = "/predict/dosha";

  /// Returns decoded JSON as Map<String,dynamic>.
  /// Throws on non-200 or parsing error.
  static Future<Map<String, dynamic>> postDosha(
    Map<String, dynamic> body, {
    Map<String, String>? extraHeaders,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = Uri.parse('$_base$_doshaPath');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (extraHeaders != null) ...extraHeaders,
    };

    http.Response response;
    try {
      response = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(timeout);
    } on TimeoutException {
      throw TimeoutException('Request timed out after ${timeout.inSeconds}s');
    } on http.ClientException catch (e) {
      throw Exception('HTTP client error: ${e.message}');
    }

    // Check status code
    if (response.statusCode != 200) {
      // Try to decode server error message
      String serverMsg = response.body;
      try {
        final parsed = jsonDecode(response.body);
        if (parsed is Map && parsed['detail'] != null) serverMsg = parsed['detail'].toString();
      } catch (_) {}
      throw Exception('API error ${response.statusCode}: $serverMsg');
    }

    // Decode JSON body
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      // If API returns non-map (list, string), wrap into map
      return {'result': decoded};
    } catch (e) {
      throw Exception('Failed to parse JSON from server: $e\nRaw: ${response.body}');
    }
  }
}
