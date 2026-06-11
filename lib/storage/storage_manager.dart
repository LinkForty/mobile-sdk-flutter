// Copyright 2026 The Link Forty Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../link_forty_logger.dart';
import '../models/deep_link_data.dart';
import '../models/event_request.dart';
import 'storage_keys.dart';

/// Protocol for SharedPreferences to enable mocking in tests
abstract class SharedPreferencesProtocol {
  Future<bool> setString(String key, String value);
  String? getString(String key);
  Future<bool> setBool(String key, bool value);
  bool? getBool(String key);
  Future<bool> remove(String key);
}

/// Wrapper for SharedPreferences to conform to the protocol
class SharedPreferencesWrapper implements SharedPreferencesProtocol {
  final SharedPreferences _prefs;

  SharedPreferencesWrapper(this._prefs);

  @override
  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  Future<bool> remove(String key) => _prefs.remove(key);
}

/// Manages persistent data for the SDK using the platform's local storage.
///
/// This manager handles caching of attribution results, the install ID,
/// and the offline event queue to ensure data survives app restarts.
class StorageManager implements StorageManagerProtocol {
  final SharedPreferencesProtocol _prefs;

  /// Creates a storage manager with the specified SharedPreferencesProtocol
  ///
  /// - [prefs]: The SharedPreferencesProtocol instance to use
  StorageManager(this._prefs);

  /// Factory constructor to create a storage manager asynchronously
  static Future<StorageManager> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageManager(SharedPreferencesWrapper(prefs));
  }

  // MARK: - Install ID

  /// Saves the install ID
  ///
  /// - [installId]: The install ID to save
  /// - Returns: True if successful, false otherwise
  @override
  Future<bool> saveInstallId(String installId) async {
    try {
      return await _prefs.setString(StorageKeys.installId, installId);
    } catch (e) {
      LinkFortyLogger.log('Failed to save install ID: $e');
      return false;
    }
  }

  /// Retrieves the saved install ID
  ///
  /// - Returns: The install ID if it exists, null otherwise
  @override
  String? getInstallId() {
    return _prefs.getString(StorageKeys.installId);
  }

  // MARK: - Install Data

  /// Saves the deep link data from attribution
  ///
  /// - [data]: The deep link data to save
  /// - Returns: True if successful, false otherwise
  @override
  Future<bool> saveInstallData(DeepLinkData data) async {
    try {
      final json = jsonEncode(data.toJson());
      return await _prefs.setString(StorageKeys.installData, json);
    } catch (e) {
      LinkFortyLogger.log('Failed to encode install data: $e');
      return false;
    }
  }

  /// Retrieves the saved deep link data
  ///
  /// - Returns: The deep link data if it exists and can be decoded, null otherwise
  @override
  DeepLinkData? getInstallData() {
    try {
      final jsonString = _prefs.getString(StorageKeys.installData);
      if (jsonString == null) return null;

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return DeepLinkData.fromJson(json);
    } catch (e) {
      LinkFortyLogger.log('Failed to decode install data: $e');
      return null;
    }
  }

  // MARK: - First Launch

  /// Checks if this is the first launch of the app
  ///
  /// - Returns: True if this is the first launch, false otherwise
  @override
  bool isFirstLaunch() {
    // If the key doesn't exist, it defaults to null, so we check if it's not true
    // We store "hasLaunched" and check if it's false
    final hasLaunched = _prefs.getBool(StorageKeys.firstLaunch) ?? false;
    return !hasLaunched;
  }

  /// Marks that the app has launched (no longer first launch)
  ///
  /// - Returns: True if successful, false otherwise
  @override
  Future<bool> setHasLaunched() async {
    try {
      return await _prefs.setBool(StorageKeys.firstLaunch, true);
    } catch (e) {
      LinkFortyLogger.log('Failed to set has launched: $e');
      return false;
    }
  }

  // MARK: - Event Queue

  /// Saves the event queue to persistent storage
  ///
  /// - [events]: List of events to persist
  /// - Returns: True if successful
  @override
  Future<bool> saveEventQueue(List<EventRequest> events) async {
    try {
      final jsonList = events.map((e) => e.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      return await _prefs.setString(StorageKeys.eventQueue, jsonString);
    } catch (e) {
      LinkFortyLogger.log('Failed to save event queue: $e');
      return false;
    }
  }

  /// Loads the event queue from persistent storage
  ///
  /// - Returns: List of persisted events, empty if none
  @override
  List<EventRequest> loadEventQueue() {
    try {
      final jsonString = _prefs.getString(StorageKeys.eventQueue);
      if (jsonString == null) return [];
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((e) => EventRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      LinkFortyLogger.log('Failed to load event queue: $e');
      return [];
    }
  }

  // MARK: - Attribution

  /// Persists the active last-click attribution context (as JSON).
  ///
  /// - [json]: The encoded `ActiveAttribution`
  /// - Returns: True if successful
  @override
  Future<bool> saveAttribution(String json) async {
    try {
      return await _prefs.setString(StorageKeys.attribution, json);
    } catch (e) {
      LinkFortyLogger.log('Failed to save attribution: $e');
      return false;
    }
  }

  /// Retrieves the persisted active attribution context (as JSON), or null.
  @override
  String? getAttribution() {
    return _prefs.getString(StorageKeys.attribution);
  }

  /// Removes the persisted active attribution context.
  @override
  Future<bool> removeAttribution() async {
    try {
      return await _prefs.remove(StorageKeys.attribution);
    } catch (e) {
      LinkFortyLogger.log('Failed to remove attribution: $e');
      return false;
    }
  }

  // MARK: - Clear Data

  /// Clears all stored SDK data
  ///
  /// This removes install ID, install data, first launch flag, event queue,
  /// and the active attribution context.
  ///
  /// - Returns: True if all removals were successful, false otherwise
  @override
  Future<bool> clearAll() async {
    try {
      final results = await Future.wait([
        _prefs.remove(StorageKeys.installId),
        _prefs.remove(StorageKeys.installData),
        _prefs.remove(StorageKeys.firstLaunch),
        _prefs.remove(StorageKeys.eventQueue),
        _prefs.remove(StorageKeys.attribution),
      ]);

      // Return true only if all removals were successful
      return results.every((result) => result);
    } catch (e) {
      LinkFortyLogger.log('Failed to clear all data: $e');
      return false;
    }
  }
}

/// Protocol for dependency injection in tests
abstract class StorageManagerProtocol {
  Future<bool> saveInstallId(String installId);
  String? getInstallId();
  Future<bool> saveInstallData(DeepLinkData data);
  DeepLinkData? getInstallData();
  bool isFirstLaunch();
  Future<bool> setHasLaunched();
  Future<bool> saveEventQueue(List<EventRequest> events);
  List<EventRequest> loadEventQueue();
  Future<bool> saveAttribution(String json);
  String? getAttribution();
  Future<bool> removeAttribution();
  Future<bool> clearAll();
}
