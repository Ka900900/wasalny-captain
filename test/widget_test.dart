import 'package:flutter_test/flutter_test.dart';
import 'package:waslny_captain/core/services/document_upload_service.dart';

void main() {
  test('UploadDocType includes the backend docType strings for criminal and drug docs', () {
    expect(UploadDocType.values, contains(UploadDocType.criminalRecord));
    expect(UploadDocType.values, contains(UploadDocType.drugTest));
    expect(UploadDocType.criminalRecord.endpoint, 'criminal-record');
    expect(UploadDocType.drugTest.endpoint, 'drug-test');
    expect(UploadDocType.idFront.endpoint, isNot('criminal-record'));
    expect(UploadDocType.insurance.endpoint, isNot('drug-test'));
  });
}
