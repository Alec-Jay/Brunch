import 'package:flutter/material.dart';
import '../models/meeting.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/meeting_card.dart';
import 'meeting_detail_screen.dart';
import 'new_meeting_screen.dart';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<Meeting> _meetings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final m = await StorageService.instance.loadMeetings();
    if (mounted) setState(() { _meetings = m; _isLoading = false; });
  }

  List<Meeting> get _filtered {
    if (_searchQuery.isEmpty) return _meetings;
    final q = _searchQuery.toLowerCase();
    return _meetings.where((m) =>
        m.title.toLowerCase().contains(q) ||
        m.summary.toLowerCase().contains(q)).toList();
  }

  Future<void> _openNew() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const NewMeetingScreen()));
    _load();
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
            colors: [Color(0xFF0A0D18), Color(0xFF0D1525), Color(0xFF080C14)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearch(),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
                Text('Meetings',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                Text('Record & review meetings',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppTheme.textSecondary, size: 20),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: const InputDecoration(
            hintText: 'Search meetings...',
            hintStyle:
                TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded,
                color: AppTheme.textSecondary, size: 20),
            border: InputBorder.none,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(
              color: AppTheme.accent, strokeWidth: 2));
    }
    final meetings = _filtered;
    if (meetings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
                border:
                    Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.mic_none_rounded,
                  color: AppTheme.accent, size: 34),
            ),
            const SizedBox(height: 16),
            const Text('No meetings yet',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Tap "New Meeting" to start recording',
                style:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.accent,
      backgroundColor: AppTheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        itemCount: meetings.length,
        itemBuilder: (ctx, i) => MeetingCard(
          meeting: meetings[i],
          onTap: () async {
            await Navigator.push(
                ctx,
                MaterialPageRoute(
                    builder: (_) =>
                        MeetingDetailScreen(meeting: meetings[i])));
            _load();
          },
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppTheme.accent, Color(0xFF9C63FF)]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 8))
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _openNew,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('New Meeting',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
