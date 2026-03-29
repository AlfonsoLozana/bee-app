import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/insulin_provider.dart';
import '../theme/app_theme.dart';

class MiniStatsGrid extends StatelessWidget {
  const MiniStatsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<InsulinProvider>();
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12, mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _MiniCard(
          icon: Icons.show_chart,
          label: 'TIR (Tiempo en rango)',
          value: '${p.tir.toStringAsFixed(0)}%',
          sub: 'Objetivo: >70% ✓',
          progress: p.tir / 100,
          color: AppColors.success,
          gradColors: [AppColors.success, AppColors.cyan],
        ),
        _MiniCard(
          icon: Icons.bar_chart,
          label: 'Variabilidad (CV)',
          value: '${p.cv.toStringAsFixed(1)}%',
          sub: 'Objetivo: <36% ✓',
          progress: p.cv / 100,
          color: AppColors.warning,
          gradColors: [AppColors.warning, const Color(0xFFFDE68A)],
        ),
        _MiniCard(
          icon: Icons.schedule,
          label: 'Última dosis',
          value: p.lastDoseDisplay,
          sub: p.lastDoseTime,
          progress: p.lastDoseProgress,
          color: AppColors.primary,
          gradColors: [AppColors.primary, const Color(0xFFA78BFA)],
        ),
        _MiniCard(
          icon: Icons.shield_outlined,
          label: 'HbA1c Est.',
          value: '${p.hba1cEst.toStringAsFixed(2)}%',
          sub: p.hba1cEst < 7.0 ? 'Objetivo: <7% ✓' : 'Objetivo: <7%',
          progress: p.hba1cEst / 10,
          color: AppColors.success,
          gradColors: [AppColors.success, const Color(0xFF6EE7B7)],
        ),
      ],
    );
  }
}

class _MiniCard extends StatefulWidget {
  final IconData icon;
  final String label, value, sub;
  final double progress;
  final Color color;
  final List<Color> gradColors;
  const _MiniCard({required this.icon, required this.label,
    required this.value, required this.sub, required this.progress,
    required this.color, required this.gradColors});
  @override State<_MiniCard> createState() => _MiniCardState();
}

class _MiniCardState extends State<_MiniCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))..forward();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface2, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(widget.icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 5),
        Expanded(child: Text(widget.label,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          overflow: TextOverflow.ellipsis)),
      ]),
      const SizedBox(height: 6),
      Text(widget.value, style: TextStyle(fontSize: 22,
        fontWeight: FontWeight.w700, color: widget.color)),
      Text(widget.sub,
        style: const TextStyle(fontSize: 10, color: AppColors.textFaint)),
      const Spacer(),
      AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: widget.progress * _anim.value,
            minHeight: 4,
            backgroundColor: AppColors.surface3,
            valueColor: AlwaysStoppedAnimation(widget.color),
          ),
        ),
      ),
    ]),
  );
}