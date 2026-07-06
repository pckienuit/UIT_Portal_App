import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/portal_api_providers.dart';
import 'study_reservation_model.dart';

final studyReservationProvider = FutureProvider.autoDispose<StudyReservationResponse>((ref) async {
  final client = ref.watch(portalApiClientProvider);
  final response = await client.get('/api/sinh-vien/thoi-hoc-bao-luu');
  return StudyReservationResponse.fromJson(response.data);
});
