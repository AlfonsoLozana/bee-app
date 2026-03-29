import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/insulin_provider.dart';
import '../models/insulin_reading.dart';
import '../theme/app_theme.dart';

class DoseHistoryList extends StatelessWidget {
  const DoseHistoryList({super.key});

  @override
  Widget build(BuildContext context) {
    final doses = context.watch<InsulinProvider>().doses;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Historial de Dosis',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
          TextButton(
            onPressed: () {},
            child: const Text('Ver todo →',
              style: TextStyle(fontSize: 12, color: AppColors.primary)),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ...doses.map((d) => _DoseItem(dose: d)),
    ]);
  }
}

class _DoseItem extends StatelessWidget {
  final DoseRecord dose;
  const _DoseItem({required this.dose});

  @override
  Widget build(BuildContext context) {
    final (emoji, bg, color, name) = switch (dose.type) {
      DoseType.rapid      => ('💉', const Color(0x1F7C6AF7), AppColors.primary, 'Insulina Rápida'),
      DoseType.basal      => ('🔵', const Color(0x1F22D3EE), AppColors.cyan,    'Insulina Basal'),
      DoseType.correction => ('🩹', const Color(0x1F34D399), AppColors.success, 'Corrección'),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 14,
            fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(
            '${DateFormat('HH:mm').format(dose.timestamp)}'
            '${dose.note != null ? ' · ${dose.note}' : ''}'
            ' · ${dose.insulinName}',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ])),
        Text('${dose.units.toStringAsFixed(0)} UI',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}