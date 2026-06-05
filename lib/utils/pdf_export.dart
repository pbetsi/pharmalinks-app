// Version mobile (Android/iOS)
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> exportPdfMobile(List<int> pdfBytes, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final filePath = '${directory.path}/$fileName';
  
  final file = File(filePath);
  await file.writeAsBytes(pdfBytes);
  
  await OpenFile.open(filePath);
}