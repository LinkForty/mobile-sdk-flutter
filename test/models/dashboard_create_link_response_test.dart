import 'package:flutter_test/flutter_test.dart';
import 'package:linkforty_flutter/models/dashboard_create_link_response.dart';

void main() {
  group('DashboardCreateLinkResponse', () {
    test('supports value equality', () {
      final r1 = DashboardCreateLinkResponse(id: '1', shortCode: 'abc');
      final r2 = DashboardCreateLinkResponse(id: '1', shortCode: 'abc');

      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));
    });

    test('toJson and fromJson work correctly', () {
      final response = DashboardCreateLinkResponse(id: '1', shortCode: 'abc');
      final json = response.toJson();

      expect(json['id'], '1');
      expect(json['shortCode'], 'abc');

      final deserialized = DashboardCreateLinkResponse.fromJson(json);
      expect(deserialized, equals(response));
    });
  });
}
