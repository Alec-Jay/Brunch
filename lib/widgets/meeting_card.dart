import 'package:flutter/material.dart';
import '../models/meeting.dart';
import '../theme/app_theme.dart';

class MeetingCard extends StatelessWidget {
  final Meeting meeting;
  final VoidCallback onTap;

  const MeetingCard({super.key, required this.meeting, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      meeting.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      meeting.formattedDuration,
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (meeting.summary.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  meeting.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 13, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    meeting.formattedDate,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const Spacer(),
                  if (meeting.actionItems.isNotEmpty) ...[
                    const Icon(Icons.check_circle_outline_rounded, size: 13, color: AppTheme.success),
                    const SizedBox(width: 4),
                    Text(
                      '${meeting.actionItems.length} action${meeting.actionItems.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
