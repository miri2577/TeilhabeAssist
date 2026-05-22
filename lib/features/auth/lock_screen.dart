import 'package:flutter/material.dart';
import 'auth_service.dart';

/// Lock-Screen: Passwort-Eingabe bei jedem App-Start.
/// Beim Erststart wird stattdessen ein neues Passwort vergeben.
class LockScreen extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onAuthenticated;

  const LockScreen({
    super.key,
    required this.authService,
    required this.onAuthenticated,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  String? _error;
  bool _isSetup = false;

  @override
  void initState() {
    super.initState();
    _isSetup = !widget.authService.hasPassword;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _login() {
    final password = _passwordController.text;
    if (widget.authService.isLockedOut) {
      setState(() => _error =
          'Zu viele Fehlversuche. Gesperrt für ${widget.authService.lockoutSeconds} Sekunden.');
      return;
    }
    if (widget.authService.validatePassword(password)) {
      widget.onAuthenticated();
    } else {
      if (widget.authService.isLockedOut) {
        setState(() => _error =
            'Zu viele Fehlversuche. Gesperrt für ${widget.authService.lockoutSeconds} Sekunden.');
      } else {
        setState(() => _error = 'Falsches Passwort');
      }
    }
  }

  Future<void> _setup() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 8) {
      setState(() => _error = 'Mindestens 8 Zeichen erforderlich');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwörter stimmen nicht überein');
      return;
    }

    await widget.authService.setPassword(password);
    widget.onAuthenticated();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'FEGH-Bericht',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _isSetup
                      ? 'Bitte vergib ein persönliches Passwort\nzum Schutz der Sozialdaten.'
                      : 'Bitte Passwort eingeben',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                // Passwort
                TextField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: _isSetup ? 'Neues Passwort' : 'Passwort',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) {
                    if (!_isSetup) _login();
                  },
                ),

                // Passwort-Stärke (nur bei Setup)
                if (_isSetup && _passwordController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildStrengthIndicator(),
                ],

                // Bestätigung (nur bei Setup)
                if (_isSetup) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmController,
                    obscureText: _obscure,
                    decoration: const InputDecoration(
                      labelText: 'Passwort bestätigen',
                      prefixIcon: Icon(Icons.lock_clock),
                    ),
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) => _setup(),
                  ),
                ],

                // Fehler
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: TextStyle(color: Colors.red.shade700)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSetup ? _setup : _login,
                    icon: Icon(_isSetup ? Icons.security : Icons.login),
                    label: Text(_isSetup ? 'Passwort vergeben' : 'Entsperren'),
                  ),
                ),

                if (_isSetup) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Das Passwort schützt alle lokal gespeicherten '
                            'Sozialdaten. Es kann nicht wiederhergestellt werden.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStrengthIndicator() {
    final strength = AuthService.checkStrength(_passwordController.text);
    final color = switch (strength) {
      PasswordStrength.tooShort => Colors.red,
      PasswordStrength.weak => Colors.orange,
      PasswordStrength.medium => Colors.amber,
      PasswordStrength.strong => Colors.green,
    };

    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: switch (strength) {
              PasswordStrength.tooShort => 0.15,
              PasswordStrength.weak => 0.4,
              PasswordStrength.medium => 0.7,
              PasswordStrength.strong => 1.0,
            },
            color: color,
            backgroundColor: color.withValues(alpha: 0.2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          strength.label,
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }
}
