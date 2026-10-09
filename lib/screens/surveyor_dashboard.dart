import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../view_models/surveyor_dashboard_data.dart';
import '../models/tree_data.dart';
import '../services/tree_service.dart';
import 'surveyor/dashboard_home.dart';
import 'surveyor/tree_browser.dart';
import 'surveyor/tree_detail_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/surveyor/survey_loading.dart';
import 'surveyor_profile_screen.dart';
import 'tree_input_screen.dart';

class SurveyorDashboard extends StatefulWidget {
  final AppUser surveyorUser;

  const SurveyorDashboard({super.key, required this.surveyorUser});

  @override
  State<SurveyorDashboard> createState() => _SurveyorDashboardState();
}

class _SurveyorDashboardState extends State<SurveyorDashboard> {
  final _authService = AuthService();
  late Stream<SurveyorDashboardData> _trees;
  late AppUser _surveyorUser;
  int _selectedTab = 0;
  bool _showList = false;
  final _listMemory = TreeBrowserMemory();
  final _mapMemory = TreeBrowserMemory();
  String? _mySessionId;
  StreamSubscription<String?>? _sessionSub;

  @override
  void initState() {
    super.initState();
    _surveyorUser = widget.surveyorUser;
    _trees = _createTreeStream();
    _registerSession();
  }

  Stream<SurveyorDashboardData> _createTreeStream() =>
      TreeService().streamTrees().map(
        (trees) => SurveyorDashboardData.fromTrees(trees, _surveyorUser.uid),
      );

  // Setiap kali dashboard ini dibuka (login baru ATAU sekadar refresh
  // halaman), device/tab ini "mengklaim" jadi sesi aktif. Kalau nanti
  // ada device/tab lain yang login dan mengklaim ulang, listener di
  // bawah akan mendeteksi perubahan dan logout otomatis di sini.
  Future<void> _registerSession() async {
    try {
      final sessionId = await _authService.registerDeviceSession(
        _surveyorUser.uid,
      );
      if (!mounted) {
        return;
      }
      _mySessionId = sessionId;
      _sessionSub = _authService.watchActiveSessionId(_surveyorUser.uid).listen(
        (remoteId) {
          if (_mySessionId != null &&
              remoteId != null &&
              remoteId != _mySessionId) {
            unawaited(_handleKickedOut());
          }
        },
        onError: (Object error) => _showSessionError(),
      );
    } catch (_) {
      _showSessionError();
    }
  }

  void _showSessionError() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sesi perangkat belum terkonfirmasi. Periksa koneksi, lalu masuk kembali.',
        ),
      ),
    );
  }

  Future<void> _handleKickedOut() async {
    _sessionSub?.cancel();
    if (!mounted) {
      return;
    }
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sesi Berakhir'),
        content: const Text(
          'Akun ini baru saja login di perangkat/tab lain. Anda akan keluar dari sesi ini.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
    if (!mounted) {
      return;
    }
    final navigator = Navigator.of(context);
    await _authService.logout();
    if (navigator.mounted) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    super.dispose();
  }

  void _openTree(TreeData tree) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TreeDetailScreen(tree: tree, surveyorUser: _surveyorUser),
      ),
    );
  }

  void _openInput() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TreeInputScreen(surveyorUser: _surveyorUser),
      ),
    );
  }

  void _openList() {
    setState(() {
      _selectedTab = 0;
      _showList = true;
    });
  }

  void _returnHome() {
    setState(() {
      _selectedTab = 0;
      _showList = false;
    });
  }

  String get _pageTitle {
    if (_showList) {
      return 'Data Pohon';
    }
    if (_selectedTab == 2) {
      return 'Peta Pohon';
    }
    if (_selectedTab == 3) {
      return 'Profil';
    }
    return 'Ruang Kerja Surveyor';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_showList && _selectedTab == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _returnHome();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F6F5),
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: MediaQuery.sizeOf(context).width < 600 ? 52 : 64,
          automaticallyImplyLeading: false,
          leading: _showList
              ? IconButton(
                  tooltip: 'Kembali ke Beranda',
                  onPressed: _returnHome,
                  icon: const Icon(Icons.arrow_back),
                )
              : null,
          title: Text(
            _pageTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        body: _selectedTab == 3
            ? SurveyorProfileScreen(
                surveyorUser: _surveyorUser,
                embedded: true,
                onUserUpdated: (user) => setState(() => _surveyorUser = user),
              )
            : StreamBuilder<SurveyorDashboardData>(
                stream: _trees,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Gagal memuat data. Periksa koneksi dan izin akun.',
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: () => setState(
                                  () => _trees = _createTreeStream(),
                                ),
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const SurveyLoading();
                  }
                  final data = snapshot.data!;
                  if (_showList) {
                    return TreeBrowser(
                      key: const ValueKey('list'),
                      memory: _listMemory,
                      trees: data.trees,
                      onOpenTree: _openTree,
                      onAddTree: _openInput,
                    );
                  }
                  if (_selectedTab == 2) {
                    return TreeBrowser(
                      key: const ValueKey('map'),
                      memory: _mapMemory,
                      trees: data.trees,
                      mapMode: true,
                      onOpenTree: _openTree,
                      onAddTree: _openInput,
                    );
                  }
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: DashboardHome(
                        user: _surveyorUser,
                        data: data,
                        onOpenTrees: _openList,
                        onOpenTree: _openTree,
                      ),
                    ),
                  );
                },
              ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedTab,
          backgroundColor: Colors.white,
          indicatorColor: AppColors.leaf.withValues(alpha: .12),
          onDestinationSelected: (index) {
            if (index == 1) {
              _openInput();
              return;
            }
            setState(() {
              _selectedTab = index;
              _showList = false;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppColors.leaf),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_location_alt_outlined),
              label: 'Input',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map, color: AppColors.leaf),
              label: 'Peta',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppColors.leaf),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
