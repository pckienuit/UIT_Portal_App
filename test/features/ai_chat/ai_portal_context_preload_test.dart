import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uit_portal_app/src/features/ai_chat/application/ai_portal_context_builder.dart';
import 'package:uit_portal_app/src/features/ai_chat/domain/ai_chat_backend.dart';
import 'package:uit_portal_app/src/features/training_point/training_point_model.dart';
import 'package:uit_portal_app/src/features/training_point/training_point_providers.dart';

void main() {
  test(
    'preload snapshots autoDispose provider result before cache disposal',
    () async {
      final container = ProviderContainer(
        overrides: [
          trainingPointFutureProvider.overrideWith(
            (ref) async => TrainingPointResponse(
              averageTrainingPoint: 85,
              averageRank: 'Tốt',
              trainingPointHistory: [
                TrainingPointHistory(
                  semesterLabel: 'Học kỳ 1 2025-2026',
                  point: 90,
                  rank: 'Xuất sắc',
                ),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final snapshot = await const AiPortalContextBuilder().preload(container, {
        AiPortalContextSection.trainingPoint,
      });

      expect(snapshot.sharedSections, {AiPortalContextSection.trainingPoint});
      expect(
        snapshot.sectionSummaries[AiPortalContextSection.trainingPoint],
        contains('85'),
      );
      expect(snapshot.buildSystemInstruction(), contains('[ĐIỂM RÈN LUYỆN]'));
    },
  );
}
