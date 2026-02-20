import 'package:flutter/material.dart';

class NoteDetailScreen extends StatelessWidget {
  final Map<String, dynamic> note;
  const NoteDetailScreen({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thoughts Detail')),
      body: Container(
        padding: const EdgeInsets.all(16),

        child: Text(note['content'], style: TextStyle(fontSize: 18)),
        
      ),
    );
  }
}
