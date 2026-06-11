import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/helper/enum.dart';
import 'package:flutter_twitter_clone/helper/utility.dart';
import 'package:flutter_twitter_clone/model/user.dart';
import 'package:flutter_twitter_clone/services/care_circle_service.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:flutter_twitter_clone/ui/page/homePage.dart';
import 'package:flutter_twitter_clone/ui/page/photoTalk/photoTalkTheme.dart';
import 'package:provider/provider.dart';

/// Roles a PhotoTalk account can take.
enum PtRole { careRecipient, family, caregiver }

extension on PtRole {
  String get serialized {
    switch (this) {
      case PtRole.careRecipient:
        return 'care_recipient';
      case PtRole.family:
        return 'family';
      case PtRole.caregiver:
        return 'caregiver';
    }
  }
}

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
  final _joinCodeController = TextEditingController();

  final CareCircleService _careCircle = CareCircleService();

  /// Step 0: pick role. Step 1: enter join code (only family/caregiver).
  /// Step 2: name/email/password.
  int _step = 0;
  PtRole? _role;
  String? _linkedRecipientId;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  void _pickRole(PtRole role) {
    setState(() {
      _role = role;
      _step = (role == PtRole.careRecipient) ? 2 : 1;
    });
  }

  Future<void> _verifyJoinCode() async {
    final code = _joinCodeController.text.trim().toUpperCase();
    if (code.length != 6) {
      _toast('Please enter the 6-character code from your family member.');
      return;
    }
    setState(() => _busy = true);
    String? recipientId;
    try {
      recipientId = await _careCircle.resolveCode(code).timeout(
            const Duration(seconds: 10),
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(
        "Couldn't reach the family-code service. Check your internet "
        "connection and your Firebase rules for /joinCodes.",
      );
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (recipientId == null) {
      _toast(
          "That code doesn't match any account. Double-check with your family member.");
      return;
    }
    setState(() {
      _linkedRecipientId = recipientId;
      _step = 2;
    });
  }

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
    if (password.length < 8) {
      _toast('Password must be at least 8 characters');
      return;
    }
    if (password != confirm) {
      _toast('Passwords do not match');
      return;
    }

    setState(() => _busy = true);

    final state = Provider.of<AuthState>(context, listen: false);

    // For care recipients we mint a fresh join code now so we can put
    // it on their profile at sign-up time.
    String? joinCode;
    if (_role == PtRole.careRecipient) {
      joinCode = CareCircleService.generateJoinCode();
    }

    final user = UserModel(
      email: email,
      bio: 'Edit profile to update bio',
      displayName: name,
      dob: '',
      location: '',
      isVerified: false,
      role: _role!.serialized,
      joinCode: joinCode,
      linkedRecipientId:
          _role == PtRole.careRecipient ? null : _linkedRecipientId,
    );

    await state.signUp(user, password: password, context: context);

    if (!mounted) return;

    if (state.authStatus == AuthStatus.LOGGED_IN) {
      // Care recipient: their userId is now known, finalize linkedRecipient
      // (self) and reserve the join code in /joinCodes.
      if (_role == PtRole.careRecipient && joinCode != null) {
        final uid = state.user!.uid;
        await _careCircle.reserveCode(joinCode, uid);
      }
      // Refresh current-user data so HomePage has a user model immediately.
      await state.getCurrentUser();
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } else {
      setState(() => _busy = false);
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
        leading: _step == 0
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    // Back from "details" jumps to the previous applicable
                    // step (join code for family, role for recipient).
                    if (_step == 2) {
                      _step = (_role == PtRole.careRecipient) ? 0 : 1;
                    } else if (_step == 1) {
                      _step = 0;
                    }
                  });
                },
              ),
        title: Text(
          _step == 0
              ? "Who are you?"
              : _step == 1
                  ? "Connect to your family"
                  : "Create your account",
          style: PhotoTalkText.title,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: _step == 0
                  ? _rolePicker()
                  : _step == 1
                      ? _joinCodeStep()
                      : _detailsStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rolePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("Who's using PhotoTalk?", style: PhotoTalkText.h2),
        const SizedBox(height: 8),
        Text(
          'This helps us set things up the right way.',
          style: PhotoTalkText.caption.copyWith(fontSize: 15),
        ),
        const SizedBox(height: 20),
        _roleCard(
          icon: Icons.spa_outlined,
          color: PhotoTalkPalette.accentGreen,
          title: 'For me',
          subtitle:
              "I'll look at photos and chat with the Companion. My family will share memories with me.",
          onTap: () => _pickRole(PtRole.careRecipient),
        ),
        const SizedBox(height: 12),
        _roleCard(
          icon: Icons.family_restroom,
          color: PhotoTalkPalette.primary,
          title: "I'm a family member",
          subtitle: "I'll share photos and memories with a loved one.",
          onTap: () => _pickRole(PtRole.family),
        ),
        const SizedBox(height: 12),
        _roleCard(
          icon: Icons.favorite,
          color: PhotoTalkPalette.accentRose,
          title: "I'm a caregiver",
          subtitle:
              "I help care for someone and want to see their engagement and recaps.",
          onTap: () => _pickRole(PtRole.caregiver),
        ),
      ],
    );
  }

  Widget _roleCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: PhotoTalkPalette.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: PhotoTalkPalette.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: PhotoTalkText.title),
                    const SizedBox(height: 4),
                    Text(subtitle, style: PhotoTalkText.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: PhotoTalkPalette.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _joinCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Enter your family code', style: PhotoTalkText.h2),
        const SizedBox(height: 8),
        Text(
          "Ask your loved one (or their caregiver) for the 6-character code "
          "that appears on their account. It's how we'll show your memories "
          "on their feed.",
          style: PhotoTalkText.body
              .copyWith(color: PhotoTalkPalette.textSecondary),
        ),
        const SizedBox(height: 24),
        _field(
          label: 'Family code',
          hint: 'ABC234',
          controller: _joinCodeController,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 58,
          child: ElevatedButton(
            onPressed: _busy ? null : _verifyJoinCode,
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
                : const Text('Continue'),
          ),
        ),
      ],
    );
  }

  Widget _detailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Let's set things up.",
          style: PhotoTalkText.h2,
        ),
        const SizedBox(height: 6),
        Text(
          _role == PtRole.careRecipient
              ? 'You can change these details any time.'
              : 'These details are just for your account.',
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
          hint: 'At least 8 characters',
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
