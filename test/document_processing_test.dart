import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:local_rag/services/documents/document_processor.dart';
import 'package:local_rag/services/documents/chunking_service.dart';
import 'package:local_rag/core/errors/app_error.dart';

void main() {
  late Directory tempDir;
  late File samplePdfFile;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('rag_doc_test_');

    // Generate a valid 2-page PDF dynamically
    final document = PdfDocument();
    
    // Page 1
    final page1 = document.pages.add();
    page1.graphics.drawString(
      'Operating Systems Lecture 1.\nA process is a program in execution.\nProcesses require CPU and memory.',
      PdfStandardFont(PdfFontFamily.helvetica, 12),
    );

    // Page 2
    final page2 = document.pages.add();
    page2.graphics.drawString(
      'Operating Systems Lecture 2.\nDeadlock occurs when processes wait indefinitely for resources held by each other.\nThe four conditions are: Mutual exclusion, Hold and wait, No preemption, and Circular wait.',
      PdfStandardFont(PdfFontFamily.helvetica, 12),
    );

    final bytes = await document.save();
    document.dispose();

    samplePdfFile = File('${tempDir.path}/GATE_OS.pdf');
    await samplePdfFile.writeAsBytes(bytes);
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Milestone 6: PDF Extraction extracts known text and preserves page numbers', () async {
    final processor = DocumentProcessor();
    final extracted = await processor.extractText(
      filePath: samplePdfFile.path,
      fileName: 'GATE_OS.pdf',
    );

    expect(extracted.totalPages, equals(2));
    expect(extracted.pages.length, equals(2));

    // Page 1 assertions
    expect(extracted.pages[0].pageNumber, equals(1));
    expect(extracted.pages[0].text, contains('A process is a program in execution'));

    // Page 2 assertions
    expect(extracted.pages[1].pageNumber, equals(2));
    expect(extracted.pages[1].text, contains('Deadlock occurs when processes wait indefinitely'));
    expect(extracted.pages[1].text, contains('Circular wait'));
  });

  test('Milestone 7: Chunking preserves document ID, chatbot ID, page numbers, and indices', () {
    final chunker = const ChunkingService(chunkSize: 100, chunkOverlap: 20);
    
    final extractedDoc = ExtractedDocument(
      fileName: 'GATE_OS.pdf',
      totalPages: 2,
      pages: [
        const ExtractedPage(
          pageNumber: 1,
          text: 'Process in execution. CPU and memory required for running tasks smoothly.',
        ),
        const ExtractedPage(
          pageNumber: 2,
          text: 'Deadlock happens when circular wait conditions are met between threads.',
        ),
      ],
    );

    final chunks = chunker.chunkDocument(
      documentId: 101,
      chatbotId: 1,
      document: extractedDoc,
    );

    expect(chunks.isNotEmpty, isTrue);
    
    // Check that every chunk preserves the metadata
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      expect(chunk.documentId, equals(101));
      expect(chunk.chatbotId, equals(1));
      expect(chunk.chunkIndex, equals(i));
      expect(chunk.sourceFileName, equals('GATE_OS.pdf'));
      expect(chunk.text.isNotEmpty, isTrue);
    }

    // Verify page numbers are preserved accurately
    expect(chunks.any((c) => c.pageNumber == 1), isTrue);
    expect(chunks.any((c) => c.pageNumber == 2), isTrue);
  });

  test('PDF Error Handling: Empty PDF throws descriptive IngestionError', () async {
    final emptyFile = File('${tempDir.path}/empty.pdf');
    await emptyFile.writeAsBytes([]);

    final processor = DocumentProcessor();
    expect(
      () => processor.extractText(filePath: emptyFile.path, fileName: 'empty.pdf'),
      throwsA(isA<IngestionError>()),
    );
  });
}
