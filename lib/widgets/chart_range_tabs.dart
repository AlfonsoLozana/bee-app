import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/insulin_provider.dart';
import '../models/chart_range.dart';
import '../theme/app_theme.dart';

class ChartRangeTabs extends StatelessWidget {
  const ChartRangeTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<InsulinProvider>();
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: ChartRange.values.map((range) {
          final selected = p.selectedRange == range;
          return Expanded(
            child: GestureDetector(
              onTap: () => p.setRange(range),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selected
                    ? [const BoxShadow(color: Color(0x667C6AF7), blurRadius: 10)]
                    : null,
                ),
                alignment: Alignment.center,
                child: Text(range.label,
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textMuted,
                  )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}