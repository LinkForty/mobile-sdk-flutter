// Copyright 2026 The Link Forty Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:linkforty_flutter/attribution/attribution_context.dart';
import 'package:linkforty_flutter/storage/storage_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageManager storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = StorageManager(SharedPreferencesWrapper(prefs));
  });

  test('fresh context has a session but no link', () {
    final ctx = AttributionContext(storage: storage);
    final stamp = ctx.getStamp();
    expect(stamp.sessionId, isNotEmpty);
    expect(stamp.attributedLinkId, isNull);
    expect(stamp.attributedClickId, isNull);
    expect(stamp.linkOpenedAt, isNull);
  });

  test('recordDeepLinkOpen stamps the link', () async {
    final ctx = AttributionContext(storage: storage);
    await ctx.recordDeepLinkOpen(linkId: 'link-A', clickId: 'click-1');

    final stamp = ctx.getStamp();
    expect(stamp.attributedLinkId, 'link-A');
    expect(stamp.attributedClickId, 'click-1');
    expect(stamp.linkOpenedAt, isNotNull);
  });

  test('newest open supersedes and rotates the session', () async {
    final ctx = AttributionContext(storage: storage);
    await ctx.recordDeepLinkOpen(linkId: 'link-A');
    final first = ctx.getStamp();

    await ctx.recordDeepLinkOpen(linkId: 'link-B');
    final second = ctx.getStamp();

    expect(second.attributedLinkId, 'link-B'); // newest wins
    expect(second.sessionId, isNot(first.sessionId)); // session rotates
  });

  test('organic open (no linkId) is a no-op', () async {
    final ctx = AttributionContext(storage: storage);
    await ctx.recordDeepLinkOpen(linkId: 'link-A');
    final sessionAfterLink = ctx.getStamp().sessionId;

    await ctx.recordDeepLinkOpen(linkId: null);
    final stamp = ctx.getStamp();

    expect(stamp.attributedLinkId, 'link-A');
    expect(stamp.sessionId, sessionAfterLink);
  });

  test('active context persists across instances; session is new', () async {
    final first = AttributionContext(storage: storage);
    await first.recordDeepLinkOpen(linkId: 'link-A');

    final second = AttributionContext(storage: storage);
    final stamp = second.getStamp();

    expect(stamp.attributedLinkId, 'link-A');
    expect(stamp.sessionId, isNot(first.getStamp().sessionId));
  });

  test('clear removes the link and rotates the session', () async {
    final ctx = AttributionContext(storage: storage);
    await ctx.recordDeepLinkOpen(linkId: 'link-A');
    final before = ctx.getStamp().sessionId;

    await ctx.clear();
    final stamp = ctx.getStamp();

    expect(stamp.attributedLinkId, isNull);
    expect(stamp.sessionId, isNot(before));

    // Cleared state must not be restored by a new instance.
    final reopened = AttributionContext(storage: storage);
    expect(reopened.getStamp().attributedLinkId, isNull);
  });
}
