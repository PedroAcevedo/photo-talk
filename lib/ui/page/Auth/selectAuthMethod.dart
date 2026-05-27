import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/helper/enum.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:flutter_twitter_clone/ui/page/Auth/signup.dart';
import 'package:flutter_twitter_clone/ui/page/Auth/signin.dart';
import 'package:flutter_twitter_clone/ui/page/homePage.dart';
import 'package:flutter_twitter_clone/ui/page/photoTalk/photoTalkTheme.dart';
import 'package:provider/provider.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Listen so this rebuilds when auth state flips after signup/signin.
    final state = context.watch<AuthState>();
    if (state.authStatus == AuthStatus.LOGGED_IN) {
      return const HomePage();
    }

    return Scaffold(
      backgroundColor: PhotoTalkPalette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              _logo(),
              const SizedBox(height: 28),
              Text('Welcome to PhotoTalk',
                  textAlign: TextAlign.center,
                  style: PhotoTalkText.h1.copyWith(fontSize: 30)),
              const SizedBox(height: 12),
              Text(
                'A calm place to share family photos, music, and stories together.',
                textAlign: TextAlign.center,
                style: PhotoTalkText.body
                    .copyWith(color: PhotoTalkPalette.textSecondary),
              ),
              const Spacer(flex: 3),
              _primaryButton(
                context,
                label: 'Create an account',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const Signup(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _secondaryButton(
                context,
                label: 'I already have an account',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SignIn(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    return Container(
      width: 120,
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PhotoTalkPalette.primary.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.photo_library_rounded,
        size: 64,
        color: PhotoTalkPalette.primary,
      ),
    );
  }

  Widget _primaryButton(BuildContext context,
      {required String label, required VoidCallback onPressed}) {
    return SizedBox(
      height: 58,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: PhotoTalkPalette.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _secondaryButton(BuildContext context,
      {required String label, required VoidCallback onPressed}) {
    return SizedBox(
      height: 58,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: PhotoTalkPalette.primary,
          side: const BorderSide(
              color: PhotoTalkPalette.primary, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}
