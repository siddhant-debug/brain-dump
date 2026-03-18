import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:dio/dio.dart';
import '../services/file_service.dart';
import '../../../core/widgets/persistent_header.dart';
import '../../auth/controllers/auth_controller.dart';
import '../widgets/secure_pdf_viewer.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/upload_controller.dart';
import '../widgets/typewriter_text.dart';

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

  String getLoadingMessage(double progress) {
    if (progress < 0.3) return "Opening the neural gates...";
    if (progress < 0.6) return "Teaching the AI your secrets...";
    if (progress < 0.9) return "Connecting neural pathways...";
    return "The AI is currently pondering your document...";
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'txt', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final success = await ref.read(uploadControllerProvider.notifier).uploadFile(file);
      
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully')),
        );
      } else {
        final error = ref.read(uploadControllerProvider).error;
        if (error != null && error != 'Upload cancelled') {
          final colors = ref.read(themeProvider).colors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: $error'),
              backgroundColor: colors.red,
            ),
          );
        }
      }
    }
  }

  void _openFile(Map<String, dynamic> file) async {
    final fileId = file['id'];
    final filename = file['filename'];
    final type = file['file_type'];

    if (filename.toString().endsWith('.pdf')) {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                SecurePdfViewer(fileId: fileId, filename: filename),
          ),
        );
      }
      return;
    }

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
      final colors = ref.read(themeProvider).colors;

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
          backgroundColor: colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeProvider).colors;
    final filesState = ref.watch(filesProvider);
    final uploadState = ref.watch(uploadControllerProvider);

    return Scaffold(
      backgroundColor: colors.bgTop,
      body: SafeArea(
        child: Column(
          children: [
            PersistentHeader(
              title: 'The Vault',
              actions: [
                IconButton(
                  icon: Icon(Icons.logout_rounded, color: colors.textDim.withValues(alpha: 0.3)),
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
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 120,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        'Documents',
                        colors,
                        onAdd: () => _pickAndUploadFile(),
                        isUploading: uploadState.isUploading,
                      ),
                      _buildUploadProgress(uploadState, colors),
                      const SizedBox(height: 10),
                      _buildFilesList(filesState, colors),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, CircadianColors colors, {VoidCallback? onAdd, bool isUploading = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title.toUpperCase(),
          style: AppTextStyles.label(colors.textDim).copyWith(
            letterSpacing: 1.2,
          ),
        ),
        if (onAdd != null)
          IconButton(
            icon: isUploading 
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent)) 
                  : Icon(Icons.add_circle_outline, color: colors.textDim, size: 20),
            onPressed: isUploading ? null : onAdd,
          ),
      ],
    );
  }

  Widget _buildUploadProgress(UploadState state, CircadianColors colors) {
    if (!state.isUploading) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.accent.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: TypewriterText(
                  text: getLoadingMessage(state.progress),
                  style: AppTextStyles.body(colors.text).copyWith(fontStyle: FontStyle.italic),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: colors.textDim, size: 20),
                onPressed: () {
                  ref.read(uploadControllerProvider.notifier).cancelUpload();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: state.progress > 0 ? state.progress : null,
            backgroundColor: colors.surfaceBorder,
            valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(state.progress * 100).toInt()}%',
              style: AppTextStyles.micro(colors.textDim),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFilesList(AsyncValue<List<Map<String, dynamic>>> filesState, CircadianColors colors) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: TextField(
            controller: _searchController,
            onChanged: (val) =>
                setState(() => _searchQuery = val.toLowerCase()),
            style: AppTextStyles.body(colors.text),
            cursorColor: colors.accent,
            decoration: InputDecoration(
              hintText: 'Search vault...',
              hintStyle: AppTextStyles.body(colors.textDim.withValues(alpha: 0.5)),
              prefixIcon: Icon(Icons.search, color: colors.textDim, size: 18),
              filled: true,
              fillColor: colors.surfaceLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide(color: colors.surfaceBorder, width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide(color: colors.surfaceBorder, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide(color: colors.accent.withValues(alpha: 0.5)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
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
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No files found.',
                    style: TextStyle(color: colors.textDim),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredFiles.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final file = filteredFiles[index];
                return _VaultFileItem(
                  file: file,
                  colors: colors,
                  onTap: () => _openFile(file),
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: colors.bgTop,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          side: BorderSide(color: colors.surfaceBorder, width: 0.5),
                        ),
                        title: Text(
                          'Delete File?',
                          style: AppTextStyles.bodyMed(colors.text),
                        ),
                        content: Text(
                          'Permanently delete "${file['filename']}"?',
                          style: AppTextStyles.body(colors.textDim),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(
                              'Cancel',
                              style: AppTextStyles.label(colors.textDim),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(
                              'Delete',
                              style: AppTextStyles.label(colors.red),
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
                              backgroundColor: colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                );
              },
            );
          },
          loading: () => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(color: colors.textDim.withValues(alpha: 0.2)),
            ),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Error: $e',
                style: TextStyle(color: colors.red),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class FileViewer extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeProvider).colors;
    return Scaffold(
      backgroundColor: colors.bgTop,
      appBar: AppBar(
        title: Text(filename, style: AppTextStyles.bodyMed(colors.text)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildViewer(context, colors),
    );
  }

  Widget _buildViewer(BuildContext context, CircadianColors colors) {
    if (filename.endsWith('.md')) {
      return Markdown(
        data: content['content'] ?? '',
        styleSheet: MarkdownStyleSheet.fromTheme(
          Theme.of(context),
        ).copyWith(
          p: AppTextStyles.serifBody(colors.text).copyWith(fontSize: 16),
          h1: AppTextStyles.h1(colors.text),
          h2: AppTextStyles.h2(colors.text),
          h3: AppTextStyles.h3(colors.text),
          code: TextStyle(
            backgroundColor: colors.surfaceLow,
            color: colors.accent,
            fontFamily: 'monospace',
          ),
          codeblockDecoration: BoxDecoration(
            color: colors.surfaceLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.surfaceBorder, width: 0.5),
          ),
        ),
      );
    } else {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          content['content'] ?? '',
          style: AppTextStyles.serifBody(colors.text).copyWith(
            fontSize: 16,
            height: 1.6,
          ),
        ),
      );
    }
  }
}

class _VaultFileItem extends StatelessWidget {
  final Map<String, dynamic> file;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final CircadianColors colors;

  const _VaultFileItem({
    required this.file,
    required this.onTap,
    required this.onDelete,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final isPdf = file['filename'].toString().endsWith('.pdf');
    final date = file['created_at'] != null
        ? file['created_at'].toString().split('T')[0]
        : 'Unknown Date';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surfaceLow,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: colors.surfaceBorder.withValues(alpha: 0.1), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPdf
                    ? colors.red.withValues(alpha: 0.1)
                    : colors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.icon),
              ),
              child: Icon(
                isPdf ? Icons.picture_as_pdf_outlined : Icons.description_outlined,
                color: isPdf ? colors.red : colors.accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file['filename'] ?? 'Unknown',
                    style: AppTextStyles.bodyMed(colors.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Stored $date',
                    style: AppTextStyles.micro(colors.textDim),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: colors.textDim.withValues(alpha: 0.3), size: 18),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
