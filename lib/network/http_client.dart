// Copyright 2026 The Link Forty Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'http_method.dart';
import 'http_response.dart';

/// Abstraction over HTTP calls for testability
abstract class HttpClient {
  /// Executes an HTTP request and returns the raw response
  Future<HttpResponse> execute({
    required String url,
    required HttpMethod method,
    Uint8List? body,
    Map<String, String>? headers,
  });
}

/// HTTP client implementation using the http package
class HttpClientImpl implements HttpClient {
  final http.Client _client;
  final Duration timeout;

  HttpClientImpl({
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  @override
  Future<HttpResponse> execute({
    required String url,
    required HttpMethod method,
    Uint8List? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(url);
    final requestHeaders = headers ?? {};

    http.Response response;

    try {
      switch (method) {
        case HttpMethod.get:
          response = await _client
              .get(uri, headers: requestHeaders)
              .timeout(timeout);
          break;
        case HttpMethod.post:
          response = await _client
              .post(uri, headers: requestHeaders, body: body)
              .timeout(timeout);
          break;
        case HttpMethod.put:
          response = await _client
              .put(uri, headers: requestHeaders, body: body)
              .timeout(timeout);
          break;
        case HttpMethod.delete:
          response = await _client
              .delete(uri, headers: requestHeaders)
              .timeout(timeout);
          break;
      }

      return HttpResponse(
        statusCode: response.statusCode,
        body: response.bodyBytes,
      );
    } catch (e) {
      rethrow;
    }
  }

  void close() {
    _client.close();
  }
}
