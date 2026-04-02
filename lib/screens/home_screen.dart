import 'package:flutter/material.dart';
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
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: _navIndex,
        children: [
          // Inicio (Dashboard)
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const CurrentValueCard(),
                    const SizedBox(height: 16),
                    const ChartRangeTabs(),
                    const SizedBox(height: 12),
                    const InsulinChart(),
                    const SizedBox(height: 16),
                    const MiniStatsGrid(),
                    const SizedBox(height: 8),
                    const DoseHistoryList(),
                  ]),
                ),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Ajustes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Perfil',
          ),
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
