class Comment {
  final String id;
  final CommentUser user;
  final String content;
  final String timestamp;
  final String rawTimestamp;
  final String likes;
  final bool hasMorePages;
  final String nextPageUrl;
  final bool hasPrevPage;
  final String prevPageUrl;
  final int currentPage;
  final bool isEmptyPage;
  final bool isErrorPage;
  final String parentId; // ID of the parent comment if this is a reply
  final List<Comment> replies; // List of replies to this comment

  // Fields for additional replies loading
  final int remainingReplies; // Number of remaining replies to load
  final String lastReplyId; // ID of the last reply in the current list
  final bool hasMoreReplies; // Whether there are more replies to load

  Comment({
    required this.id,
    required this.user,
    required this.content,
    required this.timestamp,
    this.rawTimestamp = '',
    this.likes = '',
    this.hasMorePages = false,
    this.nextPageUrl = '',
    this.hasPrevPage = false,
    this.prevPageUrl = '',
    this.currentPage = 1,
    this.isEmptyPage = false,
    this.isErrorPage = false,
    this.parentId = '',
    this.replies = const [],
    this.remainingReplies = 0,
    this.lastReplyId = '',
    this.hasMoreReplies = false,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    // Handle the case where replies might be a different type (Map instead of List)
    List<dynamic> repliesJson = [];
    if (json['replies'] != null) {
      if (json['replies'] is List) {
        repliesJson = json['replies'] as List;
      } else if (json['replies'] is Map) {
        // If replies is a Map, convert it to a List
        repliesJson =
            (json['replies'] as Map<dynamic, dynamic>).values.toList();
      }
    }

    final replies =
        repliesJson.isNotEmpty
            ? repliesJson
                .map(
                  (reply) => Comment.fromJson(
                    reply is Map<String, dynamic>
                        ? reply
                        : reply is Map
                        ? Map<String, dynamic>.from(reply)
                        : {},
                  ),
                )
                .toList()
            : <Comment>[];

    // Get the ID of the last reply if there are any replies
    String lastReplyId = '';
    if (replies.isNotEmpty) {
      lastReplyId = replies.last.id;
    }

    return Comment(
      id: json['id']?.toString() ?? '',
      user: CommentUser.fromJson(json['user'] ?? {}),
      content: json['content']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? '',
      rawTimestamp: json['rawTimestamp']?.toString() ?? '',
      likes: json['likes']?.toString() ?? '',
      hasMorePages: json['hasMorePages'] == true,
      nextPageUrl: json['nextPageUrl']?.toString() ?? '',
      hasPrevPage: json['hasPrevPage'] == true,
      prevPageUrl: json['prevPageUrl']?.toString() ?? '',
      currentPage:
          json['currentPage'] is int
              ? json['currentPage']
              : (int.tryParse(json['currentPage']?.toString() ?? '1') ?? 1),
      isEmptyPage: json['isEmptyPage'] == true,
      isErrorPage: json['isErrorPage'] == true,
      parentId: json['parentId']?.toString() ?? '',
      replies: replies,
      remainingReplies:
          json['remainingReplies'] is int
              ? json['remainingReplies']
              : (int.tryParse(json['remainingReplies']?.toString() ?? '0') ??
                  0),
      lastReplyId: lastReplyId,
      hasMoreReplies:
          json['hasMoreReplies'] == true ||
          (json['remainingReplies'] != null &&
              (int.tryParse(json['remainingReplies']?.toString() ?? '0') ?? 0) >
                  0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user.toJson(),
      'content': content,
      'timestamp': timestamp,
      'rawTimestamp': rawTimestamp,
      'likes': likes,
      'hasMorePages': hasMorePages,
      'nextPageUrl': nextPageUrl,
      'hasPrevPage': hasPrevPage,
      'prevPageUrl': prevPageUrl,
      'currentPage': currentPage,
      'isEmptyPage': isEmptyPage,
      'isErrorPage': isErrorPage,
      'parentId': parentId,
      'replies': replies.map((reply) => reply.toJson()).toList(),
      'remainingReplies': remainingReplies,
      'lastReplyId': lastReplyId,
      'hasMoreReplies': hasMoreReplies,
    };
  }

  // Helper method to check if this comment has any replies
  bool get hasReplies => replies.isNotEmpty;

  // Helper to get the complete thread (this comment + all its replies)
  List<Comment> get thread => [this, ...replies];

  // Create a copy of this comment with updated replies
  Comment copyWithAdditionalReplies(List<Comment> newReplies, int remaining) {
    final List<Comment> updatedReplies = [...replies, ...newReplies];
    return Comment(
      id: id,
      user: user,
      content: content,
      timestamp: timestamp,
      rawTimestamp: rawTimestamp,
      likes: likes,
      hasMorePages: hasMorePages,
      nextPageUrl: nextPageUrl,
      hasPrevPage: hasPrevPage,
      prevPageUrl: prevPageUrl,
      currentPage: currentPage,
      isEmptyPage: isEmptyPage,
      isErrorPage: isErrorPage,
      parentId: parentId,
      replies: updatedReplies,
      remainingReplies: remaining,
      lastReplyId: updatedReplies.isNotEmpty ? updatedReplies.last.id : '',
      hasMoreReplies: remaining > 0,
    );
  }
}

class CommentUser {
  final String name;
  final String image;
  final String url;
  final List<String> badges;

  CommentUser({
    required this.name,
    required this.image,
    required this.url,
    this.badges = const [],
  });

  factory CommentUser.fromJson(Map<String, dynamic> json) {
    // Handle case where badges might be a different type
    List<String> badgesList = [];
    if (json['badges'] != null) {
      if (json['badges'] is List) {
        badgesList =
            (json['badges'] as List)
                .map((badge) => badge?.toString() ?? '')
                .where((badge) => badge.isNotEmpty)
                .toList();
      } else if (json['badges'] is String) {
        // If it's a single string, add it as a single badge
        final badge = json['badges'].toString().trim();
        if (badge.isNotEmpty) {
          badgesList = [badge];
        }
      }
    }

    return CommentUser(
      name: json['name']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      badges: badgesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'image': image, 'url': url, 'badges': badges};
  }
}
