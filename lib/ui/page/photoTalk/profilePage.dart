import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/services/care_settings_service.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:provider/provider.dart';

import 'photoTalkTheme.dart';
import 'widgets/generic_avatar.dart';

/// A slim PhotoTalk profile page.
///
/// Replaces the original Twitter-clone profile screen with a calm
/// large-text layout that surfaces the things a care recipient or
/// caregiver actually needs to see: name, email, role, family code,
/// and the AI-disabled toggle that any care-circle member can flip.
class PhotoTalkProfilePage extends StatelessWidget {
  const PhotoTalkProfilePage({Key? key}) : super(key: key);

  static Route<T> getRoute<T>() {
    return MaterialPageRoute(builder: (_) => const PhotoTalkProfilePage());
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthState>();
    final profile = state.userModel;
    final authUser = state.user; // Firebase Auth user, when profile is null

    // Resolve each field with a sane fallback chain:
    //   profile.displayName -> auth.displayName -> email prefix -> "Friend"
    final email = profile?.email ?? authUser?.email ?? '';
    final displayName = profile?.displayName ??
        authUser?.displayName ??
        (email.contains('@') ? email.split('@').first : 'Friend');
    final photoUrl = profile?.profilePic ?? authUser?.photoURL;
    final uid = profile?.userId ?? authUser?.uid;

    // If we have a Firebase Auth user but no profile model yet, kick off
    // a profile fetch (which will self-heal if no /profile/{uid} exists).
    if (profile == null && authUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        state.getProfileUser();
      });
    }

    return Scaffold(
      backgroundColor: PhotoTalkPalette.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: PhotoTalkPalette.background,
        foregroundColor: PhotoTalkPalette.textPrimary,
        title: Text('Profile', style: PhotoTalkText.title),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _header(displayName, email, photoUrl),
              const SizedBox(height: 24),
              _section(title: 'Your details', rows: [
                _row(Icons.person_outline, 'Name', displayName),
                _row(Icons.mail_outline, 'Email',
                    email.isEmpty ? 'Not set' : email),
                _row(Icons.badge_outlined, 'Role',
                    _humanRole(profile?.role)),
                if (uid != null)
                  _row(Icons.fingerprint, 'Account ID',
                      uid.substring(0, uid.length.clamp(0, 12)) + '…'),
              ]),
              if (profile?.role == 'care_recipient' &&
                  profile?.joinCode != null) ...[
                const SizedBox(height: 16),
                _joinCodeCard(context, profile!.joinCode!),
              ],
              const SizedBox(height: 16),
              _careCircleControls(
                profile?.linkedRecipientId ?? profile?.userId ?? uid,
              ),
              const SizedBox(height: 16),
              _section(title: 'Preferences', rows: [
                _row(Icons.spa_outlined, 'Default mode', 'Calm Mode'),
                _row(Icons.text_fields, 'Text size', 'Large'),
                _row(Icons.notifications_none, 'Daily reminder', 'Off'),
              ]),
              const SizedBox(height: 24),
              _logoutButton(context),
            ],
          ),
        ),
      ),
    );
  }

  String _humanRole(String? role) {
    switch (role) {
      case 'care_recipient':
        return 'Care recipient';
      case 'family':
        return 'Family member';
      case 'caregiver':
        return 'Caregiver';
      default:
        return 'Care recipient';
    }
  }

  Widget _careCircleControls(String? recipientId) {
    if (recipientId == null) return const SizedBox.shrink();
    final service = CareSettingsService();
    return StreamBuilder<CareSettings>(
      stream: service.watch(recipientId),
      builder: (context, snap) {
        final settings = snap.data ?? const CareSettings();
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: PhotoTalkPalette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: PhotoTalkPalette.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Care settings', style: PhotoTalkText.title),
              const SizedBox(height: 4),
              Text(
                "Anyone in the care circle can change these.",
                style: PhotoTalkText.caption,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      color: PhotoTalkPalette.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          settings.aiDisabled
                              ? 'AI Companion is off'
                              : 'AI Companion is on',
                          style: PhotoTalkText.body
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          settings.aiDisabled
                              ? "The 'Talk about it' button is paused."
                              : 'Conversations are available from any memory.',
                          style: PhotoTalkText.caption,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: !settings.aiDisabled,
                    activeColor: PhotoTalkPalette.primary,
                    onChanged: (on) async {
                      try {
                        await service.setAiDisabled(recipientId, !on);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: PhotoTalkPalette.accentRose,
                            content: Text("Couldn't change setting: $e",
                                style: const TextStyle(color: Colors.white)),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _joinCodeCard(BuildContext context, String code) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PhotoTalkPalette.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: PhotoTalkPalette.primary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.share_outlined,
                color: PhotoTalkPalette.primary),
            const SizedBox(width: 8),
            Text('Family code', style: PhotoTalkText.title),
          ]),
          const SizedBox(height: 8),
          Text(
            "Share this code with family or your caregiver. When they sign up "
            "and enter it, their memories will show on your feed.",
            style: PhotoTalkText.body
                .copyWith(color: PhotoTalkPalette.textSecondary),
          ),
          const SizedBox(height: 14),
          SelectableText(
            code,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
              fontFamily: 'monospace',
              color: PhotoTalkPalette.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(String? name, String? email, String? photoUrl) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
      decoration: BoxDecoration(
        color: PhotoTalkPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PhotoTalkPalette.divider),
      ),
      child: Row(
        children: [
          const GenericAvatar(size: 72),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name ?? 'Guest', style: PhotoTalkText.h2),
                const SizedBox(height: 4),
                if (email != null)
                  Text(email, style: PhotoTalkText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({required String title, required List<Widget> rows}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PhotoTalkPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PhotoTalkPalette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: PhotoTalkText.title),
          const SizedBox(height: 4),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: PhotoTalkPalette.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: PhotoTalkText.caption),
                Text(value,
                    style: PhotoTalkText.body
                        .copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoutButton(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: () {
          final state = Provider.of<AuthState>(context, listen: false);
          state.logoutCallback();
        },
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Sign out',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: PhotoTalkPalette.accentRose,
          side: const BorderSide(color: PhotoTalkPalette.accentRose),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
