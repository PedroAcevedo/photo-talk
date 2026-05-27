import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/helper/constant.dart';
import 'package:flutter_twitter_clone/helper/utility.dart';
import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/model/user.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:flutter_twitter_clone/state/feedState.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'photoTalkTheme.dart';

/// "Upload a memory" - the PhotoTalk replacement for compose-tweet.
///
/// Same submission path as before (uses FeedState.uploadFile/createTweet)
/// but framed around photo + context (who, where, why, notes, song).
class UploadMemoryPage extends StatefulWidget {
  const UploadMemoryPage({Key? key}) : super(key: key);

  @override
  State<UploadMemoryPage> createState() => _UploadMemoryPageState();
}

class _UploadMemoryPageState extends State<UploadMemoryPage> {
  File? _photo;
  final _caption = TextEditingController();
  final _who = TextEditingController();
  final _where = TextEditingController();
  final _why = TextEditingController();
  final _song = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _caption.dispose();
    _who.dispose();
    _where.dispose();
    _why.dispose();
    _song.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto({required ImageSource source}) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _photo = File(picked.path));
      }
    } catch (e) {
      Utility.customSnackBar(context, "Couldn't open photo: $e");
    }
  }

  Future<void> _submit() async {
    // Dismiss keyboard for clearer feedback.
    FocusScope.of(context).unfocus();

    if (_photo == null && _caption.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add a photo or a short caption to save.')),
      );
      return;
    }
    setState(() => _submitting = true);

    final feedState = Provider.of<FeedState>(context, listen: false);
    final authState = Provider.of<AuthState>(context, listen: false);
    final myUser = authState.userModel;

    if (myUser == null) {
      // Demo path: just close. In production we'd require sign-in.
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Memory saved (demo).')),
      );
      return;
    }

    final user = UserModel(
      displayName: myUser.displayName ?? myUser.email!.split('@')[0],
      profilePic: myUser.profilePic ?? Constants.dummyProfilePic,
      userId: myUser.userId,
      isVerified: myUser.isVerified,
      userName: myUser.userName,
    );

    // Compose the caption + context into the FeedModel.description so we
    // don't need data-model changes for this view pass.
    final composedDescription = [
      _caption.text.trim(),
      if (_who.text.trim().isNotEmpty) 'Who: ${_who.text.trim()}',
      if (_where.text.trim().isNotEmpty) 'Where: ${_where.text.trim()}',
      if (_why.text.trim().isNotEmpty) 'Why it matters: ${_why.text.trim()}',
      if (_song.text.trim().isNotEmpty) 'Song: ${_song.text.trim()}',
    ].where((s) => s.isNotEmpty).join('\n');

    final model = FeedModel(
      description: composedDescription,
      user: user,
      createdAt: DateTime.now().toUtc().toString(),
      userId: myUser.userId!,
      tags: const ['memory'],
    );

    try {
      // We bypass FeedState.uploadFile / createTweet on purpose: those
      // wrappers swallow every Firebase exception with a `cprint` and
      // return null, so the user never sees the real error. Writing
      // directly lets us surface the actual code/message in the UI.
      await _writeDirectly(model).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException(
          "Couldn't reach Firebase after 20 seconds. The most common "
          "causes are: Realtime Database not enabled, the wrong "
          "databaseURL in firebase_options.dart, or security rules "
          "still blocking the write.",
        ),
      );

      // Refresh the feed.
      feedState.getDataFromDatabase();

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: PhotoTalkPalette.accentGreen,
          content: Text(
            'Memory saved. It will appear in Today\'s Memories.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    } on TimeoutException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(e.message ?? "Couldn't reach Firebase.");
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      // Firebase tells us which service failed: 'firebase_database',
      // 'firebase_storage', etc.  Surface that.
      _showError(
        'Firebase ${e.plugin} error: ${e.code}\n${e.message ?? ''}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError("Couldn't save memory: $e");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: PhotoTalkPalette.accentRose,
        duration: const Duration(seconds: 8),
        content: Text(message, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  /// Writes the memory directly to Storage + RTDB so any FirebaseException
  /// propagates up to the UI instead of being silently swallowed.
  Future<void> _writeDirectly(FeedModel model) async {
    if (_photo != null) {
      final filename = DateTime.now().toIso8601String().replaceAll(':', '-') +
          '_' +
          _photo!.path.split(Platform.pathSeparator).last;
      final ref =
          FirebaseStorage.instance.ref().child('tweetImage').child(filename);
      await ref.putFile(_photo!);
      model.imagePath = await ref.getDownloadURL();
    }

    final db = FirebaseDatabase.instance.ref();
    final newRef = db.child('tweet').push();
    await newRef.set(model.toJson());
    model.key = newRef.key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhotoTalkPalette.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: PhotoTalkPalette.background,
        foregroundColor: PhotoTalkPalette.textPrimary,
        title: Text('Add a memory', style: PhotoTalkText.title),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: PhotoTalkPalette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Save',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _photoBlock(),
              const SizedBox(height: 20),
              _field(
                controller: _caption,
                label: 'Caption',
                hint: 'A short, friendly title for this memory',
                maxLines: 2,
              ),
              _field(
                controller: _who,
                label: 'Who is in the photo',
                hint: 'Mom, Dad, Aunt Rose...',
                icon: Icons.people_alt_outlined,
              ),
              _field(
                controller: _where,
                label: 'Where was it taken',
                hint: 'Lake George, summer 1978',
                icon: Icons.place_outlined,
              ),
              _field(
                controller: _why,
                label: 'Why it matters',
                hint: 'A few words about what this memory means',
                icon: Icons.favorite_border,
                maxLines: 3,
              ),
              _field(
                controller: _song,
                label: 'Song (optional)',
                hint: 'Here Comes the Sun — The Beatles',
                icon: Icons.music_note_rounded,
              ),
              const SizedBox(height: 12),
              _audioNotePlaceholder(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoBlock() {
    return SizedBox(
      // Cap the height so the photo block can't push fields off-screen
      // on wide layouts (tablet, web).
      height: 260,
      child: GestureDetector(
        onTap: () => _showPhotoSheet(),
        child: Container(
          decoration: BoxDecoration(
            color: PhotoTalkPalette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: PhotoTalkPalette.divider,
                width: _photo == null ? 2 : 0),
            image: _photo != null
                ? DecorationImage(image: FileImage(_photo!), fit: BoxFit.cover)
                : null,
          ),
          child: _photo != null
              ? Stack(
                  children: [
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() => _photo = null),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.close,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo_outlined,
                        size: 56, color: PhotoTalkPalette.primary),
                    const SizedBox(height: 10),
                    Text('Add a photo',
                        style: PhotoTalkText.title
                            .copyWith(color: PhotoTalkPalette.primary)),
                    const SizedBox(height: 4),
                    Text('Tap to choose from camera or gallery',
                        style: PhotoTalkText.caption),
                  ],
                ),
        ),
      ),
    );
  }

  void _showPhotoSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: PhotoTalkPalette.primary),
                title:
                    Text('Take a photo', style: PhotoTalkText.bodyLarge),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(source: ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: PhotoTalkPalette.primary),
                title: Text('Choose from gallery',
                    style: PhotoTalkText.bodyLarge),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(source: ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 18, color: PhotoTalkPalette.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: PhotoTalkText.chip
                    .copyWith(color: PhotoTalkPalette.textSecondary)),
          ]),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: PhotoTalkText.bodyLarge,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: PhotoTalkText.caption.copyWith(fontSize: 15),
              filled: true,
              fillColor: PhotoTalkPalette.surface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
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

  Widget _audioNotePlaceholder() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PhotoTalkPalette.accentBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: PhotoTalkPalette.accentBlue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic_none_rounded,
              color: PhotoTalkPalette.accentBlue, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add a voice note',
                    style: PhotoTalkText.body
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(
                  'Record your own voice telling the story (coming soon)',
                  style: PhotoTalkText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
