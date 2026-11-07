import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_config.dart';
import 'media_cache.dart';

/// What the app last read from Supabase, as plain JSON-friendly maps. The same
/// object drives the live screens and is saved to disk as the local cache.
class RemoteSnapshot {
  RemoteSnapshot(this.data);
  final Map<String, dynamic> data;

  String get uid => data['uid'] as String;

  List<Map<String, dynamic>> rows(String key) =>
      (data[key] as List? ?? const []).cast<Map<String, dynamic>>();

  Set<String> ids(String key) => (data[key] as List? ?? const []).cast<String>().toSet();
}

/// Every Supabase read and write the app makes. Screens never call Supabase
/// directly; they go through AppState, which goes through this class.
class IntlyRepo {
  IntlyRepo._();

  static const postBucket = 'post-media';
  static const reelBucket = 'reel-media';

  static const _profileCols = 'id, username, display_name, bio, accent_hue, is_private';
  static const _postCols = 'id, user_id, body, background_index, font_index, text_color_index, created_at, '
      'post_media(storage_path, media_type, poster_path, sort_order), '
      'post_stickers(emoji, position_x, position_y, scale, sort_order), '
      'post_likes(count), comments(count), post_shares(count)';
  static const _commentCols =
      'id, post_id, user_id, parent_id, reply_to_user_id, body, created_at, comment_likes(count)';
  static const _reelCols = 'id, user_id, caption, video_path, audio_path, audio_name, poster_path, '
      'playback_speed, touch_strength, effect_index, hue, icon_index, created_at, '
      'reel_likes(count), reel_bookmarks(count), reel_reposts(count), reel_shares(count), reel_comments(count)';
  static const _reelCommentCols =
      'id, reel_id, user_id, parent_id, reply_to_user_id, body, created_at, reel_comment_likes(count)';
  static const _notifCols =
      'id, actor_id, notification_type, message, post_id, comment_id, reel_id, is_read, created_at';
  static const _draftCols = 'id, video_path, audio_path, audio_name, poster_path, caption, '
      'playback_speed, touch_strength, effect_index, created_at';

  static const _postCounts = {
    'post_likes': 'like_count', 'comments': 'comment_count', 'post_shares': 'share_count',
  };
  static const _reelCounts = {
    'reel_likes': 'like_count', 'reel_bookmarks': 'save_count', 'reel_reposts': 'repost_count',
    'reel_shares': 'share_count', 'reel_comments': 'comment_count',
  };
  static const _commentCounts = {'comment_likes': 'like_count'};
  static const _reelCommentCounts = {'reel_comment_likes': 'like_count'};

  static final _tagPattern = RegExp(r'#([A-Za-z0-9_]{1,100})');

  static SupabaseClient get _db => Supabase.instance.client;
  static String? get currentUid => SupabaseConfig.ready ? _db.auth.currentUser?.id : null;
  static bool get signedIn => currentUid != null;
  static String get _uid => currentUid!;

  /// The UI calls the signed-in user 'me'. The server knows them by UUID.
  static String _id(String id) => id == 'me' ? _uid : id;

