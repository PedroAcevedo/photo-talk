import 'dart:convert';

import 'package:http/http.dart' as http;

/// Photo context the Companion uses to ground its conversation.
class CompanionPhotoContext {
  final String caption;
  final String? who;
  final String? where;
  final String? why;
  final String? song;
  final List<String> tags;
  final String? imageUrl;

  const CompanionPhotoContext({
    required this.caption,
    this.who,
    this.where,
    this.why,
    this.song,
    this.tags = const [],
    this.imageUrl,
  });

  String toPromptContext() {
    final lines = <String>[
      'Photo caption: "$caption"',
      if (who != null && who!.trim().isNotEmpty) 'People in the photo: $who',
      if (where != null && where!.trim().isNotEmpty) 'Where it was taken: $where',
      if (why != null && why!.trim().isNotEmpty) 'Why it matters to the family: $why',
      if (song != null && song!.trim().isNotEmpty) 'Associated song: $song',
      if (tags.isNotEmpty) 'Mood tags: ${tags.join(', ')}',
    ];
    return lines.join('\n');
  }
}

/// One message in the Companion conversation.
class CompanionMessage {
  final String role; // 'user' | 'assistant'
  final String content;

  const CompanionMessage.user(this.content) : role = 'user';
  const CompanionMessage.assistant(this.content) : role = 'assistant';

  Map<String, dynamic> toApiMap() => {'role': role, 'content': content};
}

/// Wraps the OpenAI Chat Completions API for the PhotoTalk Companion.
///
/// Reads the API key from `String.fromEnvironment('OPENAI_API_KEY')`, set
/// at run time with:
///     flutter run --dart-define=OPENAI_API_KEY=sk-xxxxx
///
/// If the key is missing, every method falls back to a deterministic,
/// dementia-supportive canned response so the app remains usable.
class CompanionService {
  CompanionService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _model = 'gpt-4o-mini';
  static const String _endpoint =
      'https://api.openai.com/v1/chat/completions';

  static const String _apiKey =
      String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');

  bool get hasApiKey => _apiKey.isNotEmpty;

  static const String _systemPromptBase = '''
You are PhotoTalk Companion, a gentle, warm AI companion designed to support
a person living with dementia as they look at a family photo.

Core principles you must follow at all times:
- Use short, simple, supportive sentences. Aim for 1-2 sentences per reply.
- Focus on feelings, comfort, recognition, and meaning — not facts or recall.
- Never ask the person to identify or remember names, dates, or events.
- Avoid quiz-like questions ("Do you remember who this is?") and corrections.
- If the person seems confused, distracted, or upset, gently pivot to the
  present moment, what they notice, or what they enjoy.
- Use the photo context only as a soft starting point — do not lecture about
  the photo or push details.
- Validate the person's emotions. If they share something sad or hard,
  acknowledge it warmly and stay present.
- Keep the conversation calm, slow, and short. End an exchange softly if
  the person stops responding or expresses distress.
''';

  /// Build the initial opening line for the conversation given the photo.
  Future<String> openingPrompt(CompanionPhotoContext photo) async {
    if (!hasApiKey) return _cannedOpening(photo);
    try {
      final reply = await _chat(
        photo: photo,
        history: const [],
        userMessage:
            '(Start the conversation. Greet the person warmly and invite them '
            'to share what they notice or feel about this photo, in 1-2 short '
            'sentences. Do not ask them to identify anyone.)',
      );
      return reply ?? _cannedOpening(photo);
    } catch (_) {
      return _cannedOpening(photo);
    }
  }

  /// Get the next supportive reply from the Companion.
  Future<String> respond({
    required CompanionPhotoContext photo,
    required List<CompanionMessage> history,
    required String userMessage,
  }) async {
    if (!hasApiKey) return _cannedReply(userMessage);
    try {
      final reply = await _chat(
        photo: photo,
        history: history,
        userMessage: userMessage,
      );
      return reply ?? _cannedReply(userMessage);
    } catch (_) {
      return _cannedReply(userMessage);
    }
  }

  /// Ask GPT to write a short Story Snippet summary of the conversation.
  /// Returns a map with keys: quote, theme, tone.
  Future<Map<String, String>?> summarizeSnippet({
    required CompanionPhotoContext photo,
    required List<CompanionMessage> history,
  }) async {
    if (!hasApiKey || history.isEmpty) return null;
    try {
      final transcript = history
          .map((m) =>
              '${m.role == 'user' ? 'Person' : 'Companion'}: ${m.content}')
          .join('\n');

      final body = jsonEncode({
        'model': _model,
        'temperature': 0.4,
        'response_format': {'type': 'json_object'},
        'messages': [
          {
            'role': 'system',
            'content':
                'You summarize short conversations between an AI companion and '
                    'a person living with dementia about a family photo. Return '
                    'a single JSON object with keys: '
                    '"quote" (one short, warm sentence in first person that '
                    'captures something the person enjoyed, felt, or shared), '
                    '"theme" (one or two of: joy, calm, family, humor, kindness, '
                    'pride, comfort, togetherness, hard work), '
                    '"tone" (one of: Joyful, Calm, Reflective, Tender, Mixed). '
                    'Do not invent facts. If you have nothing meaningful to '
                    'capture, set "quote" to "".',
          },
          {
            'role': 'user',
            'content':
                'Photo context:\n${photo.toPromptContext()}\n\nTranscript:\n$transcript',
          },
        ],
      });

      final response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final content =
          decoded['choices']?[0]?['message']?['content'] as String?;
      if (content == null) return null;
      final parsed = jsonDecode(content) as Map<String, dynamic>;
      final quote = (parsed['quote'] ?? '').toString().trim();
      if (quote.isEmpty) return null;
      return {
        'quote': quote,
        'theme': (parsed['theme'] ?? '').toString(),
        'tone': (parsed['tone'] ?? 'Calm').toString(),
      };
    } catch (_) {
      return null;
    }
  }

  // -------- internals --------

  Future<String?> _chat({
    required CompanionPhotoContext photo,
    required List<CompanionMessage> history,
    required String userMessage,
  }) async {
    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content':
            '$_systemPromptBase\n\nThe photo in front of the person right now:\n${photo.toPromptContext()}',
      },
      ...history.map((m) => m.toApiMap()),
      {'role': 'user', 'content': userMessage},
    ];

    final response = await _client
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': _model,
            'temperature': 0.7,
            'max_tokens': 120,
            'messages': messages,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      // Surface the error for the calling UI but don't crash.
      return null;
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final content =
        decoded['choices']?[0]?['message']?['content'] as String?;
    return content?.trim();
  }

  // ---- canned fallbacks so the app stays usable without an API key ----

  String _cannedOpening(CompanionPhotoContext photo) {
    if (photo.who != null && photo.who!.trim().isNotEmpty) {
      return "What a lovely picture. ${photo.who} looks so happy here. "
          "What do you notice in this moment?";
    }
    return "What a lovely picture. There's no rush — what stands out to you here?";
  }

  String _cannedReply(String userText) {
    final lower = userText.toLowerCase();
    if (lower.contains('happy') ||
        lower.contains('love') ||
        lower.contains('glad')) {
      return "That's such a warm thing to share. It sounds like a moment "
          "you truly enjoy.";
    }
    if (lower.contains('sad') ||
        lower.contains('miss') ||
        lower.contains('hard')) {
      return "I hear you. Those feelings make sense. We can sit with this "
          "as long as you'd like.";
    }
    if (lower.length < 8) {
      return "Thank you for telling me. Take your time — there's no rush.";
    }
    return "That's a beautiful thing to remember. Tell me anything else "
        "you'd like to share.";
  }
}
