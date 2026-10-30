class ChunkModel {
  final int? id;
  final int documentId;
  final int chatbotId;
  final int chunkIndex;
  final String text;
  final int pageNumber;
  final int createdAt;

  // Optional retrieval metadata (populated during vector similarity queries)
  final String? sourceFileName;
  final double? similarityScore;

  const ChunkModel({
    this.id,
    required this.documentId,
    required this.chatbotId,
    required this.chunkIndex,
    required this.text,
    required this.pageNumber,
    required this.createdAt,
    this.sourceFileName,
    this.similarityScore,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'document_id': documentId,
      'chatbot_id': chatbotId,
      'chunk_index': chunkIndex,
      'text': text,
      'page_number': pageNumber,
      'created_at': createdAt,
    };
  }

  factory ChunkModel.fromMap(Map<String, dynamic> map) {
    return ChunkModel(
      id: map['id'] as int?,
      documentId: map['document_id'] as int,
      chatbotId: map['chatbot_id'] as int,
      chunkIndex: map['chunk_index'] as int,
      text: map['text'] as String,
      pageNumber: map['page_number'] as int,
      createdAt: map['created_at'] as int,
      sourceFileName: map['file_name'] as String?,
      similarityScore: (map['similarity'] as num?)?.toDouble(),
    );
  }
}
