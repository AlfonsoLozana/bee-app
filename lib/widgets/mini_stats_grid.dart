import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/insulin_provider.dart';
import '../theme/app_theme.dart';

class MiniStatsGrid extends StatelessWidget {
  const MiniStatsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<InsulinProvider>();
    return Column(
      children: [
        // Primera fila: 4 métricas principales (2x2)
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
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
        ),
        const SizedBox(height: 12),
        // Segunda fila: Métricas ampliadas (3 cards)
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.0,
          children: [
            _MiniCard(
              icon: Icons.arrow_upward,
              label: '% Alto',
              value: '${p.aboveRange.toStringAsFixed(0)}%',
              sub: 'Fuera arriba',
              progress: p.aboveRange / 100,
              color: const Color(0xFFF59E0B),
              gradColors: [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
            ),
            _MiniCard(
              icon: Icons.arrow_downward,
              label: '% Bajo',
              value: '${p.belowRange.toStringAsFixed(0)}%',
              sub: 'Fuera abajo',
              progress: p.belowRange / 100,
              color: const Color(0xFFEF4444),
              gradColors: [const Color(0xFFEF4444), const Color(0xFFF87171)],
            ),
            _MiniCard(
              icon: Icons.warning_amber,
              label: '% >240',
              value: '${p.criticalHigh.toStringAsFixed(0)}%',
              sub: 'Crítico alto',
              progress: p.criticalHigh / 100,
              color: const Color(0xFFDC2626),
              gradColors: [const Color(0xFFDC2626), const Color(0xFFEF4444)],
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Tercera fila: Eventos críticos (tarjeta especial)
        _EventsCard(hypoCount: p.hypoCount, hyperCount: p.hyperCount),
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
  const _MiniCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.progress,
    required this.color,
    required this.gradColors,
  });
  @override
  State<_MiniCard> createState() => _MiniCardState();
}

class _MiniCardState extends State<_MiniCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(widget.icon, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          widget.value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: widget.color,
          ),
        ),
        Text(
          widget.sub,
          style: const TextStyle(fontSize: 10, color: AppColors.textFaint),
        ),
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
      ],
    ),
  );
}

// Tarjeta especial para eventos críticos
class _EventsCard extends StatelessWidget {
  final int hypoCount;
  final int hyperCount;

  const _EventsCard({required this.hypoCount, required this.hyperCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0x1AEF4444), const Color(0x0AEF4444)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x30EF4444), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.health_and_safety,
                size: 16,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(width: 8),
              const Text(
                'EVENTOS CRÍTICOS (24h)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _EventBadge(
                  icon: Icons.arrow_downward,
                  label: 'Hipoglucemias',
                  count: hypoCount,
                  color: const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _EventBadge(
                  icon: Icons.arrow_upward,
                  label: 'Hiperglucemias',
                  count: hyperCount,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Eventos de ≥15 min fuera de umbral',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textFaint.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _EventBadge({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
