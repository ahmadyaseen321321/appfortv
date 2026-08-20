import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final http.Client client;

  ApiClient({http.Client? client}) : client = client ?? http.Client();

  Future<Map<String, dynamic>> get({
    required String baseUrl,
    required String path,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(baseUrl + path).replace(queryParameters: queryParameters);
    try {
      final response = await client.get(uri, headers: headers).timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        throw Exception("Invalid response format");
      } else {
        throw Exception("Server returned status code: ${response.statusCode}");
      }
    } catch (e) {
      rethrow;
    }
  }
}
