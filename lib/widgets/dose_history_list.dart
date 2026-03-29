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

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Eliminar Dosis',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          '¿Estás seguro que deseas eliminar esta dosis?',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context.read<InsulinProvider>().deleteDose(dose);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Dosis eliminada'),
                    backgroundColor: AppColors.success,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (emoji, bg, color, name) = switch (dose.type) {
      DoseType.rapid      => ('💉', const Color(0x1F7C6AF7), AppColors.primary, 'Insulina Rápida'),
      DoseType.basal      => ('🔵', const Color(0x1F22D3EE), AppColors.cyan,    'Insulina Basal'),
      DoseType.correction => ('🩹', const Color(0x1F34D399), AppColors.success, 'Corrección'),
    };
    
    return Dismissible(
      key: Key(dose.timestamp.toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        _confirmDelete(context);
        return false;  // No eliminar automáticamente, esperar confirmación
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 24,
        ),
      ),
      child: Container(
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
      ),
    );
  }
}