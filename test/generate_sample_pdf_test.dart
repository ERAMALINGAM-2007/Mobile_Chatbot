import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('Generate sample PDF and TXT for device testing', () async {
    final document = PdfDocument();
    
    // Page 1
    final page1 = document.pages.add();
    page1.graphics.drawString(
      'Computer Networks & Operating Systems Notes.\n\nA Process Control Block (PCB) contains process state, program counter, CPU registers, memory management information, and CPU scheduling information.',
      PdfStandardFont(PdfFontFamily.helvetica, 12),
    );

    // Page 2
    final page2 = document.pages.add();
    page2.graphics.drawString(
      'Deadlock Handling in Operating Systems.\n\nA deadlock occurs when a set of processes are blocked because each process is holding a resource and waiting for another resource acquired by some other process.\nBankers Algorithm is used for deadlock avoidance by verifying safe states.',
      PdfStandardFont(PdfFontFamily.helvetica, 12),
    );

    // Page 3
    final page3 = document.pages.add();
    page3.graphics.drawString(
      'Transmission Control Protocol (TCP).\n\nTCP provides reliable, ordered, and error-checked delivery of a stream of bytes between applications.\nTCP uses a three-way handshake (SYN, SYN-ACK, ACK) to establish a connection before data transfer begins.',
      PdfStandardFont(PdfFontFamily.helvetica, 12),
    );

    final bytes = await document.save();
    document.dispose();

    await File('GATE_Sample_Notes.pdf').writeAsBytes(bytes);
    
    // Also create a sample TXT
    await File('GATE_Short_Notes.txt').writeAsString(
      'Operating Systems Summary.\nVirtual memory provides an illusion of a very large memory. Paging maps virtual addresses to physical page frames.'
    );
  });
}
