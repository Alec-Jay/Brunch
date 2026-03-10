import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final DateTime _today = DateTime.now();
  late int _selectedDay;
  late int _currentMonth;
  late int _currentYear;

  final List<_CalEvent> _events = [
    _CalEvent('Team Stand-up', '09:00', const Color(0xFF7C6FFF)),
    _CalEvent('Product Review', '14:00', const Color(0xFF00C9A7)),
    _CalEvent('Client Call', '16:30', const Color(0xFFFF6B6B)),
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = _today.day;
    _currentMonth = _today.month;
    _currentYear = _today.year;
  }

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  int get _daysInMonth =>
      DateTime(_currentYear, _currentMonth + 1, 0).day;

  int get _firstWeekday =>
      DateTime(_currentYear, _currentMonth, 1).weekday;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF100A16), Color(0xFF120D1A), Color(0xFF080C14)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                  child: Column(
                    children: [
                      _buildCalendarCard(),
                      const SizedBox(height: 20),
                      _buildComingSoonBanner(),
                      const SizedBox(height: 20),
                      _buildEventList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Calendar',
                    style: TextStyle(color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.bold)),
                Text('Schedule & upcoming events',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          // Month navigation
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() {
                  if (_currentMonth == 1) { _currentMonth = 12; _currentYear--; }
                  else _currentMonth--;
                }),
                icon: const Icon(Icons.chevron_left_rounded,
                    color: Colors.white),
              ),
              Expanded(
                child: Text(
                  '${_monthNames[_currentMonth]} $_currentYear',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  if (_currentMonth == 12) { _currentMonth = 1; _currentYear++; }
                  else _currentMonth++;
                }),
                icon: const Icon(Icons.chevron_right_rounded,
                    color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Day labels
          Row(
            children: _dayNames.map((d) => Expanded(
              child: Center(
                child: Text(d,
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),
          // Days grid
          _buildDaysGrid(),
        ],
      ),
    );
  }

  Widget _buildDaysGrid() {
    final blanks = _firstWeekday - 1;
    final total = blanks + _daysInMonth;
    final rows = (total / 7).ceil();
    return Column(
      children: List.generate(rows, (row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: List.generate(7, (col) {
              final index = row * 7 + col;
              final day = index - blanks + 1;
              if (day < 1 || day > _daysInMonth) {
                return const Expanded(child: SizedBox(height: 38));
              }
              final isToday = day == _today.day &&
                  _currentMonth == _today.month &&
                  _currentYear == _today.year;
              final isSelected = day == _selectedDay;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDay = day),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppTheme.accent
                          : isToday
                              ? AppTheme.accent.withValues(alpha: 0.15)
                              : null,
                      border: isToday && !isSelected
                          ? Border.all(
                              color: AppTheme.accent.withValues(alpha: 0.5),
                              width: 1)
                          : null,
                    ),
                    child: Center(
                      child: Text('$day',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? AppTheme.accent
                                    : Colors.white70,
                            fontSize: 14,
                            fontWeight: isSelected || isToday
                                ? FontWeight.w600
                                : FontWeight.normal,
                          )),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildComingSoonBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFFFF6B6B).withValues(alpha: 0.15),
          const Color(0xFFFF8E53).withValues(alpha: 0.08),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFFF6B6B).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.rocket_launch_rounded,
                color: Color(0xFFFF6B6B), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Calendar Integration — Coming Soon',
                    style: TextStyle(color: Colors.white,
                        fontSize: 13, fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text('Sync meetings from Google Calendar & Outlook in Phase 6',
                    style: TextStyle(color: AppTheme.textSecondary,
                        fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Today\'s Schedule',
                style: TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${_events.length} events',
                  style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._events.map((e) => _buildEventCard(e)),
        const SizedBox(height: 16),
        _buildPlaceholderEventCard(),
      ],
    );
  }

  Widget _buildEventCard(_CalEvent event) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 4, height: 40,
              decoration: BoxDecoration(
                color: event.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(event.time,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: event.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Record',
                  style: TextStyle(color: Colors.white60,
                      fontSize: 11, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderEventCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppTheme.border.withValues(alpha: 0.5),
            style: BorderStyle.solid),
      ),
      child: const Row(
        children: [
          Icon(Icons.add_rounded, color: AppTheme.textSecondary, size: 20),
          SizedBox(width: 10),
          Text('Add event from your calendar',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _CalEvent {
  final String title;
  final String time;
  final Color color;
  const _CalEvent(this.title, this.time, this.color);
}
