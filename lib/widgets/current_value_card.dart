import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/insulin_provider.dart';
import '../models/insulin_reading.dart';
import '../theme/app_theme.dart';

class CurrentValueCard extends StatelessWidget {
  const CurrentValueCard({super.key});

  @override
  Widget build(BuildContext context) {
    final p   = context.watch<InsulinProvider>();
    final val = p.currentValue;
    final status = InsulinReading(timestamp: DateTime.now(), value: val).status;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x2E7C6AF7), Color(0x1422D3EE)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x407C6AF7)),
      ),
      padding: const EdgeInsets.all(20),
      child: Stack(children: [
        // Glow decorativo
        Positioned(
          top: -30, right: -30,
          child: Container(
            width: 130, height: 130,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x337C6AF7), Colors.transparent],
              ),
            ),
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('NIVEL DE INSULINA',
                  style: TextStyle(fontSize: 11, letterSpacing: 1.2,
                    color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Colors.white, AppColors.primary],
                  ).createShader(b),
                  child: Text(val.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 52,
                      fontWeight: FontWeight.w700, color: Colors.white, height: 1.0)),
                ),
                const SizedBox(height: 4),
                const Text('pmol/L · Actualizado ahora',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                _StatusBadge(status: status),
                if (p.yesterdayComparison != null) ...[
                  const SizedBox(height: 10),
                  Text(p.yesterdayComparison!,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ]),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0x10FFFFFF), height: 1),
          const SizedBox(height: 16),
          Row(children: [
            _StatItem(label: 'Mínimo hoy',  value: p.minToday.toStringAsFixed(0)),
            _StatItem(label: 'Máximo hoy',  value: p.maxToday.toStringAsFixed(0), color: AppColors.warning),
            _StatItem(label: 'Promedio',    value: p.averageToday.toStringAsFixed(0)),
            _StatItem(label: 'Dosis hoy',   value: p.dosesToday.toString(), color: AppColors.success),
          ]),
        ]),
      ]),
    );
  }
}

class _StatusBadge extends StatefulWidget {
  final InsulinStatus status;
  const _StatusBadge({required this.status});
  @override State<_StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<_StatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (widget.status) {
      InsulinStatus.normal => ('Normal', const Color(0x2634D399), AppColors.success),
      InsulinStatus.high   => ('Alto',   const Color(0x26F59E0B), AppColors.warning),
      InsulinStatus.low    => ('Bajo',   const Color(0x26F59E0B), AppColors.warning),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        FadeTransition(
          opacity: _anim,
          child: Container(width: 6, height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _StatItem({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textFaint)),
    ]),
  );
}