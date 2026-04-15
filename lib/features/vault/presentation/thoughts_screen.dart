import 'package:brain_dump/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../notes/services/note_service.dart';
import '../../notes/models/note.dart';
import '../../../core/widgets/persistent_header.dart';
import '../../auth/controllers/auth_controller.dart';
import 'note_detail_screen.dart';
import '../../../../core/theme/theme_provider.dart';

class ThoughtsScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const ThoughtsScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<ThoughtsScreen> createState() => _ThoughtsScreenState();
}

class _ThoughtsScreenState extends ConsumerState<ThoughtsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAddNoteDialog(BuildContext context, WidgetRef ref, CircadianColors colors) async {
    final TextEditingController noteController = TextEditingController();
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: colors.bgTop,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: BorderSide(color: colors.surfaceBorder, width: 0.5),
          ),
          title: Text(
            'New Thought',
            style: AppTextStyles.bodyMed(colors.text),
          ),
          content: TextField(
            controller: noteController,
            autofocus: true,
            style: AppTextStyles.body(colors.text),
            maxLines: 5,
            decoration: InputDecoration(
              hintText: "What's on your mind?",
              hintStyle: AppTextStyles.body(colors.textDim.withValues(alpha: 0.5)),
              filled: true,
              fillColor: colors.surfaceLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: AppTextStyles.label(colors.textDim),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: Text(
                'Save',
                style: AppTextStyles.label(colors.accent),
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
                          content: Text('Thought saved'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e')),
                      );
                    }
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final colors = themeState.colors;
    final notesState = ref.watch(notesProvider);

    return Scaffold(
      backgroundColor: colors.bgTop,
      body: SafeArea(
        child: Column(
          children: [
            PersistentHeader(
              title: 'Thoughts',
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
                  ref.invalidate(notesProvider);
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 120, // Space for Dock
                  ),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        'Stream of Consciousness',
                        colors,
                        onAdd: () => _showAddNoteDialog(context, ref, colors),
                      ),
                      _buildNotesList(notesState, colors),
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

  Widget _buildSectionHeader(String title, CircadianColors colors, {VoidCallback? onAdd}) {
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
            icon: Icon(Icons.add_circle_outline, color: colors.textDim, size: 20),
            onPressed: onAdd,
          ),
      ],
    );
  }

  Widget _buildNotesList(AsyncValue<List<Note>> notesState, CircadianColors colors) {
    return notesState.when(
      data: (notes) {
        if (notes.isEmpty) {
          return Center(
            child: Text(
              'No thoughts saved yet.',
              style: TextStyle(color: colors.textFaint),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: notes.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final note = notes[index];
            return _ThoughtItem(
              note: note,
              colors: colors,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => NoteDetailScreen(note: note),
                  ),
                );
              },
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
                      'Delete Thought?',
                      style: AppTextStyles.bodyMed(colors.text),
                    ),
                    content: Text(
                      'Permanently delete this thought?',
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
                        .read(noteServiceProvider)
                        .deleteNote(note.id);
                    ref.invalidate(notesProvider);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e')),
                      );
                    }
                  }
                }
              },
            );
          },
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white24)),
      error: (e, _) => Center(
        child: Text(
          'Error: $e',
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }
}

class _ThoughtItem extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final CircadianColors colors;

  const _ThoughtItem({
    required this.note,
    required this.onTap,
    required this.onDelete,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final date = note.createdAt.toString().split(' ')[0];
    final sentiment = note.sentiment?.toLowerCase();
    final sentimentColor = sentiment == 'positive'
        ? colors.green
        : sentiment == 'negative'
            ? colors.red
            : colors.textDim;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.bgTop,
          border: Border(
            left: BorderSide(
              color: colors.accent,
              width: 1.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    note.content,
                    style: AppTextStyles.body(colors.text),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
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
            const SizedBox(height: 12),
            Row(
              children: [
                if (sentiment != null) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: sentimentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  date,
                  style: AppTextStyles.micro(colors.textDim),
                ),
                const Spacer(),
                if (note.isFavorite)
                  Icon(Icons.star, color: Colors.amber.withValues(alpha: 0.5), size: 14),
              ],
            ),
            if (note.categories.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: note.categories.map((cat) {
                  return Text(
                    '#${cat.toLowerCase()}',
                    style: AppTextStyles.micro(colors.accent.withValues(alpha: 0.7)),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
