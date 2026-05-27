import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/helper/utility.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:flutter_twitter_clone/ui/page/photoTalk/photoTalkTheme.dart';
import 'package:provider/provider.dart';

class ForgetPasswordPage extends StatefulWidget {
  const ForgetPasswordPage({Key? key}) : super(key: key);

  @override
  State<ForgetPasswordPage> createState() => _ForgetPasswordPageState();
}

class _ForgetPasswordPageState extends State<ForgetPasswordPage> {
  final _emailController = TextEditingController();
  final _focusNode = FocusNode();
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      Utility.customSnackBar(context, 'Please enter your email address');
      return;
    }
    if (!Utility.validateEmail(email)) {
      Utility.customSnackBar(context, 'Please enter a valid email address');
      return;
    }
    _focusNode.unfocus();
    final state = Provider.of<AuthState>(context, listen: false);
    state.forgetPassword(email, context: context);
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhotoTalkPalette.background,
      appBar: AppBar(
        backgroundColor: PhotoTalkPalette.background,
        foregroundColor: PhotoTalkPalette.textPrimary,
        elevation: 0,
        title: Text('Reset password', style: PhotoTalkText.title),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Forgot your password?', style: PhotoTalkText.h2),
              const SizedBox(height: 8),
              Text(
                "Enter the email you used and we'll send you a link to set a new one.",
                style: PhotoTalkText.body
                    .copyWith(color: PhotoTalkPalette.textSecondary),
              ),
              const SizedBox(height: 24),
              Text('Email',
                  style: PhotoTalkText.chip
                      .copyWith(color: PhotoTalkPalette.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                focusNode: _focusNode,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: PhotoTalkText.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'you@example.com',
                  hintStyle: PhotoTalkText.caption.copyWith(fontSize: 15),
                  filled: true,
                  fillColor: PhotoTalkPalette.surface,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: PhotoTalkPalette.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: PhotoTalkPalette.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 58,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PhotoTalkPalette.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Send reset link'),
                ),
              ),
              if (_sent) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: PhotoTalkPalette.accentGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: PhotoTalkPalette.accentGreen.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: PhotoTalkPalette.accentGreen),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'If that email is in our system, a reset link is on its way.',
                          style: PhotoTalkText.body,
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
    );
  }
}