  /// A short, user-facing reason for a failed call.
  static String describe(Object e) {
    if (e is PostgrestException) return e.message;
    if (e is StorageException) return e.message;
    if (e is AuthException) return e.message;
    if (e is SocketException || e is TimeoutException) {
      return "Couldn't reach Intly. Check your connection and try again.";
    }
    return 'Something went wrong. Please try again.';
  }

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Reads the whole visible app state for the signed-in user in three short
  /// rounds. Row-level security decides what each query may return.
  static Future<RemoteSnapshot> fetchSnapshot() async {
    final me = _uid;

    // Round 1: rows that depend only on the signed-in user.
    final r1 = await Future.wait<dynamic>([
      _db.from('profiles').select(_profileCols).eq('id', me),
      _db.from('user_settings').select().eq('user_id', me),
      _db.from('posts').select(_postCols).order('created_at', ascending: false).limit(50),
      _db.from('reels').select(_reelCols).order('created_at', ascending: false).limit(30),
      _db
          .from('notifications')
          .select(_notifCols)
          .eq('recipient_id', me)
          .order('created_at', ascending: false)
          .limit(100),
      _db.from('reel_drafts').select(_draftCols).eq('user_id', me).order('created_at', ascending: false),
    ]);
    final posts = _list(r1[2], _postCounts);
    final reels = _list(r1[3], _reelCounts);
    final notifs = _list(r1[4]);
    final postIds = _ids(posts, 'id');
    final reelIds = _ids(reels, 'id');

    // Round 2: comments, and the signed-in user's own likes and saves.
    final r2 = await Future.wait<dynamic>([
      _when(postIds, () => _db
          .from('comments')
          .select(_commentCols)
          .inFilter('post_id', postIds)
          .order('created_at', ascending: false)
          .limit(1000)),
      _when(reelIds, () => _db
          .from('reel_comments')
          .select(_reelCommentCols)
          .inFilter('reel_id', reelIds)
          .order('created_at', ascending: false)
          .limit(1000)),
      _when(postIds, () => _db.from('post_likes').select('post_id').eq('user_id', me).inFilter('post_id', postIds)),
      _when(postIds, () => _db.from('post_bookmarks').select('post_id').eq('user_id', me).inFilter('post_id', postIds)),
      _when(reelIds, () => _db.from('reel_likes').select('reel_id').eq('user_id', me).inFilter('reel_id', reelIds)),
      _when(reelIds, () => _db.from('reel_bookmarks').select('reel_id').eq('user_id', me).inFilter('reel_id', reelIds)),
      _when(reelIds, () => _db.from('reel_reposts').select('reel_id').eq('user_id', me).inFilter('reel_id', reelIds)),
      _db.from('comment_likes').select('comment_id').eq('user_id', me),
      _db.from('reel_comment_likes').select('reel_comment_id').eq('user_id', me),
    ]);
    final comments = _list(r2[0], _commentCounts);
    final reelComments = _list(r2[1], _reelCommentCounts);

    // Round 3: everyone involved, so names, avatars and follow counts can show.
    final authors = <String>{me};
    for (final r in [...posts, ...comments, ...reels, ...reelComments, ...notifs]) {
      for (final key in ['user_id', 'reply_to_user_id', 'actor_id']) {
        final v = r[key];
        if (v is String) authors.add(v);
      }
    }
    final ids = authors.toList();
    final or = ids.join(',');
    final r3 = await Future.wait<dynamic>([
      _db.from('profiles').select(_profileCols).inFilter('id', ids),
      _db.from('follows').select().or('follower_id.in.($or),following_id.in.($or)'),
    ]);

    return RemoteSnapshot({
      'uid': me,
      'fetchedAt': DateTime.now().toUtc().toIso8601String(),
      'settings': _list(r1[1]),
      'profiles': _list(r3[0]),
      'follows': _list(r3[1]),
      'posts': posts,
      'comments': comments,
      'reels': reels,
      'reelComments': reelComments,
      'notifs': notifs,
      'drafts': _list(r1[5]),
      'postLiked': _ids(r2[2], 'post_id'),
      'postSaved': _ids(r2[3], 'post_id'),
      'reelLiked': _ids(r2[4], 'reel_id'),
      'reelSaved': _ids(r2[5], 'reel_id'),
      'reelReposted': _ids(r2[6], 'reel_id'),
      'commentLiked': _ids(r2[7], 'comment_id'),
      'reelCommentLiked': _ids(r2[8], 'reel_comment_id'),
    });
  }

  // ---------------------------------------------------------------------------
  // Profile and settings
  // ---------------------------------------------------------------------------

  static Future<void> updateProfile({required String name, required String bio}) async {
    await _db.from('profiles').update({'display_name': name, 'bio': bio}).eq('id', _uid);
  }

  static Future<void> setPrivate(bool value) async {
    await _db.from('profiles').update({'is_private': value}).eq('id', _uid);
  }

  static Future<void> updateSettings(Map<String, dynamic> patch) async {
    await _db.from('user_settings').update(patch).eq('user_id', _uid);
  }

  // ---------------------------------------------------------------------------
  // Posts and comments
  // ---------------------------------------------------------------------------

  /// Creates a post, or updates one when [id] is given. Local media files are
  /// uploaded only when [replaceMedia] is true. Returns the post id.
  static Future<String> savePost({
    String? id,
    required String body,
    required int bg,
    required int font,
    required int tcolor,
    required List<Map<String, dynamic>> stickers,
    String? imageLocal,
    String? videoLocal,
    required bool replaceMedia,
  }) async {
    final patch = {
      'body': body,
      'background_index': bg,
      'font_index': font,
      'text_color_index': tcolor,
    };
    final String postId;
    if (id == null) {
      final row = await _db.from('posts').insert({...patch, 'user_id': _uid}).select('id').single();
      postId = row['id'] as String;
    } else {
      postId = id;
      await _db.from('posts').update(patch).eq('id', postId);
    }

    await _db.from('post_stickers').delete().eq('post_id', postId);
    if (stickers.isNotEmpty) {
      await _db.from('post_stickers').insert([
        for (var i = 0; i < stickers.length; i++) {'post_id': postId, ...stickers[i], 'sort_order': i},
      ]);
    }

    if (replaceMedia) {
      await _db.from('post_media').delete().eq('post_id', postId);
      final media = <Map<String, dynamic>>[];
      if (videoLocal != null) {
        final vp = await uploadMedia(postBucket, '$_uid/$postId/video.${_ext(videoLocal)}', videoLocal);
        final pp = imageLocal == null
            ? null
            : await uploadMedia(postBucket, '$_uid/$postId/poster.${_ext(imageLocal)}', imageLocal);
        media.add({
          'post_id': postId, 'media_type': 'video', 'storage_path': vp, 'poster_path': pp,
          'mime_type': _mime(videoLocal), 'sort_order': 0,
        });
      } else if (imageLocal != null) {
        final ip = await uploadMedia(postBucket, '$_uid/$postId/image.${_ext(imageLocal)}', imageLocal);
        media.add({
          'post_id': postId, 'media_type': 'image', 'storage_path': ip,
          'mime_type': _mime(imageLocal), 'sort_order': 0,
        });
      }
      if (media.isNotEmpty) await _db.from('post_media').insert(media);
    }

    await _syncPostHashtags(postId, body);
    return postId;
  }

