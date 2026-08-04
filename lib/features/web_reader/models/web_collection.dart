class WebCollectionLink {
  final String id;
  final String title;
  final String url;
  final String note;

  const WebCollectionLink({
    required this.id,
    required this.title,
    required this.url,
    this.note = '',
  });

  String get domain {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  WebCollectionLink copyWith({
    String? id,
    String? title,
    String? url,
    String? note,
  }) {
    return WebCollectionLink(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'note': note,
      };

  factory WebCollectionLink.fromJson(Map<String, dynamic> json) {
    return WebCollectionLink(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
    );
  }
}

class WebCollection {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final bool isPreset;
  final List<WebCollectionLink> links;

  const WebCollection({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.isPreset,
    required this.links,
  });

  int get linkCount => links.length;

  WebCollection copyWith({
    String? id,
    String? title,
    String? description,
    String? emoji,
    bool? isPreset,
    List<WebCollectionLink>? links,
  }) {
    return WebCollection(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      isPreset: isPreset ?? this.isPreset,
      links: links ?? this.links,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'emoji': emoji,
        'isPreset': isPreset,
        'links': links.map((e) => e.toJson()).toList(),
      };

  factory WebCollection.fromJson(Map<String, dynamic> json) {
    final rawLinks = json['links'];
    return WebCollection(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      emoji: ((json['emoji'] ?? '📁').toString()).trim().isEmpty
          ? '📁'
          : (json['emoji'] ?? '📁').toString(),
      isPreset: json['isPreset'] == true,
      links: rawLinks is List
          ? rawLinks
              .whereType<Map>()
              .map((e) => WebCollectionLink.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}
