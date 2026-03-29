import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/insulin_provider.dart';
import '../models/insulin_reading.dart';
import '../theme/app_theme.dart';

class RegisterDoseSheet extends StatefulWidget {
  const RegisterDoseSheet({super.key});

  @override
  State<RegisterDoseSheet> createState() => _RegisterDoseSheetState();
}

class _RegisterDoseSheetState extends State<RegisterDoseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _unitsController = TextEditingController();
  final _insulinNameController = TextEditingController();
  final _noteController = TextEditingController();
  
  DoseType _selectedType = DoseType.rapid;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _unitsController.dispose();
    _insulinNameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitDose() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSubmitting = true);

    try {
      final dose = DoseRecord(
        timestamp: DateTime.now(),
        type: _selectedType,
        units: double.parse(_unitsController.text),
        insulinName: _insulinNameController.text.trim(),
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      await context.read<InsulinProvider>().addDose(dose);
      
      if (!mounted) return;
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dosis registrada correctamente'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al registrar dosis: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Registrar Dosis',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Selector de tipo
              const Text(
                'Tipo de insulina',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<DoseType>(
                segments: const [
                  ButtonSegment(
                    value: DoseType.rapid,
                    label: Text('Rápida'),
                    icon: Icon(Icons.flash_on),
                  ),
                  ButtonSegment(
                    value: DoseType.basal,
                    label: Text('Basal'),
                    icon: Icon(Icons.schedule),
                  ),
                  ButtonSegment(
                    value: DoseType.correction,
                    label: Text('Corrección'),
                    icon: Icon(Icons.healing),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (Set<DoseType> newSelection) {
                  setState(() => _selectedType = newSelection.first);
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.primary;
                    }
                    return AppColors.surface3;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return AppColors.textMuted;
                  }),
                ),
              ),
              const SizedBox(height: 20),

              // Unidades
              const Text(
                'Unidades',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _unitsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  hintText: 'Ej: 8.5',
                  suffixText: 'UI',
                  filled: true,
                  fillColor: AppColors.surface3,
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
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa las unidades';
                  }
                  final units = double.tryParse(value);
                  if (units == null || units <= 0) {
                    return 'Las unidades deben ser mayor a 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Nombre de insulina
              const Text(
                'Nombre de insulina',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _insulinNameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Ej: Humalog, NovoRapid',
                  filled: true,
                  fillColor: AppColors.surface3,
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
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor ingresa el nombre de la insulina';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Nota (opcional)
              const Text(
                'Nota (opcional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Ej: Antes de desayuno',
                  filled: true,
                  fillColor: AppColors.surface3,
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
                ),
              ),
              const SizedBox(height: 32),

              // Botón guardar
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitDose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'Guardar Dosis',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
