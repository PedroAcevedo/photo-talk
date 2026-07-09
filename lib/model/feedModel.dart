// ignore_for_file: avoid_print

import 'package:flutter_twitter_clone/model/user.dart';

class FeedModel {
  String? key;
  String? parentkey;
  String? childRetwetkey;
  String? description;
  late String userId;
  int? likeCount;
  List<String>? likeList;
  int? commentCount;
  int? retweetCount;
  late String createdAt;
  String? imagePath;
  List<String>? tags;
  List<String?>? replyTweetKeyList;
  String?
      lanCode; //Saving the language of the tweet so to not translate to check which language
  UserModel? user;
  /// PhotoTalk: the care recipient on whose feed this memory should
  /// appear. Equals the uploader's linkedRecipientId (or their own uid,
  /// if they are themselves a care recipient).
  String? careRecipientId;
  /// PhotoTalk: optional uploaded audio (mp3/m4a/wav) attached to the
  /// memory. Played in Music + Captions mode.
  String? audioPath;
  /// PhotoTalk: optional human-readable song title separate from the
  /// audio URL.
  String? songTitle;
  /// PhotoTalk: an optional external media link (YouTube / Spotify /
  /// Apple Music etc.) that opens in an in-app webview overlay from
  /// Music + Captions mode. Used when the family doesn't want to (or
  /// can't) upload an audio file.
  String? externalMediaUrl;
  /// PhotoTalk: multi-photo support. When a memory carries more than one
  /// image the URLs live here. [imagePath] is kept as the first entry so
  /// older code paths (and legacy data) still resolve.
  List<String>? imagePaths;
  /// PhotoTalk: gentle conversation starters drafted by GPT during the
  /// upload step. The Companion uses them as opener seeds.
  List<String>? prompts;
  FeedModel(
      {this.key,
      this.description,
      required this.userId,
      this.likeCount,
      this.commentCount,
      this.retweetCount,
      required this.createdAt,
      this.imagePath,
      this.likeList,
      this.tags,
      this.user,
      this.replyTweetKeyList,
      this.parentkey,
      this.lanCode,
      this.childRetwetkey,
      this.careRecipientId,
      this.audioPath,
      this.songTitle,
      this.imagePaths,
      this.prompts,
      this.externalMediaUrl});
  toJson() {
    return {
      "userId": userId,
      "description": description,
      "likeCount": likeCount,
      "commentCount": commentCount ?? 0,
      "retweetCount": retweetCount ?? 0,
      "createdAt": createdAt,
      "imagePath": imagePath,
      "likeList": likeList,
      "tags": tags,
      "replyTweetKeyList": replyTweetKeyList,
      "user": user == null ? null : user!.toJson(),
      "parentkey": parentkey,
      "lanCode": lanCode,
      "childRetwetkey": childRetwetkey,
      "careRecipientId": careRecipientId,
      "audioPath": audioPath,
      "songTitle": songTitle,
      "imagePaths": imagePaths,
      "prompts": prompts,
      "externalMediaUrl": externalMediaUrl,
    };
  }

  FeedModel.fromJson(Map<dynamic, dynamic> map) {
    key = map['key'];
    description = map['description'];
    userId = map['userId'];
    likeCount = map['likeCount'] ?? 0;
    commentCount = map['commentCount'];
    retweetCount = map["retweetCount"] ?? 0;
    imagePath = map['imagePath'];
    createdAt = map['createdAt'];
    imagePath = map['imagePath'];
    lanCode = map['lanCode'];
    user = UserModel.fromJson(map['user']);
    parentkey = map['parentkey'];
    childRetwetkey = map['childRetwetkey'];
    careRecipientId = map['careRecipientId'];
    audioPath = map['audioPath'];
    songTitle = map['songTitle'];
    externalMediaUrl = map['externalMediaUrl'];
    if (map['imagePaths'] != null) {
      imagePaths = <String>[];
      map['imagePaths'].forEach((value) {
        if (value is String && value.isNotEmpty) imagePaths!.add(value);
      });
    }
    // Back-compat: legacy memories only have imagePath. Surface it as the
    // single entry of imagePaths so newer UI doesn't have to special-case.
    if ((imagePaths == null || imagePaths!.isEmpty) &&
        imagePath != null &&
        imagePath!.isNotEmpty) {
      imagePaths = [imagePath!];
    }
    if (map['prompts'] != null) {
      prompts = <String>[];
      map['prompts'].forEach((value) {
        if (value is String && value.trim().isNotEmpty) {
          prompts!.add(value.toString());
        }
      });
    }
    if (map['tags'] != null) {
      tags = <String>[];
      map['tags'].forEach((value) {
        tags!.add(value);
      });
    }
    if (map["likeList"] != null) {
      likeList = <String>[];

      final list = map['likeList'];

      /// In new tweet db schema likeList is stored as a List<String>()
      ///
      if (list is List) {
        map['likeList'].forEach((value) {
          if (value is String) {
            likeList!.add(value);
          }
        });
        likeCount = likeList!.length;
      }

      /// In old database tweet db schema likeList is saved in the form of map
      /// like list map is removed from latest code but to support old schema below code is required
      /// Once all user migrated to new version like list map support will be removed
      else if (list is Map) {
        list.forEach((key, value) {
          likeList!.add(value["userId"]);
        });
        likeCount = list.length;
      }
    } else {
      likeList = [];
      likeCount = 0;
    }
    if (map['replyTweetKeyList'] != null) {
      map['replyTweetKeyList'].forEach((value) {
        replyTweetKeyList = <String>[];
        map['replyTweetKeyList'].forEach((value) {
          replyTweetKeyList!.add(value);
        });
      });
      commentCount = replyTweetKeyList!.length;
    } else {
      replyTweetKeyList = [];
      commentCount = 0;
    }
  }

  bool get isValidTweet {
    bool isValid = false;
    if (user != null && user!.userName != null && user!.userName!.isNotEmpty) {
      isValid = true;
    } else {
      print("Invalid Tweet found. Id:- $key");
    }
    return isValid;
  }

  /// get tweet key to retweet.
  ///
  /// If tweet [TweetType] is [TweetType.Retweet] and its description is null
  /// then its retweeted child tweet will be shared.
  String get getTweetKeyToRetweet {
    if (description == null && imagePath == null && childRetwetkey != null) {
      return childRetwetkey!;
    } else {
      return key!;
    }
  }
}
