import 'package:blinkid_flutter/blinkid_flutter.dart';

class UiDocumentFilter {
  Country? country;
  Region? region;
  DocumentType? documentType;

  UiDocumentFilter({this.country, this.region, this.documentType});
}

const sampleCountries = <Country>[
  Country.canada,
  Country.usa,
  Country.croatia,
  Country.germany,
  Country.uK,
  Country.australia,
];

const sampleUsaRegions = <Region>[
  Region.california,
  Region.texas,
  Region.newYork,
  Region.florida,
];

const sampleDocumentTypes = <DocumentType>[
  DocumentType.id,
  DocumentType.dl,
  DocumentType.passport,
  DocumentType.visa,
];

const redactionModes = <RedactionMode>[
  RedactionMode.none,
  RedactionMode.imageOnly,
  RedactionMode.resultFieldsOnly,
  RedactionMode.fullResult,
];

const sampleRedactionFields = <FieldType>[
  FieldType.firstName,
  FieldType.lastName,
  FieldType.fullName,
  FieldType.documentNumber,
  FieldType.dateOfBirth,
  FieldType.address,
  FieldType.personalIdNumber,
];

DocumentFilter uiToDocumentFilter(UiDocumentFilter ui) {
  return DocumentFilter(
    country: ui.country,
    region: ui.region,
    documentType: ui.documentType,
  );
}

bool hasDocumentFilterCriteria(UiDocumentFilter ui) {
  return ui.country != null || ui.region != null || ui.documentType != null;
}

UiDocumentFilter emptyUiDocumentFilter() => UiDocumentFilter();
