class Chatbot {
  final int? id;
  final String name;
  final String description;
  final int createdAt;
  final int updatedAt;

  // Transient counts for display on home screen
  final int documentCount;
  final int conversationCount;

  const Chatbot({
    this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    this.documentCount = 0,
    this.conversationCount = 0,
  });

  Chatbot copyWith({
    int? id,
    String? name,
    String? description,
    int? createdAt,
    int? updatedAt,
    int? documentCount,
    int? conversationCount,
  }) {
    return Chatbot(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      documentCount: documentCount ?? this.documentCount,
      conversationCount: conversationCount ?? this.conversationCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Chatbot.fromMap(Map<String, dynamic> map) {
    return Chatbot(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? '',
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      documentCount: (map['document_count'] as int?) ?? 0,
      conversationCount: (map['conversation_count'] as int?) ?? 0,
    );
  }
}
