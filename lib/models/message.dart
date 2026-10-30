import 'dart:convert';

class MessageModel {
  final int? id;
  final int conversationId;
  final String role; // 'system', 'user', 'assistant'
  final String content;
  final List<MessageCitation> citations;
  final int createdAt;

  const MessageModel({
    this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.citations = const [],
    required this.createdAt,
  });

  MessageModel copyWith({
    int? id,
    int? conversationId,
    String? role,
    String? content,
    List<MessageCitation>? citations,
    int? createdAt,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      citations: citations ?? this.citations,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'conversation_id': conversationId,
      'role': role,
      'content': content,
      'sources_json': jsonEncode(citations.map((c) => c.toMap()).toList()),
      'created_at': createdAt,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    List<MessageCitation> parsedCitations = [];
    if (map['sources_json'] != null && (map['sources_json'] as String).isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(map['sources_json'] as String);
        parsedCitations = decoded
            .map((item) => MessageCitation.fromMap(item as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    return MessageModel(
      id: map['id'] as int?,
      conversationId: map['conversation_id'] as int,
      role: map['role'] as String,
      content: map['content'] as String,
      citations: parsedCitations,
      createdAt: map['created_at'] as int,
    );
  }
}

class MessageCitation {
  final String fileName;
  final int pageNumber;
  final String excerpt;
  final double? score;

  const MessageCitation({
    required this.fileName,
    required this.pageNumber,
    required this.excerpt,
    this.score,
  });

  Map<String, dynamic> toMap() {
    return {
      'file_name': fileName,
      'page_number': pageNumber,
      'excerpt': excerpt,
      if (score != null) 'score': score,
    };
  }

  factory MessageCitation.fromMap(Map<String, dynamic> map) {
    return MessageCitation(
      fileName: (map['file_name'] as String?) ?? 'Document',
      pageNumber: (map['page_number'] as int?) ?? 1,
      excerpt: (map['excerpt'] as String?) ?? '',
      score: (map['score'] as num?)?.toDouble(),
    );
  }
}
