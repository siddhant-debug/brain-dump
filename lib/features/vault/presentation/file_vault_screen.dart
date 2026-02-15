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
  final bool isEmbedded;
  const FileVaultScreen({super.key, this.isEmbedded = false});

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
    final notesState = ref.watch(notesProvider);
    final filesState = ref.watch(filesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D), // Match minimal theme
      appBar: widget.isEmbedded
          ? null // No AppBar if embedded
          : AppBar(
              title: const Text(
                'The Vault',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.transparent,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notesProvider);
          ref.invalidate(filesProvider);
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: widget.isEmbedded ? 60 : 20, // Add top padding if no AppBar
            bottom: widget.isEmbedded ? 120 : 20, // Space for Dock
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isEmbedded) ...[
                const Text(
                  'Library',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
              ],

              _buildSectionHeader(
                'Thoughts',
                onAdd: () => _showAddNoteDialog(context, ref),
              ),
              const SizedBox(height: 10),
              _buildNotesList(notesState),

              const SizedBox(height: 30),

              _buildSectionHeader(
                'Documents',
                onAdd: () => _pickAndUploadFile(),
              ),
              const SizedBox(height: 10),
              _buildFilesList(filesState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onAdd}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (onAdd != null)
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
            onPressed: onAdd,
          ),
      ],
    );
  }

  Future<void> _showAddNoteDialog(BuildContext context, WidgetRef ref) async {
    final TextEditingController noteController = TextEditingController();
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            'Add New Thought',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: noteController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Type your thought here...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            maxLines: 5,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.blueAccent),
              ),
              onPressed: () async {
                if (noteController.text.isNotEmpty) {
                  try {
                    await ref
                        .read(noteServiceProvider)
                        .saveNote(noteController.text);
                    ref.invalidate(notesProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Thought saved successfully'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save thought: $e')),
                      );
                    }
                  }
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilesList(AsyncValue<List<Map<String, dynamic>>> filesState) {
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
        // Removed Expanded
        filesState.when(
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
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.white24,
                          ),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF1E1E1E),
                                title: const Text(
                                  'Delete File?',
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: Text(
                                  'Permantly delete "${file['filename']}"?',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              try {
                                await ref
                                    .read(fileServiceProvider)
                                    .deleteFile(file['id']);
                                ref.invalidate(filesProvider);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to delete: $e'),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white24),
                      ],
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
        )
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
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            final noteId = note['id']; // Important: Use unique ID for Key

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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white24,
                      ),
                      onPressed: () async {
                        // No confirmation for notes (quick delete), or maybe minimal one?
                        // Let's add confirmation to be safe and consistent.
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1E1E1E),
                            title: const Text(
                              'Delete Thought?',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: const Text(
                              'This cannot be undone.',
                              style: TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await ref
                              .read(noteServiceProvider)
                              .deleteNote(noteId);
                          ref.invalidate(notesProvider);
                        }
                      },
                    ),
                    Icon(
                      note['is_favorite'] == true
                          ? Icons.star
                          : Icons.star_border,
                      color: note['is_favorite'] == true
                          ? Colors.yellowAccent
                          : Colors.white24,
                    ),
                  ],
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
