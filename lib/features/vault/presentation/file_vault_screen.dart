import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:dio/dio.dart';
import '../services/file_service.dart';
import '../../../core/widgets/persistent_header.dart';
import '../../auth/controllers/auth_controller.dart';

/*
1 : FileVaultScreen is now exclusively for file storage (The Vault).
*/
class FileVaultScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const FileVaultScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<FileVaultScreen> createState() => _FileVaultScreenState();
}

class _FileVaultScreenState extends ConsumerState<FileVaultScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
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

      String errorMsg = e.toString().replaceAll('Exception: ', '');
      if (e is DioException) {
        final detail = e.response?.data?['detail'];
        errorMsg = detail != null
            ? detail.toString()
            : e.message ?? 'Network error occurred';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file: $errorMsg'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: Column(
        children: [
          if (widget.isEmbedded)
            PersistentHeader(
              title: 'The Vault',
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white24),
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                ),
              ],
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(filesProvider);
              },
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: widget.isEmbedded
                      ? 0
                      : 20, // Add top padding if no AppBar
                  bottom: widget.isEmbedded ? 120 : 20, // Space for Dock
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
          ),
        ],
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
          error: (e, _) => Center(
            child: Text(
              'Error: $e',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      ],
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
