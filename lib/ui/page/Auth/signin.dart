import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/helper/enum.dart';
import 'package:flutter_twitter_clone/helper/utility.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:flutter_twitter_clone/ui/page/homePage.dart';
import 'package:flutter_twitter_clone/ui/page/photoTalk/photoTalkTheme.dart';
import 'package:provider/provider.dart';

/// PhotoTalk Sign-in form.
///
/// On success: pushes HomePage and clears the back stack so the welcome
/// page doesn't reappear underneath.
class SignIn extends StatefulWidget {
  const SignIn({Key? key}) : super(key: key);

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!Utility.validateCredentials(context, email, password)) {
      return;
    }

    setState(() => _busy = true);
    final state = Provider.of<AuthState>(context, listen: false);

    final uid = await state.signIn(email, password, context: context);

    if (uid != null) {
      // signIn() doesn't flip authStatus itself; refresh current user
      // so AuthStatus and userModel are populated before we navigate.
      await state.getCurrentUser();
    }

    if (!mounted) return;
    setState(() => _busy = false);

    if (state.authStatus == AuthStatus.LOGGED_IN) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhotoTalkPalette.background,
      appBar: AppBar(
        backgroundColor: PhotoTalkPalette.background,
        foregroundColor: PhotoTalkPalette.textPrimary,
        elevation: 0,
        title: Text('Sign in', style: PhotoTalkText.title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Welcome back.', style: PhotoTalkText.h2),
              const SizedBox(height: 24),
              _field(
                label: 'Email',
                hint: 'you@example.com',
                controller: _emailController,
                keyboard: TextInputType.emailAddress,
              ),
              _field(
                label: 'Password',
                hint: 'Your password',
                controller: _passwordController,
                obscure: true,
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/ForgetPasswordPage');
                  },
                  child: Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: PhotoTalkPalette.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 58,
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PhotoTalkPalette.primary,
                    disabledBackgroundColor:
                        PhotoTalkPalette.primary.withOpacity(0.5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Sign in'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: PhotoTalkText.chip
                  .copyWith(color: PhotoTalkPalette.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboard,
            style: PhotoTalkText.bodyLarge,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: PhotoTalkText.caption.copyWith(fontSize: 15),
              filled: true,
              fillColor: PhotoTalkPalette.surface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: PhotoTalkPalette.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: PhotoTalkPalette.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
