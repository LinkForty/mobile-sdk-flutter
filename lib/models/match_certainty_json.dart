// Copyright 2026 The Link Forty Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// Lenient readers for the install-match certainty fields
/// (`confidenceScore`, `matchedFactors`, `attributionMethod`,
/// `competingLinks`).
///
/// These fields are informational, so a missing or unexpected value is read as
/// `null` rather than failing the whole install response or deep link.
library;

/// Reads a JSON number as an `int`, truncating a double (`2.0` → `2`).
int? intFromJsonOrNull(Object? json) => json is num ? json.toInt() : null;

/// Reads a JSON number as a `double`.
double? doubleFromJsonOrNull(Object? json) =>
    json is num ? json.toDouble() : null;

/// Reads a JSON string.
String? stringFromJsonOrNull(Object? json) => json is String ? json : null;

/// Reads a JSON array of strings, skipping any element that is not a string.
List<String>? stringListFromJsonOrNull(Object? json) =>
    json is List ? json.whereType<String>().toList() : null;
