import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:provider/provider.dart';

import 'photoTalkTheme.dart';

/// A slim PhotoTalk profile page.
///
/// Replaces the original Twitter-clone profile screen with a calm
/// large-text layout that surfaces the things a care recipient or
/// caregiver actually needs to see: name, email, role, and a clear
/// way to sign out.
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
                    profile == null ? 'Care recipient' : 'Family member'),
                if (uid != null)
                  _row(Icons.fingerprint, 'Account ID',
                      uid.substring(0, uid.length.clamp(0, 12)) + '…'),
              ]),
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
          ClipOval(
            child: SizedBox(
              width: 72,
              height: 72,
              child: photoUrl == null || photoUrl.isEmpty
                  ? Container(
                      color: PhotoTalkPalette.background,
                      alignment: Alignment.center,
                      child: const Icon(Icons.person,
                          size: 36, color: PhotoTalkPalette.textMuted),
                    )
                  : Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: PhotoTalkPalette.background,
                        alignment: Alignment.center,
                        child: const Icon(Icons.person,
                            size: 36, color: PhotoTalkPalette.textMuted),
                      ),
                    ),
            ),
          ),
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
