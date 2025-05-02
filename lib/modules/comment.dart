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
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? '',
      user: CommentUser.fromJson(json['user'] ?? {}),
      content: json['content'] ?? '',
      timestamp: json['timestamp'] ?? '',
      rawTimestamp: json['rawTimestamp'] ?? '',
      likes: json['likes'] ?? '',
      hasMorePages: json['hasMorePages'] ?? false,
      nextPageUrl: json['nextPageUrl'] ?? '',
      hasPrevPage: json['hasPrevPage'] ?? false,
      prevPageUrl: json['prevPageUrl'] ?? '',
      currentPage: json['currentPage'] ?? 1,
      isEmptyPage: json['isEmptyPage'] ?? false,
      isErrorPage: json['isErrorPage'] ?? false,
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
    };
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
    return CommentUser(
      name: json['name'] ?? '',
      image: json['image'] ?? '',
      url: json['url'] ?? '',
      badges: List<String>.from(json['badges'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'image': image, 'url': url, 'badges': badges};
  }
}
