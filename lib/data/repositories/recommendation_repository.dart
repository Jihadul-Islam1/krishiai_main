import '../models/recommendation.dart';

class RecommendationRepository {
  RecommendationRepository();

  /// AI recommendations are produced from a live model. Until that ships,
  /// the list is empty so the dashboard surfaces an honest empty state.
  Future<List<Recommendation>> all() async => const <Recommendation>[];
}
