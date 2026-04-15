import 'package:brain_dump/core/theme/app_theme.dart';
import 'package:brain_dump/core/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../notes/models/note.dart';

class NoteDetailScreen extends ConsumerStatefulWidget {
  final Note note;
  const NoteDetailScreen({super.key, required this.note});

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  Widget _buildSentimentBadge(String? sentiment, CircadianColors colors) {
    if (sentiment == null || sentiment.isEmpty) return const SizedBox.shrink();

    Color bgColor;
    IconData icon;
    Color textColor = colors.text;
    
    switch (sentiment.toLowerCase()) {
      case 'positive':
        bgColor = colors.greenBg;
        icon = Icons.sentiment_satisfied_alt;
        textColor = colors.green;
        break;
      case 'negative':
        bgColor = colors.redBg;
        icon = Icons.sentiment_dissatisfied;
        textColor = colors.red;
        break;
      case 'neutral':
      default:
        bgColor = colors.surfaceLow;
        icon = Icons.sentiment_neutral;
        textColor = colors.textDim;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.surfaceBorder, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Text(
            sentiment.toUpperCase(),
            style: AppTextStyles.label(textColor).copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> categories = widget.note.categories;
    final String? sentiment = widget.note.sentiment;
    final themeState = ref.watch(themeProvider);
    final colors = themeState.colors;

    return Scaffold(
      backgroundColor: colors.bgTop,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          widget.note.title ?? 'Thought Detail',
          style: AppTextStyles.h3(colors.text),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.text),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meta Row: Sentiment + Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSentimentBadge(sentiment, colors),
                  Text(
                    widget.note.createdAt.toString().split(' ')[0],
                    style: AppTextStyles.caption(colors.textFaint),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // The Thought Content
              Text(
                widget.note.content,
                style: AppTextStyles.h2(colors.text).copyWith(
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 40),

              // Categories Section
              if (categories.isNotEmpty) ...[
                Text(
                  'INSIGHTS',
                  style: AppTextStyles.label(colors.textFaint).copyWith(
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((cat) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.accentBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colors.accentBorder, width: 0.5),
                      ),
                      child: Text(
                        '#${cat.toLowerCase()}',
                        style: AppTextStyles.bodyMed(colors.accent).copyWith(
                          fontSize: 13,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
