import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/insulin_provider.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  bool _obscure       = true;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.2)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final provider = context.read<InsulinProvider>();
    final ok = await provider.login(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InsulinProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Logo animado
                Center(
                  child: ScaleTransition(
                    scale: _pulseAnim,
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.cyan],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 30, spreadRadius: 5,
                          )
                        ],
                      ),
                      child: const Icon(Icons.water_drop_rounded,
                        color: Colors.white, size: 36),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                const Text('Bienvenido',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                const Text('Inicia sesión con tu cuenta LibreView',
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted)),

                const SizedBox(height: 40),

                // Error banner
                if (provider.errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline,
                        color: AppColors.danger, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(provider.errorMessage!,
                          style: const TextStyle(
                            fontSize: 13, color: AppColors.danger)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                ],

                // Email
                _buildLabel('Correo electrónico'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _inputDecoration(
                    hint: 'usuario@ejemplo.com',
                    icon: Icons.email_outlined,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'El correo es obligatorio';
                    if (!v.contains('@')) return 'Formato de correo inválido';
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Contraseña
                _buildLabel('Contraseña'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _inputDecoration(
                    hint: '••••••••',
                    icon: Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textMuted, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'La contraseña es obligatoria';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),

                const SizedBox(height: 8),

                // Nota de privacidad
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Tus credenciales se usan únicamente para conectarse '
                    'directamente con LibreView. No se almacenan en servidores externos.',
                    style: TextStyle(fontSize: 11, color: AppColors.textFaint),
                  ),
                ),

                const SizedBox(height: 36),

                // Botón login
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: provider.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: provider.isLoading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                      : const Text('Conectar a LibreView',
                          style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 24),

                // Link a LibreView
                Center(
                  child: GestureDetector(
                    onTap: () {/* abre navegador */},
                    child: const Text.rich(TextSpan(
                      text: '¿No tienes cuenta? ',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                      children: [
                        TextSpan(text: 'Regístrate en LibreView',
                          style: TextStyle(color: AppColors.primary,
                            fontWeight: FontWeight.w500)),
                      ],
                    )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
      color: AppColors.textMuted));

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textFaint),
    prefixIcon: Icon(icon, color: AppColors.textFaint, size: 20),
    suffixIcon: suffix,
    filled: true,
    fillColor: AppColors.surface2,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
    ),
  );
}