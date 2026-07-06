import '../../data/portal_api_client.dart';
import 'tuition_model.dart';

class TuitionRepository {
  final PortalApiClient _apiClient;

  TuitionRepository(this._apiClient);

  Future<List<TuitionRecord>> getTuitionRecords() async {
    try {
      final body = {
        "tuition_field_list": [
          "id",
          "semester",
          "year_id",
          "tuition_amount",
          "tuition_credit_number",
          "must_be_paid",
          "paid",
          "remaining",
          "debt_in_advance",
          "payment_status",
          "late_payment_date",
          "paid_time",
          "note"
        ],
        "detail_field_list": [
          "id",
          "subject_id",
          "subject_code",
          "subject_name",
          "tuition_credit_number",
          "unit_price",
          "additional_tuition",
          "amount",
          "note"
        ]
      };

      final response = await _apiClient.post(
        '/api/sv/tuition',
        data: body,
      );

      final tuitionResponse = TuitionResponse.fromJson(response.data);
      return tuitionResponse.records;
    } catch (e) {
      rethrow;
    }
  }
}

