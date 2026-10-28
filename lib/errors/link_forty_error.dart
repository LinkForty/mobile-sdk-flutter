// Copyright 2026 The Link Forty Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// Errors that can occur when using the LinkForty SDK
abstract class LinkFortyError implements Exception {
  final String message;
  final Object? cause;

  const LinkFortyError(this.message, [this.cause]);

  @override
  String toString() => message;
}

/// The SDK has not been initialized
///
/// Call `LinkForty.instance.initialize(config:)` before using other SDK methods
class NotInitializedError extends LinkFortyError {
  const NotInitializedError()
    : super('LinkForty SDK is not initialized. Call initialize() first.');
}

/// The SDK has already been initialized
///
/// `initialize(config:)` can only be called once
class AlreadyInitializedError extends LinkFortyError {
  const AlreadyInitializedError()
    : super('LinkForty SDK has already been initialized.');
}

/// The configuration is invalid
class InvalidConfigurationError extends LinkFortyError {
  InvalidConfigurationError(String detail)
    : super('Invalid configuration: $detail');
}

/// A network error occurred
class NetworkError extends LinkFortyError {
  NetworkError(Object cause)
    : super('Network error: ${_extractMessage(cause)}', cause);

  static String _extractMessage(Object error) {
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return error.toString();
  }
}

/// The server returned an invalid response
class InvalidResponseError extends LinkFortyError {
  final int? statusCode;
  final String? responseMessage;

  InvalidResponseError({this.statusCode, this.responseMessage})
    : super(_buildMessage(statusCode, responseMessage));

  static String _buildMessage(int? statusCode, String? responseMessage) {
    final buffer = StringBuffer('Invalid server response');
    if (statusCode != null) {
      buffer.write(' (status: $statusCode)');
    }
    if (responseMessage != null) {
      buffer.write(': $responseMessage');
    }
    return buffer.toString();
  }
}

/// Failed to decode the response
class DecodingError extends LinkFortyError {
  DecodingError(Object cause)
    : super('Failed to decode response: ${_extractMessage(cause)}', cause);

  static String _extractMessage(Object error) {
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return error.toString();
  }
}

/// Failed to encode the request
class EncodingError extends LinkFortyError {
  EncodingError(Object cause)
    : super('Failed to encode request: ${_extractMessage(cause)}', cause);

  static String _extractMessage(Object error) {
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return error.toString();
  }
}

/// Invalid event data
class InvalidEventDataError extends LinkFortyError {
  InvalidEventDataError(String detail) : super('Invalid event data: $detail');
}

/// Invalid deep link URL
class InvalidDeepLinkUrlError extends LinkFortyError {
  InvalidDeepLinkUrlError(String detail)
    : super('Invalid deep link URL: $detail');
}

/// API key is required for this operation
class MissingApiKeyError extends LinkFortyError {
  const MissingApiKeyError()
    : super(
        'API key is required for this operation. Provide an apiKey in LinkFortyConfig.',
      );
}

/// Template ID is required for link creation
class MissingTemplateIdError extends LinkFortyError {
  const MissingTemplateIdError()
    : super(
        'A template ID is required for link creation. Provide a templateId in CreateLinkOptions.',
      );
}
