import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/helper/constant.dart';
import 'package:flutter_twitter_clone/helper/enum.dart';
import 'package:flutter_twitter_clone/helper/utility.dart';
import 'package:flutter_twitter_clone/model/user.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:flutter_twitter_clone/ui/page/homePage.dart';
import 'package:flutter_twitter_clone/ui/page/photoTalk/photoTalkTheme.dart';
import 'package:provider/provider.dart';

/// PhotoTalk Create-account form.
///
/// Restyled to the calm/warm theme. On success it pushes HomePage and
/// clears the back stack, so the user lands inside the app immediately
/// without seeing the welcome page again.
class Signup extends StatefulWidget {
  const Signup({Key? key}) : super(key: key);

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  Future<void> _submit() async {
    if (_busy) return;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.isEmpty) {
      _toast('Please enter your name');
      return;
    }
    if (name.length > 27) {
      _toast('Name must be 27 characters or less');
      return;
    }
    if (email.isEmpty || !_isValidEmail(email)) {
      _toast('Please enter a valid email address');
      return;
    }
    if (password.length < 6) {
      _toast('Password must be at least 6 characters');
      return;
    }
    if (password != confirm) {
      _toast('Passwords do not match');
      return;
    }

    setState(() => _busy = true);

    final state = Provider.of<AuthState>(context, listen: false);
    final random = Random().nextInt(8);
    final user = UserModel(
      email: email,
      bio: 'Edit profile to update bio',
      displayName: name,
      dob: DateTime(1950, DateTime.now().month, DateTime.now().day + 3)
          .toString(),
      location: '',
      profilePic: Constants.dummyProfilePicList[random],
      isVerified: false,
    );

    await state.signUp(user, password: password, context: context);

    if (!mounted) return;
    setState(() => _busy = false);

    if (state.authStatus == AuthStatus.LOGGED_IN) {
      // Refresh current-user data so HomePage has a user model immediately.
      await state.getCurrentUser();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    }
  }

  void _toast(String msg) {
    Utility.customSnackBar(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhotoTalkPalette.background,
      appBar: AppBar(
        backgroundColor: PhotoTalkPalette.background,
        foregroundColor: PhotoTalkPalette.textPrimary,
        elevation: 0,
        title: Text('Create your account', style: PhotoTalkText.title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Let's set things up.",
                style: PhotoTalkText.h2,
              ),
              const SizedBox(height: 6),
              Text(
                'You can change these details any time.',
                style: PhotoTalkText.caption.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 24),
              _field(
                label: 'Your name',
                hint: 'Mary Johnson',
                controller: _nameController,
              ),
              _field(
                label: 'Email',
                hint: 'you@example.com',
                controller: _emailController,
                keyboard: TextInputType.emailAddress,
              ),
              _field(
                label: 'Password',
                hint: 'At least 6 characters',
                controller: _passwordController,
                obscure: true,
              ),
              _field(
                label: 'Confirm password',
                hint: 'Type it again',
                controller: _confirmController,
                obscure: true,
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
                      : const Text('Create account'),
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