  static Future<void> deletePost(String id) async {
    await _db.from('posts').delete().eq('id', id);
  }

  static Future<void> setPostLike(String postId, bool on) => _link('post_likes', 'post_id', postId, on);
  static Future<void> setPostSave(String postId, bool on) => _link('post_bookmarks', 'post_id', postId, on);

  static Future<void> reportPost(String postId) async {
    await _db.from('reports').insert({
      'reporter_id': _uid, 'post_id': postId, 'reason': 'other', 'details': '',
    });
  }

  /// Adds a comment or a reply. Returns the new comment id.
  static Future<String> addComment(String postId, String body, {String? parentId, String? replyTo}) async {
    final row = await _db.from('comments').insert({
      'post_id': postId,
      'user_id': _uid,
      'body': body,
      'parent_id': parentId,
      'reply_to_user_id': replyTo == null ? null : _id(replyTo),
    }).select('id').single();
    return row['id'] as String;
  }

  static Future<void> setCommentLike(String commentId, bool on) => _link('comment_likes', 'comment_id', commentId, on);

  // ---------------------------------------------------------------------------
  // Reels and drafts
  // ---------------------------------------------------------------------------

  /// Uploads one reel file (video, audio or poster) into a folder for this reel.
  static Future<String> uploadReelFile(String localFile, String folder, String name) =>
      uploadMedia(reelBucket, '$_uid/$folder/$name.${_ext(localFile)}', localFile);

  static Future<void> insertReel({
    required String videoPath,
    String? audioPath,
    String? posterPath,
    required String audioName,
    required String caption,
    required double speed,
    required double touch,
    required int fx,
  }) async {
    await _db.from('reels').insert({
      'user_id': _uid,
      'video_path': videoPath,
      'audio_path': audioPath,
      'poster_path': posterPath,
      'audio_name': audioName,
      'caption': caption,
      'playback_speed': speed,
      'touch_strength': touch,
      'effect_index': fx,
    });
  }

  static Future<String> insertDraft({
    required String videoPath,
    String? audioPath,
    String? posterPath,
    required String audioName,
    required String caption,
    required double speed,
    required double touch,
    required int fx,
  }) async {
    final row = await _db.from('reel_drafts').insert({
      'user_id': _uid,
      'video_path': videoPath,
      'audio_path': audioPath,
      'poster_path': posterPath,
      'audio_name': audioName,
      'caption': caption,
      'playback_speed': speed,
      'touch_strength': touch,
      'effect_index': fx,
    }).select('id').single();
    return row['id'] as String;
  }

  static Future<void> deleteDraft(String id) async {
    await _db.from('reel_drafts').delete().eq('id', id);
  }

  static Future<void> deleteReel(String id) async {
    await _db.from('reels').delete().eq('id', id);
  }

  static Future<void> setReelLike(String reelId, bool on) => _link('reel_likes', 'reel_id', reelId, on);
  static Future<void> setReelSave(String reelId, bool on) => _link('reel_bookmarks', 'reel_id', reelId, on);
  static Future<void> setReelRepost(String reelId, bool on) => _link('reel_reposts', 'reel_id', reelId, on);

  static Future<void> shareReel(String reelId) async {
    await _db.from('reel_shares').insert({'reel_id': reelId, 'user_id': _uid});
  }

  static Future<String> addReelComment(String reelId, String body, {String? parentId, String? replyTo}) async {
    final row = await _db.from('reel_comments').insert({
      'reel_id': reelId,
      'user_id': _uid,
      'body': body,
      'parent_id': parentId,
      'reply_to_user_id': replyTo == null ? null : _id(replyTo),
    }).select('id').single();
    return row['id'] as String;
  }

