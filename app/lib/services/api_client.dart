import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');

/// Resolves a server-relative path (e.g. an avatar or cover upload URL) to an
/// absolute URL, since the Flutter web app and the API are served from
/// different origins. Already-absolute URLs (external search covers) pass through.
String resolveMediaUrl(String path) => path.startsWith('http') ? path : '$apiBaseUrl$path';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}

class ApiClient {
  String? token;

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse('$apiBaseUrl$path').replace(queryParameters: query);

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

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final res = await http.put(_uri(path), headers: _headers, body: body == null ? null : jsonEncode(body));
    _checkStatus(res);
    return _decode(res);
  }

  Future<void> delete(String path) async {
    final res = await http.delete(_uri(path), headers: _headers);
    _checkStatus(res);
  }

  Future<dynamic> uploadFile(String path, {required String field, required List<int> bytes, required String filename, String? contentType}) async {
    final request = http.MultipartRequest('POST', _uri(path));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes(field, bytes, filename: filename, contentType: contentType != null ? MediaType.parse(contentType) : null));

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    _checkStatus(res);
    return _decode(res);
  }
}
