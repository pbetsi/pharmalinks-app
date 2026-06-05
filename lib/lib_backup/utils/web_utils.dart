// Pour le web
import 'dart:html' as html;

void openPdfInNewTab(String pdfBytes) {
  html.window.open(
    'data:application/pdf;base64,$pdfBytes',
    'PDF',
  );
}