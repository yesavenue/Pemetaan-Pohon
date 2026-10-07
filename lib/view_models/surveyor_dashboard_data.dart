import '../models/tree_data.dart';

/// Data tampilan di memori saja; tidak diserialisasi atau ditulis ke Firebase.
class SurveyorDashboardData {
  final List<TreeData> trees;

  SurveyorDashboardData._(this.trees);

  factory SurveyorDashboardData.fromTrees(
    Iterable<TreeData> source,
    String surveyorId,
  ) {
    final ownTrees =
        source.where((tree) => tree.surveyorId == surveyorId).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return SurveyorDashboardData._(List.unmodifiable(ownTrees));
  }

  int get atRiskCount => trees
      .where((tree) => tree.condition == TreeCondition.rawanTumbang)
      .length;

  int mappedToday(DateTime now) {
    final today = now.toLocal();
    return trees.where((tree) {
      final date = tree.timestamp.toLocal();
      return date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
    }).length;
  }
}