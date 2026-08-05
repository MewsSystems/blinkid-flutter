import 'package:blinkid_flutter/blinkid_flutter.dart';

class UiDocumentFilter {
  CountryId? country;
  RegionId? region;
  DocumentTypeId? documentType;

  UiDocumentFilter({this.country, this.region, this.documentType});
}

const sampleCountries = <CountryId>[
  CountryId.canada,
  CountryId.usa,
  CountryId.croatia,
  CountryId.germany,
  CountryId.uk,
  CountryId.australia,
];

const sampleUsaRegions = <RegionId>[
  RegionId.california,
  RegionId.texas,
  RegionId.newYork,
  RegionId.florida,
];

const sampleDocumentTypes = <DocumentTypeId>[
  DocumentTypeId.id,
  DocumentTypeId.dl,
  DocumentTypeId.passport,
  DocumentTypeId.visa,
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
    region: ui.country == CountryId.usa ? ui.region : null,
    documentType: ui.documentType,
  );
}

bool hasDocumentFilterCriteria(UiDocumentFilter ui) {
  return ui.country != null || ui.region != null || ui.documentType != null;
}

UiDocumentFilter emptyUiDocumentFilter() => UiDocumentFilter();
