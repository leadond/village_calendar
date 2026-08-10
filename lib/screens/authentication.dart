import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_preview.dart';
import '../src/services/setup_services.dart';

class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({super.key});

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isCreatingAccount = false;
  String? _errorMessage;
  DateTime? _lastOtpRequestAt;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final supabase = SetupServices.maybeSupabaseClient;
    if (supabase == null) {
      setState(() {
        _errorMessage =
            'Supabase is not configured yet. Use App Preview to keep exploring.';
      });
      _showMessage(
        'Add Supabase credentials with --dart-define before signing in.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isCreatingAccount) {
        final response = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (!mounted) {
          return;
        }

        if (response.session == null) {
          // Email confirmation is disabled server-side (accounts are
          // auto-confirmed), so sign in immediately after signup.
          final signIn = await supabase.auth.signInWithPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
          if (!mounted) {
            return;
          }
          if (signIn.session == null) {
            _showMessage('Account created. Please sign in.');
            return;
          }
        }
      } else {
        final response = await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (response.session == null) {
          _showMessage('Sign-in did not return a session.');
          return;
        }
      }

      if (!mounted) {
        return;
      }

      // Return to RootGate, which reacts to the new auth state and routes to
      // onboarding or the home shell automatically.
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on AuthException catch (error) {
      final message = _friendlyAuthError(error.message);
      setState(() => _errorMessage = message);
      _showMessage(error.message);
    } catch (error) {
      setState(() => _errorMessage = 'Authentication failed. Use App Preview while we finish account setup.');
      _showMessage('Authentication failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage =
            'Enter your email first, then use password reset.';
      });
      _showMessage('Enter your email address first.');
      return;
    }

    final supabase = SetupServices.maybeSupabaseClient;
    if (supabase == null) {
      setState(() {
        _errorMessage =
            'Supabase is not configured yet, so password reset is unavailable.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final redirectTo = _authRedirectUrl();

      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo,
      );

      if (!mounted) return;

      setState(() {
        _errorMessage =
            'Password reset email sent. Check your inbox, then reopen the app from the reset link.';
      });
      _showMessage('Password reset email sent.');
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
      _showMessage(error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not send password reset email.');
      _showMessage('Could not send password reset email: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage =
            'Enter your email first, then request a sign-in link.';
      });
      _showMessage('Enter your email address first.');
      return;
    }

    final supabase = SetupServices.maybeSupabaseClient;
    if (supabase == null) {
      setState(() {
        _errorMessage =
            'Supabase is not configured yet, so magic-link sign-in is unavailable.';
      });
      return;
    }

    if (_isOtpCooldownActive) {
      final remaining = 60 - DateTime.now().difference(_lastOtpRequestAt!).inSeconds;
      setState(() {
        _errorMessage =
            'Please wait about $remaining seconds before requesting another sign-in link.';
      });
      _showMessage('Please wait before requesting another sign-in link.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final redirectTo = _authRedirectUrl();

      await supabase.auth.signInWithOtp(
        email: email,
        emailRedirectTo: redirectTo,
      );

      if (!mounted) return;
      setState(() {
        _lastOtpRequestAt = DateTime.now();
        _errorMessage =
            'Magic link sent. Open it from your email to sign in without your password.';
      });
      _showMessage('Magic link sent.');
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
      _showMessage(error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not send sign-in link.');
      _showMessage('Could not send sign-in link: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'That email/password combination was rejected by Supabase. If the account does not exist yet, switch to Create Account or use App Preview for now.';
    }
    if (lower.contains('security purposes') ||
        lower.contains('rate limit') ||
        lower.contains('too many requests')) {
      return 'Supabase temporarily rate-limited email auth requests. Wait a minute, then try the sign-in link or reset email again.';
    }
    if (lower.contains('email not confirmed')) {
      return 'The account exists but is not confirmed yet. You can still use App Preview while auth is being finished.';
    }
    return message;
  }

  bool get _isOtpCooldownActive {
    final last = _lastOtpRequestAt;
    if (last == null) return false;
    return DateTime.now().difference(last).inSeconds < 60;
  }

  String get _otpCooldownLabel {
    final last = _lastOtpRequestAt;
    if (last == null) return 'Email me a sign-in link';
    final remaining = 60 - DateTime.now().difference(last).inSeconds;
    if (remaining <= 0) return 'Email me a sign-in link';
    return 'Try again in ${remaining}s';
  }

  String _authRedirectUrl() {
    final base = Uri.base;
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '/',
    ).toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isCreatingAccount
                          ? 'Create your account'
                          : 'Welcome back',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) {
                          return 'Please enter your email.';
                        }
                        if (!email.contains('@')) {
                          return 'Please enter a valid email.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Use at least 6 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _isCreatingAccount ? 'Create Account' : 'Sign In',
                            ),
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(
                              () => _isCreatingAccount = !_isCreatingAccount,
                            ),
                      child: Text(
                        _isCreatingAccount
                            ? 'Use an existing account'
                            : 'Create a new account',
                      ),
                    ),
                    if (!_isCreatingAccount)
                      TextButton(
                        onPressed: (_isLoading || _isOtpCooldownActive)
                            ? null
                            : _sendMagicLink,
                        child: Text(_otpCooldownLabel),
                      ),
                    if (!_isCreatingAccount)
                      TextButton(
                        onPressed: _isLoading ? null : _sendResetEmail,
                        child: const Text('Forgot password? Send reset email'),
                      ),
                    OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AppPreviewScreen(),
                                ),
                              ),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Open App Preview'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
