import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class AppDatabase {
  static const String _dbName = 'local_rag.db';
  static const int _dbVersion = 1;

  static Database? _database;

  static Future<Database> get instance async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        // Enforce Foreign Key constraints
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await _createTables(db);
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    // 1. Chatbots table
    await db.execute('''
      CREATE TABLE chatbots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    // 2. Documents table
    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chatbot_id INTEGER NOT NULL,
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        page_count INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at INTEGER NOT NULL,
        FOREIGN KEY (chatbot_id) REFERENCES chatbots (id) ON DELETE CASCADE
      );
    ''');

    // 3. Chunks table
    await db.execute('''
      CREATE TABLE chunks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        chatbot_id INTEGER NOT NULL,
        chunk_index INTEGER NOT NULL,
        text TEXT NOT NULL,
        page_number INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE,
        FOREIGN KEY (chatbot_id) REFERENCES chatbots (id) ON DELETE CASCADE
      );
    ''');

    // 4. Vector Embeddings table (Float32 blob storage)
    await db.execute('''
      CREATE TABLE embeddings (
        chunk_id INTEGER PRIMARY KEY,
        chatbot_id INTEGER NOT NULL,
        embedding BLOB NOT NULL,
        FOREIGN KEY (chunk_id) REFERENCES chunks (id) ON DELETE CASCADE
      );
    ''');

    // 5. Conversations table
    await db.execute('''
      CREATE TABLE conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chatbot_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (chatbot_id) REFERENCES chatbots (id) ON DELETE CASCADE
      );
    ''');

    // 6. Messages table
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id INTEGER NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        sources_json TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE
      );
    ''');

    // 7. Indexes for performance and strict chatbot isolation
    await db.execute('CREATE INDEX idx_docs_chatbot ON documents(chatbot_id);');
    await db.execute('CREATE INDEX idx_chunks_chatbot ON chunks(chatbot_id);');
    await db.execute('CREATE INDEX idx_chunks_doc ON chunks(document_id);');
    await db.execute('CREATE INDEX idx_embed_chatbot ON embeddings(chatbot_id);');
    await db.execute('CREATE INDEX idx_conv_chatbot ON conversations(chatbot_id);');
    await db.execute('CREATE INDEX idx_msg_conv ON messages(conversation_id);');
  }

  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
