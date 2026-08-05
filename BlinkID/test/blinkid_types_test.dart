// Regression guard for the v8001 upgrade: several CountryId/RegionId/DocumentTypeId values had
// typo'd @JsonValue strings that could never match either native SDK (e.g. Country.bambodia
// instead of cambodia, Region.alagos instead of alagoas, DocumentType.eId instead of eid) — they
// simply never matched, silently. These counts (verified against both native SDKs' compiled
// enums) and round-trip checks catch any value falling out of sync with native again.
import 'package:blinkid_flutter/blinkid_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Classification enum counts match both native SDKs', () {
    test('CountryId has all 257 native values', () {
      expect(CountryId.values.length, 257);
    });

    test('RegionId has all 150 native values', () {
      expect(RegionId.values.length, 150);
    });

    test('DocumentTypeId has all 91 native values', () {
      expect(DocumentTypeId.values.length, 91);
    });

    test('FieldType has all 74 native values', () {
      expect(FieldType.values.length, 74);
    });
  });

  group('Classification enum @JsonValue round-trips', () {
    test('every CountryId value round-trips through DocumentFilter JSON', () {
      for (final value in CountryId.values) {
        final wire = DocumentFilter(country: value).toJson()['country'];
        expect(wire, isNotNull, reason: 'CountryId.${value.name} has no @JsonValue');
        final decoded = DocumentFilter.fromJson({'country': wire}).country;
        expect(decoded, value, reason: 'CountryId.${value.name} round-trip mismatch via "$wire"');
      }
    });

    test('every RegionId value round-trips through DocumentFilter JSON', () {
      for (final value in RegionId.values) {
        final wire = DocumentFilter(region: value).toJson()['region'];
        expect(wire, isNotNull, reason: 'RegionId.${value.name} has no @JsonValue');
        final decoded = DocumentFilter.fromJson({'region': wire}).region;
        expect(decoded, value, reason: 'RegionId.${value.name} round-trip mismatch via "$wire"');
      }
    });

    test('every DocumentTypeId value round-trips through DocumentFilter JSON', () {
      for (final value in DocumentTypeId.values) {
        final wire = DocumentFilter(documentType: value).toJson()['documentType'];
        expect(wire, isNotNull, reason: 'DocumentTypeId.${value.name} has no @JsonValue');
        final decoded = DocumentFilter.fromJson({'documentType': wire}).documentType;
        expect(decoded, value, reason: 'DocumentTypeId.${value.name} round-trip mismatch via "$wire"');
      }
    });

    test('every FieldType value round-trips through DetailedFieldType JSON', () {
      for (final value in FieldType.values) {
        final wire = DetailedFieldType(value, AlphabetType.latin).toJson()['fieldType'];
        expect(wire, isNotNull, reason: 'FieldType.${value.name} has no @JsonValue');
        final decoded = DetailedFieldType.fromJson({
          'fieldType': wire,
          'alphabetType': 'latin',
        }).fieldType;
        expect(decoded, value, reason: 'FieldType.${value.name} round-trip mismatch via "$wire"');
      }
    });
  });

  group('Deprecated Country/Region/DocumentType typedefs', () {
    test('still resolve to the v8001-renamed *Id enums', () {
      // ignore: deprecated_member_use_from_same_package
      expect(Country.usa, CountryId.usa);
      // ignore: deprecated_member_use_from_same_package
      expect(Region.california, RegionId.california);
      // ignore: deprecated_member_use_from_same_package
      expect(DocumentType.dl, DocumentTypeId.dl);
    });
  });

  group('DocumentClassInfo nested classification (v8001)', () {
    test('parses the {id, rawValue} shape, with id null for an unrecognized OTA-only class', () {
      final info = DocumentClassInfo({
        'country': {'id': 'croatia', 'rawValue': 'croatia'},
        'region': null,
        'documentType': {'id': null, 'rawValue': 'someNewOtaDocumentType'},
        'empty': false,
      });

      expect(info.country?.id, CountryId.croatia);
      expect(info.country?.rawValue, 'croatia');
      expect(info.region, isNull);
      expect(info.documentType?.id, isNull);
      expect(info.documentType?.rawValue, 'someNewOtaDocumentType');
      expect(info.empty, isFalse);
    });
  });
}
