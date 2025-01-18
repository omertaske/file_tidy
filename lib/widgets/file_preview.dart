import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class FilePreview extends StatelessWidget {
  final FileSystemEntity file;
  
  const FilePreview({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    if (file is! File) return const SizedBox();
    
    final extension = path.extension(file.path).toLowerCase();
    
    switch (extension) {
      case '.jpg':
      case '.jpeg':
      case '.png':
        return Image.file(
          file as File,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
        );
      case '.txt':
      case '.md':
      case '.json':
      case '.yaml':
      case '.dart':
        return FutureBuilder<String>(
          future: (file as File).readAsString(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const CircularProgressIndicator();
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(snapshot.data!),
              ),
            );
          },
        );
      case '.pdf':
        return const Center(child: Text('PDF Önizleme'));
      default:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.insert_drive_file, size: 64),
            const SizedBox(height: 16),
            Text('${extension.toUpperCase()} dosyası önizlenemiyor'),
          ],
        );
    }
  }
} 