import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/insulin_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _lowLimitController;
  late TextEditingController _highLimitController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<InsulinProvider>();
    _lowLimitController = TextEditingController(text: provider.lowLimit.toString());
    _highLimitController = TextEditingController(text: provider.highLimit.toString());
  }

  @override
  void dispose() {
    _lowLimitController.dispose();
    _highLimitController.dispose();
    super.dispose();
  }

  Future<void> _saveLimits() async {
    final provider = context.read<InsulinProvider>();
    
    final lowValue = int.tryParse(_lowLimitController.text);
    final highValue = int.tryParse(_highLimitController.text);

    if (lowValue == null || highValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa valores numéricos válidos'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (lowValue >= highValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El límite bajo debe ser menor que el límite alto'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    await provider.setLowLimit(lowValue);
    await provider.setHighLimit(highValue);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Límites actualizados correctamente'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ajustes',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 32,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Personaliza los límites de glucosa',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Límites de Glucosa',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildLimitField(
                      label: 'Límite Bajo (mg/dL)',
                      controller: _lowLimitController,
                      hint: 'Ej: 70',
                    ),
                    const SizedBox(height: 16),
                    _buildLimitField(
                      label: 'Límite Alto (mg/dL)',
                      controller: _highLimitController,
                      hint: 'Ej: 180',
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveLimits,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Guardar Cambios',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryDim,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Estos límites se usan para calcular el TIR (Time In Range) y las alertas visuales en la gráfica.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLimitField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textFaint),
            filled: true,
            fillColor: AppColors.surface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}