  static Future<void> setReelCommentLike(String commentId, bool on) =>
      _link('reel_comment_likes', 'reel_comment_id', commentId, on);

  // ---------------------------------------------------------------------------
  // Follows and notifications
  // ---------------------------------------------------------------------------

  /// Follows [target]. Returns 'pending' when the account is private.
  static Future<String> follow(String target) async {
    final row = await _db
        .from('follows')
        .insert({'follower_id': _uid, 'following_id': _id(target)})
        .select('status')
        .single();
    return row['status'] as String;
  }

  static Future<void> unfollow(String target) async {
    await _db.from('follows').delete().eq('follower_id', _uid).eq('following_id', _id(target));
  }

  /// Accepts a follow request from [follower] (private accounts only).
  static Future<void> acceptFollower(String follower) async {
    await _db
        .from('follows')
        .update({'status': 'accepted'})
        .eq('follower_id', _id(follower))
        .eq('following_id', _uid);
  }

  /// Declines a pending request, or removes someone who follows you.
  static Future<void> removeFollower(String follower) async {
    await _db.from('follows').delete().eq('follower_id', _id(follower)).eq('following_id', _uid);
  }

  static Future<void> markNotificationRead(String id) async {
    await _db.from('notifications').update({'is_read': true}).eq('id', id);
  }

  static Future<void> markAllNotificationsRead() async {
    await _db.from('notifications').update({'is_read': true}).eq('recipient_id', _uid).eq('is_read', false);
  }

  // ---------------------------------------------------------------------------
  // Storage and helpers
  // ---------------------------------------------------------------------------

  /// Uploads a local file and keeps a copy in the media cache. Returns the path.
  static Future<String> uploadMedia(String bucket, String path, String localFile) async {
    final file = File(localFile);
    await _db.storage.from(bucket).upload(
          path,
          file,
          fileOptions: FileOptions(upsert: true, contentType: _mime(localFile)),
        );
    await MediaCache.adopt(bucket, path, file);
    return path;
  }

  static Future<void> _link(String table, String col, String id, bool on) async {
    if (on) {
      await _db.from(table).upsert(
            {col: id, 'user_id': _uid},
            onConflict: '$col,user_id',
            ignoreDuplicates: true,
          );
    } else {
      await _db.from(table).delete().eq(col, id).eq('user_id', _uid);
    }
  }

  /// Keeps post_hashtags in step with the text: #Tag becomes the tag "tag".
  static Future<void> _syncPostHashtags(String postId, String text) async {
    final tags = _tagPattern.allMatches(text).map((m) => m.group(1)!.toLowerCase()).toSet().toList();
    await _db.from('post_hashtags').delete().eq('post_id', postId);
    if (tags.isEmpty) return;
    await _db.from('hashtags').upsert(
          [for (final t in tags) {'tag': t}],
          onConflict: 'tag',
          ignoreDuplicates: true,
        );
    final rows = await _db.from('hashtags').select('id, tag').inFilter('tag', tags);
    await _db.from('post_hashtags').insert([
      for (final r in rows) {'post_id': postId, 'hashtag_id': r['id']},
    ]);
  }

  static Future<dynamic> _when(List<String> ids, Future<dynamic> Function() query) =>
      ids.isEmpty ? Future<dynamic>.value(const <dynamic>[]) : query();

  static List<Map<String, dynamic>> _list(Object? v, [Map<String, String> counts = const {}]) =>
      ((v as List?) ?? const []).map((e) => _flatten(Map<String, dynamic>.from(e as Map), counts)).toList();

  static List<String> _ids(Object? rows, String col) =>
      [for (final r in (rows as List? ?? const [])) (r as Map)[col] as String];

  /// Turns an embedded count such as "post_likes": [{"count": 3}] into a plain
  /// number under the alias, so the cache and the state stay simple.
  static Map<String, dynamic> _flatten(Map<String, dynamic> row, Map<String, String> counts) {
    final out = Map<String, dynamic>.from(row);
    counts.forEach((embed, alias) {
      out[alias] = _count(out.remove(embed));
    });
    return out;
  }

  static int _count(dynamic embed) {
    if (embed is List && embed.isNotEmpty && embed.first is Map) {
      return ((embed.first as Map)['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  static String _ext(String path) {
    final i = path.lastIndexOf('.');
    return i < 0 ? 'bin' : path.substring(i + 1).toLowerCase();
  }

  static String _mime(String path) => switch (_ext(path)) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'mp4' => 'video/mp4',
        'mov' => 'video/quicktime',
        'webm' => 'video/webm',
        'm4a' => 'audio/mp4',
        'mp3' => 'audio/mpeg',
        'aac' => 'audio/aac',
        _ => 'application/octet-stream',
      };
}
