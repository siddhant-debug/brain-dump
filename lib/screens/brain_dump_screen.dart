import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../features/brain_dump/models/chat_message.dart';
import '../features/brain_dump/providers/brain_dump_provider.dart';
import '../features/auth/controllers/auth_controller.dart';
import '../core/widgets/persistent_header.dart';
import '../core/theme/app_theme.dart';
import '../features/analytics/services/analytics_service.dart';
import '../widgets/context_bar.dart';
import '../widgets/memory_sparks.dart';
import '../widgets/omni_bar.dart';
import '../core/theme/theme_provider.dart';
import '../features/reminders/controllers/smart_reminder_controller.dart';
import '../features/reminders/presentation/clarifying_prompt_sheet.dart';

/// Black Canvas - Minimalist Digital Notebook
/// Design: Pure black background, invisible list, hand-drawn spacing
class BrainDumpScreen extends ConsumerStatefulWidget {
  const BrainDumpScreen({super.key});

  @override
  ConsumerState<BrainDumpScreen> createState() => _BrainDumpScreenState();
}

class _BrainDumpScreenState extends ConsumerState<BrainDumpScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  int _previousMessageCount = 0;

  // Checkmark animation for saved notes
  bool _showCheckmark = false;
  late AnimationController _checkmarkController;

  // "Leaving mind" ghost text animation for journal mode
  String _ghostText = '';
  bool _showGhost = false;
  late AnimationController _ghostController;
  late Animation<double> _ghostOpacity;
  late Animation<Offset> _ghostSlide;

  @override
  void initState() {
    super.initState();

    _checkmarkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _ghostController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _ghostOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ghostController, curve: Curves.easeOut));
    _ghostSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.5),
    ).animate(CurvedAnimation(parent: _ghostController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _checkmarkController.dispose();
    _ghostController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          0.0, // Because the list is reversed, 0.0 is the bottom
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _onSubmitted() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final isChatMode = ref.read(brainDumpProvider).isChatMode;

    // In journal mode, capture text for ghost animation before clearing
    if (!isChatMode) {
      setState(() {
        _ghostText = text;
        _showGhost = true;
      });
    }

    // [Architect] Smart Reminder Routing Check
    final reminderKeywords = ['remind me', 'alarm', 'set a reminder', 'wake me up'];
    final lowerText = text.toLowerCase();
    final isReminderIntent = reminderKeywords.any((k) => lowerText.contains(k));

    if (isReminderIntent) {
      // Trigger Smart Reminder Flow
      await ref.read(smartReminderControllerProvider.notifier).parseInput(text);
      if (mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => const ClarifyingPromptSheet(),
        );
      }
      _controller.clear();
      return;
    }

    // [Architect] UX FIX: CLEAN INPUT EARLY
    _controller.clear();

    try {
      if (isChatMode) {
        // Chat mode: All input goes to AI as conversation
        await ref.read(brainDumpProvider.notifier).processInput(text);
      } else {
        // Journal mode: Save silently with "leaving mind" animation
        await ref.read(brainDumpProvider.notifier).saveNoteSilently(text);
        if (!mounted) return;

        // Play ghost float-away animation
        _ghostController.forward().then((_) {
          if (mounted) {
            setState(() => _showGhost = false);
            _ghostController.reset();
          }
        });

        // Show checkmark after ghost begins fading
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            setState(() => _showCheckmark = true);
            _checkmarkController.forward();

            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) {
                setState(() => _showCheckmark = false);
                _checkmarkController.reset();
              }
            });
          }
        });
      }

      // [Architect] Invalidate analytics providers to force a refresh
      ref.invalidate(consistencyProvider);
      ref.invalidate(themesProvider);
      ref.invalidate(loopsProvider);
      ref.invalidate(pipelineProvider);
    } catch (e) {
      debugPrint('[DEBUG] Error: $e');

      // Reset ghost state on error
      if (!isChatMode && mounted) {
        setState(() => _showGhost = false);
        _ghostController.reset();
      }
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
          content: Text('Error: $errorMsg'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brainDumpState = ref.watch(brainDumpProvider);
    final themeState = ref.watch(themeProvider);
    final colors = themeState.colors;

    // Auto-scroll when new messages arrive
    if (brainDumpState.messages.length > _previousMessageCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
      _previousMessageCount = brainDumpState.messages.length;
    }

    return Scaffold(
      backgroundColor: colors.bgTop, // Pure black
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: brainDumpState.isChatMode
            ? _buildChatLayer(brainDumpState, colors)
            : _buildJournalLayout(colors),
      ),
    );
  }

  /// Shared header — mode toggle + clear + logout
  Widget _buildHeader(bool isChatMode, CircadianColors colors) {
    return PersistentHeader(
      title: 'BrainDumps',
      actions: [
        // Clear History Button — only in chat mode
        if (isChatMode)
          IconButton(
            icon: Icon(
              Icons.cleaning_services_rounded,
              color: colors.textDim,
              size: 20,
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: colors.bgTop,
                  title: Text(
                    'Clear Screen?',
                    style: TextStyle(color: colors.text),
                  ),
                  content: Text(
                    'This will clear messages from your screen but keep them in your brain.',
                    style: TextStyle(color: colors.textDim),
                  ),
                  actions: [
                    TextButton(
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: colors.textDim),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    TextButton(
                      child: Text(
                        'Clear',
                        style: TextStyle(color: colors.red),
                      ),
                      onPressed: () {
                        ref
                            .read(brainDumpProvider.notifier)
                            .clearLocalHistory();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        // Logout Button
        IconButton(
          icon: Icon(Icons.logout_rounded, color: colors.textDim.withValues(alpha: 0.2)),
          onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
        ),
      ],
    );
  }

  /// Mode toggle
  Widget _buildModeToggle(bool isChatMode, CircadianColors colors) {
    return GestureDetector(
      onTap: () => ref.read(brainDumpProvider.notifier).toggleMode(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.surfaceBorder, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isChatMode ? Icons.chat_bubble_outline_rounded : Icons.edit_note_rounded,
              size: 14,
              color: colors.accent,
            ),
            const SizedBox(width: 6),
            Text(
              isChatMode ? 'Chat' : 'Journal',
              style: TextStyle(
                color: colors.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chat layout — messages list, input at bottom via Layer 2 overlay
  Widget _buildChatLayer(BrainDumpState state, CircadianColors colors) {
    return Column(
      children: [
        _buildHeader(state.isChatMode, colors),
        const ContextBar(),
        const SizedBox(height: 12),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(brainDumpProvider);
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              reverse:
                  true, // Forces layout from bottom, so it naturally anchors to bottom
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                top: 0,
                bottom: 24, // Space around messages
              ),
              itemCount: state.messages.length,
              itemBuilder: (context, index) {
                // Because reverse is true, index 0 is at the bottom. We want index 0 to be the NEWEST message.
                // state.messages[last] is newest. So reversed access:
                final msgIndex = state.messages.length - 1 - index;
                final msg = state.messages[msgIndex];
                // To maintain normal spacing (last item has 0 bottom padding), check if it's the newest
                final isLast = msgIndex == state.messages.length - 1;
  
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: isLast ? 0 : 40,
                  ), // 40px spacing between Q&A pairs
                  child: _MinimalMessageRow(msg: msg, colors: colors),
                );
              },
            ),
          ),
        ),
        OmniBar(
          controller: _controller,
          onSubmitted: _onSubmitted,
          isProcessing: state.isProcessing,
          hintText: "ask anything...",
          leading: _buildModeToggle(true, colors),
        ),
      ],
    );
  }

  /// Journal layout — input at top with green text, ghost animation
  Widget _buildJournalLayout(CircadianColors colors) {

    return Column(
      children: [
        _buildHeader(false, colors),
        // Input area at top — full remaining space
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(brainDumpProvider);
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Stack(
                children: [
                  // Ghost text — floats up and fades after save
                  if (_showGhost)
                    SlideTransition(
                      position: _ghostSlide,
                      child: FadeTransition(
                        opacity: _ghostOpacity,
                        child: Text(
                          _ghostText,
                          style: TextStyle(
                            color: colors.textDim,
                            fontSize: 18,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  // Animated hint at input position
                  ValueListenableBuilder(
                    valueListenable: _controller,
                    builder: (context, value, child) {
                      return value.text.isEmpty
                          ? _AnimatedHintText(text: 'dump your thoughts...', colors: colors)
                          : const SizedBox.shrink();
                    },
                  ),
                  // Actual input — green text
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: null,
                    minLines: 10, // Added minLines to make touch area larger for refresh
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _onSubmitted(),
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 16,
                      height: 1.5,
                    ),
                    cursorColor: colors.accent,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Bottom Toggle for Journal Mode
        Padding(
          padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildModeToggle(false, colors),
              const Spacer(),
              if (_showCheckmark)
                FadeTransition(
                  opacity: _checkmarkController,
                  child: Icon(
                    Icons.check_circle_outline,
                    color: colors.accent,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// [Architect] NEW COMPONENT: Visible Thinking Indicator
// Replaces the invisible/subtle text with a clear animation
class ThinkingIndicator extends StatefulWidget {
  final CircadianColors colors;
  const ThinkingIndicator({super.key, required this.colors});

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator> {
  late Timer _timer;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _dotCount = (_dotCount + 1) % 4;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dotCount;
    return Text(
      'thinking$dots',
      style: TextStyle(
        color: widget.colors.textDim,
        fontSize: 14,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

/// Minimal Message Row - Restyled with Glassmorphism and MemorySparks
class _MinimalMessageRow extends StatelessWidget {
  final ChatMessage msg;
  final CircadianColors colors;

  const _MinimalMessageRow({required this.msg, required this.colors});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.sender == MessageSender.user;

    return Row(
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI AVATAR (Left)
        if (!isUser) ...[
          CircleAvatar(
            radius: 16,
            backgroundColor: colors.text.withValues(alpha: 0.12),
            child: Icon(
              Icons.psychology,
              size: 18,
              color: colors.textDim,
            ),
          ),
          const SizedBox(width: 12),
        ],

        // MESSAGE CONTENT
        Flexible(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? colors.accent
                        : colors.surface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isUser
                          ? colors.accent
                          : colors.surfaceBorder.withValues(alpha: 0.1),
                    ),
                  ),
                  child: (msg.status == MessageStatus.thinking ||
                          msg.status == MessageStatus.sending)
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (msg.content.isNotEmpty &&
                                msg.content != 'Thinking...') ...[
                              Flexible(
                                child: Text(
                                  msg.content,
                                  style: AppTextStyles.body(
                                    isUser
                                        ? Colors.white
                                        : colors.text,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            ThinkingIndicator(colors: colors),
                          ],
                        )
                      : Text(
                          msg.content,
                          style: AppTextStyles.body(
                            isUser ? Colors.white : colors.text,
                          ),
                        ),
                ),

                // Memory Sparks (only for AI)
                if (!isUser && msg.sources.isNotEmpty)
                  MemorySparks(
                    count: msg.sources.length,
                    labelOverride: msg.status == MessageStatus.thinking
                        ? "Connecting memories..."
                        : null,
                  ),
              ],
            ),
          ),
        ),

        // USER AVATAR (Right)
        if (isUser) ...[
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 16,
            backgroundColor: colors.surface,
            child: Icon(Icons.person, size: 18, color: colors.textDim),
          ),
        ],
      ],
    );
  }
}

/// Collapsible Sources Widget - Handles Option A and B for source display
class _CollapsibleSources extends StatefulWidget {
  final List<String> sources;

  const _CollapsibleSources({required this.sources});

  @override
  State<_CollapsibleSources> createState() => _CollapsibleSourcesState();
}

class _CollapsibleSourcesState extends State<_CollapsibleSources> {
  // Toggle this to switch between Option A and Option B
  static const bool _useOptionA = true;

  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.sources.isEmpty) return const SizedBox.shrink();

    // OPTION A: Subtle text "from X memories"
    if (_useOptionA) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Consumer(
          builder: (context, ref, child) {
            final colors = ref.watch(themeProvider).colors;
            return Text(
              'from ${widget.sources.length} memories',
              style: TextStyle(
                color: colors.textDim,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            );
          },
        ),
      );
    }

    // OPTION B: Collapsed button (Default)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Consumer(
              builder: (context, ref, child) {
                final colors = ref.watch(themeProvider).colors;
                return Text(
                  _isExpanded ? '↑ sources' : '↓ sources',
                  style: TextStyle(color: colors.textDim, fontSize: 11),
                );
              },
            ),
          ),
        ),
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Consumer(
              builder: (context, ref, child) {
                final colors = ref.watch(themeProvider).colors;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.sources.map((source) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.surfaceBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.description,
                            color: colors.textDim,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            source, // Filename (e.g., notes.txt)
                            style: TextStyle(
                              color: colors.text,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Animated Hint Text - Breathing effect, accepts configurable text
class _AnimatedHintText extends StatefulWidget {
  final String text;
  final CircadianColors colors;

  const _AnimatedHintText({required this.colors, this.text = 'start typing ...'});

  @override
  State<_AnimatedHintText> createState() => _AnimatedHintTextState();
}

class _AnimatedHintTextState extends State<_AnimatedHintText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.2,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Text(
        widget.text,
        style: TextStyle(
          color: widget.colors.text, // Opacity handles the dimming
          fontSize: 20,
          fontWeight: FontWeight.w300,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
