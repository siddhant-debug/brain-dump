import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/file_service.dart';
import '../../notes/services/note_service.dart';

/*
1 : FileVaultScreen is a unified repository for all stored data (files and thoughts).
It uses a TabController to switch between file storage and note history.
*/
class FileVaultScreen extends ConsumerStatefulWidget {
  const FileVaultScreen({super.key});

  @override
  ConsumerState<FileVaultScreen> createState() => _FileVaultScreenState();
}

class _FileVaultScreenState extends ConsumerState<FileVaultScreen>
    with SingleTickerProviderStateMixin {
  /*
  2 : _searchController and _searchQuery enable real-time filtering of the file list.
  _tabController manages the switch between 'Files' and 'Thoughts' tabs.
  */
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /*
  3 : _pickAndUploadFile triggers the device-native file picker.
  Once a file is selected, it's passed to FileService for multipart upload.
  It invalidates filesProvider on success to refresh the UI list.
  */
  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'txt', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      try {
        await ref.read(fileServiceProvider).uploadFile(file);
        if (!mounted) return;
        ref.invalidate(filesProvider); // Trigger a re-fetch of the file list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /*
  4 : _openFile fetches the raw content of a stored file and navigates to FileViewer.
  */
  void _openFile(Map<String, dynamic> file) async {
    final fileId = file['id'];
    final filename = file['filename'];
    final type = file['file_type'];

    try {
      final content = await ref
          .read(fileServiceProvider)
          .getFileContent(fileId);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                FileViewer(filename: filename, type: type, content: content),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    /*
    5 : filesState and notesState watch their respective providers 
    to reactive update when data is fetched or refreshed.
    */
    final filesState = ref.watch(filesProvider);
    final notesState = ref.watch(notesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text(
          'The Vault',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'Files'),
            Tab(text: 'Thoughts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 6 : Tab 1: Render the searchable file list
          _buildFileList(filesState),
          // 7 : Tab 2: Render the thoughts (saved notes) list
          _buildNotesList(notesState),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndUploadFile,
        backgroundColor: Colors.white,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildFileList(AsyncValue<List<Map<String, dynamic>>> filesState) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: (val) =>
                setState(() => _searchQuery = val.toLowerCase()),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search files...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: filesState.when(
            data: (files) {
              final filteredFiles = files
                  .where(
                    (f) => f['filename'].toString().toLowerCase().contains(
                      _searchQuery,
                    ),
                  )
                  .toList();

              if (filteredFiles.isEmpty) {
                return const Center(
                  child: Text(
                    'No files found.',
                    style: TextStyle(color: Colors.white38),
                  ),
                );
              }

              return ListView.builder(
                itemCount: filteredFiles.length,
                itemBuilder: (context, index) {
                  final file = filteredFiles[index];
                  final isPdf = file['filename'].toString().endsWith('.pdf');

                  return ListTile(
                    onTap: () => _openFile(file),
                    leading: Icon(
                      isPdf ? Icons.picture_as_pdf : Icons.description,
                      color: isPdf ? Colors.redAccent : Colors.blueAccent,
                    ),
                    title: Text(
                      file['filename'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Uploaded on ${file['created_at'].toString().split('T')[0]}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white24,
                    ),
                  );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: Colors.white24),
            ),
            error: (e, __) => Center(
              child: Text(
                'Error: $e',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesList(AsyncValue<List<dynamic>> notesState) {
    return notesState.when(
      data: (notes) {
        if (notes.isEmpty) {
          return const Center(
            child: Text(
              'No thoughts saved yet.',
              style: TextStyle(color: Colors.white38),
            ),
          );
        }

        return ListView.builder(
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: Text(
                  note['content'],
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'Saved on ${note['created_at'].toString().split('T')[0]}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                trailing: Icon(
                  note['is_favorite'] == true ? Icons.star : Icons.star_border,
                  color: note['is_favorite'] == true
                      ? Colors.yellowAccent
                      : Colors.white24,
                ),
              ),
            );
          },
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white24)),
      error: (e, __) => Center(
        child: Text(
          'Error: $e',
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }
}

class FileViewer extends StatelessWidget {
  final String filename;
  final String type;
  final dynamic content;

  const FileViewer({
    super.key,
    required this.filename,
    required this.type,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text(filename),
        backgroundColor: Colors.transparent,
      ),
      body: _buildViewer(context),
    );
  }

  Widget _buildViewer(BuildContext context) {
    if (filename.endsWith('.md')) {
      return Markdown(
        data: content['content'] ?? '',
        styleSheet: MarkdownStyleSheet.fromTheme(
          Theme.of(context),
        ).copyWith(p: const TextStyle(color: Colors.white70)),
      );
    } else if (filename.endsWith('.pdf')) {
      // Placeholder for PDF viewer - In real scenario use syncfusion_flutter_pdfviewer or similar
      return const Center(
        child: Text(
          'PDF Viewing requires device implementation',
          style: TextStyle(color: Colors.white),
        ),
      );
    } else {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          content['content'] ?? '',
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
  }
}
