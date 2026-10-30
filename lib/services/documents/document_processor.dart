import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../core/errors/app_error.dart';

class ExtractedPage {
  final int pageNumber;
  final String text;

  const ExtractedPage({
    required this.pageNumber,
    required this.text,
  });
}

class ExtractedDocument {
  final String fileName;
  final int totalPages;
  final List<ExtractedPage> pages;

  const ExtractedDocument({
    required this.fileName,
    required this.totalPages,
    required this.pages,
  });
}

class DocumentProcessor {
  /// Extracts text from PDF or TXT files per page
  Future<ExtractedDocument> extractText({
    required String filePath,
    required String fileName,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw IngestionError('File does not exist at path: $filePath');
    }

    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return await _extractPdf(file, fileName);
    } else if (lower.endsWith('.txt')) {
      return await _extractTxt(file, fileName);
    } else {
      throw IngestionError('Unsupported file format: $fileName. LocalRAG supports PDF and TXT.');
    }
  }

  Future<ExtractedDocument> _extractPdf(File file, String fileName) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const IngestionError('PDF file is empty.');
    }

    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: bytes);
      final int pageCount = document.pages.count;
      if (pageCount == 0) {
        throw const IngestionError('PDF contains no pages.');
      }

      final extractor = PdfTextExtractor(document);
      final List<ExtractedPage> pages = [];
      int totalExtractedLength = 0;

      for (int i = 0; i < pageCount; i++) {
        final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
        final cleanedText = _cleanText(pageText);
        if (cleanedText.isNotEmpty) {
          totalExtractedLength += cleanedText.length;
          pages.add(ExtractedPage(pageNumber: i + 1, text: cleanedText));
        }
      }

      if (totalExtractedLength == 0) {
        throw const IngestionError(
          'Could not extract text from this PDF.\n\nReason: PDF may contain scanned images without embedded text.',
        );
      }

      return ExtractedDocument(
        fileName: fileName,
        totalPages: pageCount,
        pages: pages,
      );
    } catch (e) {
      if (e is AppError) rethrow;
      throw IngestionError('Failed to parse PDF "$fileName": $e');
    } finally {
      document?.dispose();
    }
  }

  Future<ExtractedDocument> _extractTxt(File file, String fileName) async {
    try {
      final rawText = await file.readAsString();
      final cleanedText = _cleanText(rawText);
      if (cleanedText.isEmpty) {
        throw const IngestionError('Text file is empty.');
      }

      return ExtractedDocument(
        fileName: fileName,
        totalPages: 1,
        pages: [
          ExtractedPage(pageNumber: 1, text: cleanedText),
        ],
      );
    } catch (e) {
      if (e is AppError) rethrow;
      throw IngestionError('Failed to read TXT "$fileName": $e');
    }
  }

  String _cleanText(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
