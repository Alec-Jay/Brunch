import 'package:flutter/material.dart';
import '../services/notes_storage_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/home_tile.dart';
import 'calendar_screen.dart';
import 'folder_screen.dart';
import 'meetings_screen.dart';
import 'notes_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  int _meetingCount = 0;
  int _noteCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCounts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadCounts();
  }

  Future<void> _loadCounts() async {
    final results = await Future.wait([
      StorageService.instance.loadMeetings(),
      NotesStorageService.instance.loadNotes(),
    ]);
    if (mounted) {
      setState(() {
        _meetingCount = (results[0] as List).length;
        _noteCount = (results[1] as List).length;
      });
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _formattedDate {
    final now = DateTime.now();
    const days = [
      'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'
    ];
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  Future<void> _navigate(Widget screen) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => screen));
    _loadCounts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
            colors: [
              Color(0xFF090D1A),
              Color(0xFF0C1220),
              Color(0xFF060A10),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              _buildGreeting(),
              Expanded(child: _buildTileGrid()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 16, 0),
      child: Row(
        children: [
          // Logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.accent, Color(0xFF00D4FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.brunch_dining_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          const Text(
            'Brunch',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings_rounded,
                color: AppTheme.textSecondary, size: 22),
            onPressed: () => _navigate(const SettingsScreen()),
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _greeting,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formattedDate,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: const BoxDecoration(
                    color: AppTheme.success, shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
                Text(
                  '$_meetingCount meetings · $_noteCount notes',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTileGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.88,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          HomeTile(
            title: 'Meetings',
            subtitle: _meetingCount == 0
                ? 'Record a meeting'
                : '$_meetingCount recorded',
            icon: Icons.mic_rounded,
            gradient: const [Color(0xFF7C6FFF), Color(0xFF4A3FA0)],
            badge: _meetingCount > 0 ? '$_meetingCount' : null,
            onTap: () => _navigate(const MeetingsScreen()),
          ),
          HomeTile(
            title: 'Notes',
            subtitle: _noteCount == 0
                ? 'Text & voice notes'
                : '$_noteCount notes',
            icon: Icons.note_alt_rounded,
            gradient: const [Color(0xFF00C9A7), Color(0xFF007A68)],
            badge: _noteCount > 0 ? '$_noteCount' : null,
            onTap: () => _navigate(const NotesScreen()),
          ),
          HomeTile(
            title: 'Calendar',
            subtitle: 'Schedule & events',
            icon: Icons.calendar_month_rounded,
            gradient: const [Color(0xFFFF6B6B), Color(0xFFCC3C3C)],
            onTap: () => _navigate(const CalendarScreen()),
          ),
          HomeTile(
            title: 'Folder',
            subtitle: 'All your files',
            icon: Icons.folder_rounded,
            gradient: const [Color(0xFF4776E6), Color(0xFF2952B3)],
            onTap: () => _navigate(const FolderScreen()),
          ),
        ],
      ),
    );
  }
}
