import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_twitter_clone/helper/constant.dart';
import 'package:flutter_twitter_clone/helper/utility.dart';
import 'package:flutter_twitter_clone/model/feedModel.dart';
import 'package:flutter_twitter_clone/model/user.dart';
import 'package:flutter_twitter_clone/services/companion_service.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:flutter_twitter_clone/state/feedState.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:file_picker/file_picker.dart';

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
  /// Photos selected for this memory, in the order they should appear.
  /// Bytes are kept in memory so uploads work on web (where File paths
  /// aren't usable).
  final List<_PickedPhoto> _photos = [];
  // Audio attachment (mp3/m4a/wav/aac). We keep the bytes in memory so
  // the upload works on web too, where File paths aren't reliable.
  String? _audioName;
  Uint8List? _audioBytes;
  final _caption = TextEditingController();
  final _who = TextEditingController();
  final _where = TextEditingController();
  final _why = TextEditingController();
  final _song = TextEditingController();
  final _mediaLink = TextEditingController();
  bool _submitting = false;
  // AI prompt suggestions. Once the family asks for suggestions, we keep
  // them here and persist them with the memory.
  List<String> _suggestedPrompts = [];
  bool _suggesting = false;

  @override
  void dispose() {
    _caption.dispose();
    _who.dispose();
    _where.dispose();
    _why.dispose();
    _song.dispose();
    _mediaLink.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      if (f.bytes == null) {
        Utility.customSnackBar(
            context, "Couldn't read that file. Try a different one.");
        return;
      }
      setState(() {
        _audioName = f.name;
        _audioBytes = f.bytes;
      });
    } catch (e) {
      Utility.customSnackBar(context, "Couldn't open audio: $e");
    }
  }

  Future<void> _pickPhoto({required ImageSource source}) async {
    try {
      final picker = ImagePicker();
      if (source == ImageSource.gallery) {
        // Multi-select from the gallery.
        final picks = await picker.pickMultiImage(
          maxWidth: 1600,
          imageQuality: 85,
        );
        if (picks.isEmpty) return;
        for (final p in picks) {
          final bytes = await p.readAsBytes();
          _photos.add(_PickedPhoto(file: p, bytes: bytes));
        }
        if (mounted) setState(() {});
      } else {
        // Camera always returns one shot.
        final XFile? picked = await picker.pickImage(
          source: source,
          maxWidth: 1600,
          imageQuality: 85,
        );
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        if (!mounted) return;
        setState(() {
          _photos.add(_PickedPhoto(file: picked, bytes: bytes));
        });
      }
    } catch (e) {
      Utility.customSnackBar(context, "Couldn't open photo: $e");
    }
  }

  void _removePhotoAt(int index) {
    setState(() {
      if (index >= 0 && index < _photos.length) _photos.removeAt(index);
    });
  }

  Future<void> _suggestPrompts() async {
    if (_suggesting) return;
    final caption = _caption.text.trim();
    final who = _who.text.trim();
    final where = _where.text.trim();
    final why = _why.text.trim();
    if (caption.isEmpty && who.isEmpty && where.isEmpty && why.isEmpty) {
      Utility.customSnackBar(
        context,
        'Add a caption or some context first so prompts feel personal.',
      );
      return;
    }
    setState(() => _suggesting = true);
    try {
      final service = CompanionService();
      final photo = CompanionPhotoContext(
        caption: caption.isEmpty ? 'A family memory' : caption,
        who: who.isEmpty ? null : who,
        where: where.isEmpty ? null : where,
        why: why.isEmpty ? null : why,
        song: _song.text.trim().isEmpty ? null : _song.text.trim(),
      );
      final prompts = await service.suggestPrompts(photo);
      if (!mounted) return;
      setState(() {
        _suggestedPrompts = prompts;
        _suggesting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _suggesting = false);
      Utility.customSnackBar(context, "Couldn't draft prompts: $e");
    }
  }

  Future<void> _submit() async {
    // Dismiss keyboard for clearer feedback.
    FocusScope.of(context).unfocus();

    if (_photos.isEmpty && _caption.text.trim().isEmpty) {
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
    final firebaseUser = authState.user;
    final fallbackName = firebaseUser?.displayName?.trim().isNotEmpty == true
        ? firebaseUser!.displayName!.trim()
        : firebaseUser?.email?.split('@').first ?? 'PhotoTalk Friend';
    final fallbackUserName =
        fallbackName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final userId = myUser?.userId ?? firebaseUser?.uid ?? 'phototalk-demo-user';

    final user = UserModel(
      displayName: myUser?.displayName ?? fallbackName,
      email: myUser?.email ?? firebaseUser?.email,
      profilePic: myUser?.profilePic ??
          firebaseUser?.photoURL ??
          Constants.dummyProfilePic,
      userId: userId,
      isVerified: myUser?.isVerified ?? firebaseUser?.emailVerified ?? false,
      userName: myUser?.userName ?? fallbackUserName,
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

    // The memory should land on the care recipient's feed. For family /
    // caregiver accounts that's their linkedRecipientId; for a care
    // recipient uploading to themselves, it's their own uid.
    final recipientId = myUser?.linkedRecipientId ?? myUser?.userId ?? userId;

    final model = FeedModel(
      description: composedDescription,
      user: user,
      createdAt: DateTime.now().toUtc().toString(),
      userId: userId,
      tags: const ['memory'],
      careRecipientId: recipientId,
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
    if (_photos.isNotEmpty) {
      final urls = <String>[];
      for (var i = 0; i < _photos.length; i++) {
        final p = _photos[i];
        final safeName =
            p.file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
        final filename =
            '${DateTime.now().toIso8601String().replaceAll(':', '-')}_${i}_$safeName';
        final ref = FirebaseStorage.instance
            .ref()
            .child('tweetImage')
            .child(filename);
        await ref.putData(p.bytes);
        urls.add(await ref.getDownloadURL());
      }
      model.imagePaths = urls;
      // Keep imagePath for back-compat readers (sidebar previews, legacy
      // queries) — same value as imagePaths[0].
      model.imagePath = urls.first;
    }

    if (_suggestedPrompts.isNotEmpty) {
      model.prompts = List<String>.from(_suggestedPrompts);
    }

    if (_audioBytes != null && _audioName != null) {
      final safeName =
          _audioName!.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final filename =
          '${DateTime.now().toIso8601String().replaceAll(':', '-')}_$safeName';
      final guessedMime = _guessAudioMime(safeName);
      final ref =
          FirebaseStorage.instance.ref().child('tweetAudio').child(filename);
      await ref.putData(
        _audioBytes!,
        SettableMetadata(contentType: guessedMime),
      );
      model.audioPath = await ref.getDownloadURL();
    }

    // Pull the song title out of the existing _song field so the player
    // can show it alongside the audio.
    if (_song.text.trim().isNotEmpty) {
      model.songTitle = _song.text.trim();
    }

    // External media link (YouTube / Spotify / Apple Music) — persisted
    // only when it looks like a URL to avoid saving accidental typos.
    final link = _mediaLink.text.trim();
    if (link.isNotEmpty) {
      final looksLikeUrl =
          RegExp(r'^https?://', caseSensitive: false).hasMatch(link);
      model.externalMediaUrl = looksLikeUrl ? link : 'https://$link';
    }

    final db = FirebaseDatabase.instance.ref();
    final newRef = db.child('tweet').push();
    await newRef.set(model.toJson());
    model.key = newRef.key;
  }

  String _guessAudioMime(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) return 'audio/mp4';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.ogg') || lower.endsWith('.oga')) return 'audio/ogg';
    return 'audio/mpeg';
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
              _field(
                controller: _mediaLink,
                label: 'External media link (optional)',
                hint: 'YouTube, Spotify, or Apple Music URL',
                icon: Icons.link_rounded,
                keyboard: TextInputType.url,
              ),
              const SizedBox(height: 12),
              _suggestedPromptsBlock(),
              const SizedBox(height: 12),
              _audioNotePlaceholder(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoBlock() {
    if (_photos.isEmpty) {
      // Empty state: a single big "Add photos" tile.
      return SizedBox(
        height: 220,
        child: GestureDetector(
          onTap: () => _showPhotoSheet(),
          child: Container(
            decoration: BoxDecoration(
              color: PhotoTalkPalette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: PhotoTalkPalette.divider, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_a_photo_outlined,
                    size: 56, color: PhotoTalkPalette.primary),
                const SizedBox(height: 10),
                Text('Add photos',
                    style: PhotoTalkText.title
                        .copyWith(color: PhotoTalkPalette.primary)),
                const SizedBox(height: 4),
                Text(
                    'Tap to choose one or several from camera or gallery',
                    style: PhotoTalkText.caption,
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }
    // With photos: a horizontal thumbnail strip with remove + an "add more"
    // tile at the end.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _photos.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              if (i == _photos.length) return _addMoreTile();
              return _photoThumb(i);
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _photos.length == 1
              ? '1 photo selected'
              : '${_photos.length} photos selected',
          style: PhotoTalkText.caption,
        ),
      ],
    );
  }

  Widget _photoThumb(int index) {
    final p = _photos[index];
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: Image.memory(p.bytes, fit: BoxFit.cover),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _removePhotoAt(index),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ),
          if (index == 0)
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Cover',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ),
        ],
      ),
    );
  }

  Widget _addMoreTile() {
    return GestureDetector(
      onTap: () => _showPhotoSheet(),
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          color: PhotoTalkPalette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PhotoTalkPalette.divider, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.add_photo_alternate_outlined,
                size: 36, color: PhotoTalkPalette.primary),
            SizedBox(height: 6),
            Text('Add more',
                style: TextStyle(
                  color: PhotoTalkPalette.primary,
                  fontWeight: FontWeight.w600,
                )),
          ],
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
                title: Text('Take a photo', style: PhotoTalkText.bodyLarge),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(source: ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: PhotoTalkPalette.primary),
                title:
                    Text('Choose from gallery', style: PhotoTalkText.bodyLarge),
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
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: PhotoTalkPalette.textSecondary),
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
            keyboardType: keyboard,
            style: PhotoTalkText.bodyLarge,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: PhotoTalkText.caption.copyWith(fontSize: 15),
              filled: true,
              fillColor: PhotoTalkPalette.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: PhotoTalkPalette.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: PhotoTalkPalette.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestedPromptsBlock() {
    final hasPrompts = _suggestedPrompts.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PhotoTalkPalette.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: PhotoTalkPalette.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined,
                  color: PhotoTalkPalette.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasPrompts
                      ? 'Companion prompts (saved with this memory)'
                      : 'Suggested conversation starters',
                  style: PhotoTalkText.body
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (hasPrompts)
                IconButton(
                  tooltip: 'Clear suggestions',
                  icon: const Icon(Icons.close_rounded,
                      color: PhotoTalkPalette.textSecondary),
                  onPressed: () =>
                      setState(() => _suggestedPrompts = []),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasPrompts
                ? 'These will be available to the Companion when your loved one taps "Talk about it" on this memory.'
                : 'Tap "Suggest prompts" and we\'ll draft three gentle openers for the Companion to use later.',
            style: PhotoTalkText.caption,
          ),
          const SizedBox(height: 10),
          if (hasPrompts)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestedPrompts
                  .map((p) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: PhotoTalkPalette.primary
                                  .withOpacity(0.4)),
                        ),
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: 320),
                          child: Text(p,
                              style: PhotoTalkText.body
                                  .copyWith(fontSize: 14)),
                        ),
                      ))
                  .toList(),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _suggesting ? null : _suggestPrompts,
                icon: _suggesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Suggest prompts'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PhotoTalkPalette.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  textStyle:
                      const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _audioNotePlaceholder() {
    final hasAudio = _audioBytes != null && _audioName != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PhotoTalkPalette.accentBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: PhotoTalkPalette.accentBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.music_note_rounded,
              color: PhotoTalkPalette.accentBlue, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasAudio ? 'Music attached' : 'Add a song or audio',
                  style: PhotoTalkText.body
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  hasAudio
                      ? _audioName!
                      : 'Tap to attach an mp3, m4a, or wav file from this device.',
                  style: PhotoTalkText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (hasAudio)
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close_rounded,
                  color: PhotoTalkPalette.accentBlue),
              onPressed: () => setState(() {
                _audioBytes = null;
                _audioName = null;
              }),
            )
          else
            ElevatedButton.icon(
              onPressed: _pickAudio,
              icon: const Icon(Icons.attach_file_rounded, size: 18),
              label: const Text('Choose'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PhotoTalkPalette.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _PickedPhoto {
  final XFile file;
  final Uint8List bytes;
  const _PickedPhoto({required this.file, required this.bytes});
}
