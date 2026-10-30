class ConversationModel {
  final int? id;
  final int chatbotId;
  final String title;
  final int createdAt;
  final int updatedAt;

  const ConversationModel({
    this.id,
    required this.chatbotId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  ConversationModel copyWith({
    int? id,
    int? chatbotId,
    String? title,
    int? createdAt,
    int? updatedAt,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      chatbotId: chatbotId ?? this.chatbotId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'chatbot_id': chatbotId,
      'title': title,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory ConversationModel.fromMap(Map<String, dynamic> map) {
    return ConversationModel(
      id: map['id'] as int?,
      chatbotId: map['chatbot_id'] as int,
      title: map['title'] as String,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }
}
