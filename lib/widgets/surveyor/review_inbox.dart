import 'package:flutter/material.dart';
import '../../models/tree_data.dart';

/// Uses the dashboard's owner-scoped snapshot, without another subscription.
class ReviewInbox extends StatelessWidget {
  final List<TreeData> trees;
  final ValueChanged<TreeData> onOpen;
  const ReviewInbox({super.key, required this.trees, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final rows = trees.where((t) => t.status == TreeStatus.rejected).toList()
      ..sort(
        (a, b) => (b.reviewedAt ?? b.timestamp).compareTo(
          a.reviewedAt ?? a.timestamp,
        ),
      );
    final unread = rows.where((t) => t.hasUnreadReview).length;
    return IconButton(
      tooltip: 'Pesan admin ($unread belum dibaca)',
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () async {
        final chosen = await showModalBottomSheet<TreeData>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .65,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Pesan perbaikan dari admin',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: rows.isEmpty
                        ? const Center(
                            child: Text('Belum ada permintaan perbaikan.'),
                          )
                        : ListView.separated(
                            itemCount: rows.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final row = rows[index];
                              return ListTile(
                                leading: Icon(
                                  row.hasUnreadReview
                                      ? Icons.mark_email_unread_outlined
                                      : Icons.drafts_outlined,
                                ),
                                title: Text(row.species),
                                subtitle: Text(
                                  row.rejectionReason,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.pop(context, row),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
        if (chosen != null && context.mounted) {
          onOpen(chosen);
        }
      },
    );
  }
}