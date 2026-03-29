import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/insulin_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/current_value_card.dart';
import '../widgets/chart_range_tabs.dart';
import '../widgets/insulin_chart.dart';
import '../widgets/mini_stats_grid.dart';
import '../widgets/dose_history_list.dart';
import '../widgets/register_dose_sheet.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userName = context.watch<InsulinProvider>().userName;
    
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: _navIndex,
        children: [
          // Inicio (Dashboard)
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.surface,
                surfaceTintColor: Colors.transparent,
                toolbarHeight: 72,
                flexibleSpace: FlexibleSpaceBar(
                  background: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.cyan],
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Buenos días,',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            Text('$userName 👋', style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                          ],
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                sliver: SliverList(delegate: SliverChildListDelegate([
                  const CurrentValueCard(),
                  const SizedBox(height: 16),
                  const ChartRangeTabs(),
                  const SizedBox(height: 12),
                  const InsulinChart(),
                  const SizedBox(height: 16),
                  const MiniStatsGrid(),
                  const SizedBox(height: 8),
                  const DoseHistoryList(),
                ])),
              ),
            ],
          ),
          // Ajustes
          const SettingsScreen(),
          // Perfil
          const ProfileScreen(),
        ],
      ),
      floatingActionButton: _navIndex == 0
          ? FloatingActionButton(
              onPressed: () => _showRegisterSheet(context),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Ajustes'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: 'Perfil'),
        ],
      ),
    );
  }

  void _showRegisterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const RegisterDoseSheet(),
    );
  }
}