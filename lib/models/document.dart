class DocumentModel {
  final int? id;
  final int chatbotId;
  final String fileName;
  final String filePath;
  final String mimeType;
  final int fileSize;
  final int pageCount;
  final String status; // 'pending', 'processing', 'completed', 'error'
  final int createdAt;

  const DocumentModel({
    this.id,
    required this.chatbotId,
    required this.fileName,
    required this.filePath,
    required this.mimeType,
    required this.fileSize,
    this.pageCount = 0,
    this.status = 'pending',
    required this.createdAt,
  });

  DocumentModel copyWith({
    int? id,
    int? chatbotId,
    String? fileName,
    String? filePath,
    String? mimeType,
    int? fileSize,
    int? pageCount,
    String? status,
    int? createdAt,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      chatbotId: chatbotId ?? this.chatbotId,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      pageCount: pageCount ?? this.pageCount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'chatbot_id': chatbotId,
      'file_name': fileName,
      'file_path': filePath,
      'mime_type': mimeType,
      'file_size': fileSize,
      'page_count': pageCount,
      'status': status,
      'created_at': createdAt,
    };
  }

  factory DocumentModel.fromMap(Map<String, dynamic> map) {
    return DocumentModel(
      id: map['id'] as int?,
      chatbotId: map['chatbot_id'] as int,
      fileName: map['file_name'] as String,
      filePath: map['file_path'] as String,
      mimeType: map['mime_type'] as String,
      fileSize: map['file_size'] as int,
      pageCount: (map['page_count'] as int?) ?? 0,
      status: (map['status'] as String?) ?? 'pending',
      createdAt: map['created_at'] as int,
    );
  }
}
