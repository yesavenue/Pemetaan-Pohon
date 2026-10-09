import '../models/app_user.dart';
import '../models/tree_data.dart';
import '../models/tree_pruning_request.dart';

/// Agregasi presentasi dari dataset admin existing, bukan skema database baru.
class AdminSummary {
  final List<TreeData> trees;
  final List<AppUser> surveyors;
  final List<TreePruningRequest> requests;
  AdminSummary({
    required List<TreeData> trees,
    required List<AppUser> surveyors,
    required List<TreePruningRequest> requests,
  }) : trees = List.unmodifiable(trees),
       surveyors = List.unmodifiable(surveyors),
       requests = List.unmodifiable(requests);

  int get activeSurveyors =>
      surveyors.where((u) => u.role == UserRole.surveyor && u.isActive).length;
  List<TreeData> get pendingTrees =>
      trees.where((t) => t.status == TreeStatus.pending).toList()..sort((a, b) {
        final date = a.timestamp.compareTo(b.timestamp);
        return date != 0 ? date : a.id.compareTo(b.id);
      });
  List<TreePruningRequest> get waitingRequests =>
      requests.where((r) => r.status == PruningStatus.menunggu).toList()
        ..sort((a, b) {
          final date = a.createdAt.compareTo(b.createdAt);
          return date != 0 ? date : a.id.compareTo(b.id);
        });
  List<TreeData> get verifiedTrees =>
      trees.where((t) => t.status == TreeStatus.verified).toList();
  List<TreeData> get mapTrees => verifiedTrees
      .where(
        (t) =>
            t.latitude.isFinite &&
            t.longitude.isFinite &&
            t.latitude.abs() <= 90 &&
            t.longitude.abs() <= 180,
      )
      .toList();
  int conditionCount(TreeCondition condition) =>
      trees.where((t) => t.condition == condition).length;
  List<MapEntry<String, int>> get speciesCounts {
    final counts = <String, int>{};
    for (final tree in trees) {
      final name = tree.species.trim().isEmpty
          ? 'Tidak diketahui'
          : tree.species.trim();
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return counts.entries.toList()..sort((a, b) {
      final count = b.value.compareTo(a.value);
      return count != 0 ? count : a.key.compareTo(b.key);
    });
  }
}