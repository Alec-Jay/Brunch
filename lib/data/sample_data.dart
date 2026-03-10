import '../models/meeting.dart';

final List<Meeting> sampleMeetings = [
  Meeting(
    id: '1',
    title: 'Q1 Planning Session',
    date: DateTime.now().subtract(const Duration(hours: 2)),
    durationSeconds: 2820,
    summary:
        'Discussed Q1 targets across all teams. Agreed on a revised revenue goal of \$2.4M with a focus on enterprise accounts. Weekly check-ins confirmed for every Monday at 9am.',
    actionItems: [
      'Sarah to send full project brief by Friday',
      'Book team offsite lunch for end of March',
      'James to review and update budget spreadsheet',
      'All leads to confirm headcount by EOD Thursday',
    ],
    transcript:
        'Good morning everyone, glad we could all make it. Let\'s get started with the Q1 planning. First up, I want to review where we ended Q4 and set some clear targets. Revenue came in at \$1.9M which was slightly below target but we have strong pipeline going into Q1. I\'d like to propose we aim for \$2.4M this quarter with a big push on enterprise accounts...',
  ),
  Meeting(
    id: '2',
    title: 'Product Design Review',
    date: DateTime.now().subtract(const Duration(days: 1)),
    durationSeconds: 3660,
    summary:
        'Reviewed latest UI mockups for the mobile app. Onboarding flow approved unanimously. Checkout screen flagged for revision — needs to reduce friction and support Apple Pay. Next review scheduled for next Tuesday.',
    actionItems: [
      'Design team to revise checkout screen by Monday',
      'Share approved mockups with dev team today',
      'Add Apple Pay to checkout requirements doc',
    ],
    transcript:
        'Alright, let\'s take a look at what the design team has put together. I\'m pulling up the Figma link now. Starting with the onboarding flow — I think this is really clean. The three-step setup is intuitive and I like that we\'ve removed the mandatory account creation...',
  ),
  Meeting(
    id: '3',
    title: 'Weekly Standup',
    date: DateTime.now().subtract(const Duration(days: 3)),
    durationSeconds: 900,
    summary:
        'Backend API is 80% complete, on track for Wednesday delivery. Frontend team is blocked pending final design decisions on the dashboard. DevOps completed staging deployment.',
    actionItems: [
      'Design team to unblock frontend with dashboard specs',
      'Mike to update API documentation by Tuesday',
    ],
    transcript:
        'Starting with backend updates from Mike. Backend updates: the REST API is about 80% done, the authentication endpoints are complete, working on the data endpoints now. Should be done by Wednesday. Frontend from Lisa: we\'re blocked on the dashboard design, waiting for specs from design...',
  ),
  Meeting(
    id: '4',
    title: 'Investor Update Call',
    date: DateTime.now().subtract(const Duration(days: 7)),
    durationSeconds: 5400,
    summary:
        'Presented Q4 results and Q1 roadmap to Series A investors. Positive reception overall. Questions raised about customer acquisition cost and churn. Follow-up deck to be sent by end of week.',
    actionItems: [
      'Send follow-up deck with CAC breakdown by Friday',
      'Schedule one-on-one with lead investor for next week',
      'Prepare churn analysis for next board meeting',
    ],
    transcript:
        'Thank you all for joining today. I\'d like to walk you through our Q4 performance and what we\'re building towards in Q1. We finished Q4 with 340 active customers, up from 210 at the start of the quarter. MRR hit \$158K, which represents 62% growth quarter over quarter...',
  ),
];
