import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StorageService {
  static Future<Directory> getAppDocumentsDirectoryForChatbot(int chatbotId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final chatbotDir = Directory(p.join(appDir.path, 'chatbots', chatbotId.toString(), 'documents'));
    if (!await chatbotDir.exists()) {
      await chatbotDir.create(recursive: true);
    }
    return chatbotDir;
  }

  static Future<Directory> getModelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(p.join(appDir.path, 'models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  static Future<File> copyDocumentToChatbotStorage({
    required int chatbotId,
    required String sourcePath,
    required String fileName,
  }) async {
    final targetDir = await getAppDocumentsDirectoryForChatbot(chatbotId);
    final targetPath = p.join(targetDir.path, fileName);
    final sourceFile = File(sourcePath);
    return await sourceFile.copy(targetPath);
  }

  static Future<void> deleteDocumentFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<void> deleteChatbotDirectory(int chatbotId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final chatbotDir = Directory(p.join(appDir.path, 'chatbots', chatbotId.toString()));
    if (await chatbotDir.exists()) {
      await chatbotDir.delete(recursive: true);
    }
  }
}
