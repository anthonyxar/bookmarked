import 'dart:convert';
import 'package:http/http.dart' as http;

const _baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}

class ApiClient {
  String? token;

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse('$_baseUrl$path').replace(queryParameters: query);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  dynamic _decode(http.Response res) {
    if (res.statusCode == 204 || res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  void _checkStatus(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    String message = 'Something went wrong (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] != null) message = body['detail'].toString();
    } catch (_) {}
    throw ApiException(message, res.statusCode);
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final res = await http.get(_uri(path, query), headers: _headers);
    _checkStatus(res);
    return _decode(res);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final res = await http.post(_uri(path), headers: _headers, body: body == null ? null : jsonEncode(body));
    _checkStatus(res);
    return _decode(res);
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    final res = await http.patch(_uri(path), headers: _headers, body: body == null ? null : jsonEncode(body));
    _checkStatus(res);
    return _decode(res);
  }

  Future<void> delete(String path) async {
    final res = await http.delete(_uri(path), headers: _headers);
    _checkStatus(res);
  }
}
