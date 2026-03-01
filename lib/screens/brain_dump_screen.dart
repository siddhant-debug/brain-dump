import 'dart:ui';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../features/brain_dump/models/chat_message.dart';
import '../features/brain_dump/providers/brain_dump_provider.dart';
import '../features/auth/controllers/auth_controller.dart';
import '../features/vault/presentation/file_vault_screen.dart';
import '../features/vault/presentation/thoughts_screen.dart';
import '../core/widgets/persistent_header.dart';
import '../core/theme/app_theme.dart';
import '../features/analytics/presentation/analytics_screen.dart';
import '../features/analytics/services/analytics_service.dart';

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

  // Navigation State
  int _selectedIndex = 0; // 0: Insights, 1: Chat, 2: Thoughts, 3: Vault

  // Message tracking
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
    debugPrint(
      'DEBUG UI RENDER: brainDumpState.messages.length = ${brainDumpState.messages.length}',
    );

    // Auto-scroll when new messages arrive
    if (brainDumpState.messages.length > _previousMessageCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
      _previousMessageCount = brainDumpState.messages.length;
    }

    return Scaffold(
      backgroundColor: AppColors.background, // Pure black
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            // LAYER 1: CONTENT — routes between Journal/Chat on tab 1
            Positioned.fill(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  const AnalyticsScreen(),
                  brainDumpState.isChatMode
                      ? _buildChatLayer(brainDumpState)
                      : _buildJournalLayout(),
                  const ThoughtsScreen(isEmbedded: true),
                  const FileVaultScreen(isEmbedded: true),
                ],
              ),
            ),

            // LAYER 2: MINIMAL INPUT (Chat mode only, on tab 1)
            if (_selectedIndex == 1 && brainDumpState.isChatMode)
              Positioned(
                bottom: 100, // Above dock
                left: 24,
                right: 24,
                child: _buildMinimalInput(),
              ),

            // LAYER 3: PILL-SHAPED DOCK
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: _PillDock(
                  selectedIndex: _selectedIndex,
                  onTabSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shared header — mode toggle + clear + logout
  Widget _buildHeader(bool isChatMode) {
    return PersistentHeader(
      title: 'BrainDumps',
      subtitle: _buildModeToggle(isChatMode),
      actions: [
        // Clear History Button — only in chat mode
        if (isChatMode)
          IconButton(
            icon: const Icon(
              Icons.cleaning_services_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppColors.background,
                  title: const Text(
                    'Clear Screen?',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  content: const Text(
                    'This will clear messages from your screen but keep them in your brain.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    TextButton(
                      child: const Text(
                        'Clear',
                        style: TextStyle(color: AppColors.error),
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
          icon: const Icon(Icons.logout_rounded, color: Colors.white24),
          onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
        ),
      ],
    );
  }

  /// Mode toggle
  Widget _buildModeToggle(bool isChatMode) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isChatMode ? 'Chat' : 'Journal',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          height: 18,
          child: Switch.adaptive(
            value: isChatMode,
            onChanged: (_) {
              ref.read(brainDumpProvider.notifier).toggleMode();
            },
            activeThumbColor: AppColors.textPrimary.withValues(alpha: 0.6),
            activeTrackColor: AppColors.textPrimary.withValues(alpha: 0.1),
            inactiveThumbColor: AppColors.accent,
            inactiveTrackColor: AppColors.accent.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }

  /// Chat layout — messages list, input at bottom via Layer 2 overlay
  Widget _buildChatLayer(BrainDumpState state) {
    return Column(
      children: [
        _buildHeader(state.isChatMode),
        Expanded(
          child: ListView.builder(
            reverse:
                true, // Forces layout from bottom, so it naturally anchors to bottom
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(
              left: 24,
              right: 24,
              top: 0,
              bottom: 180, // Space for input + dock
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
                child: _MinimalMessageRow(msg: msg),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Journal layout — input at top with green text, ghost animation
  Widget _buildJournalLayout() {
    return Column(
      children: [
        _buildHeader(false),
        // Input area at top — full remaining space
        Expanded(
          child: SingleChildScrollView(
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
                          color: AppColors.textSecondary,
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
                        ? const _AnimatedHintText(text: 'dump your thoughts...')
                        : const SizedBox.shrink();
                  },
                ),
                // Actual input — green text
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLines: null,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _onSubmitted(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    height: 1.5,
                  ),
                  cursorColor: AppColors.accent,
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
        // Checkmark indicator — centered below input after save
        if (_showCheckmark)
          FadeTransition(
            opacity: _checkmarkController,
            child: const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Icon(
                Icons.check_circle_outline,
                color: AppColors.textSecondary,
                size: 28,
              ),
            ),
          ),
      ],
    );
  }

  /// Minimal input for Chat mode — positioned at bottom via Stack overlay
  Widget _buildMinimalInput() {
    return Row(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Custom Animated Hint
              ValueListenableBuilder(
                valueListenable: _controller,
                builder: (context, value, child) {
                  return value.text.isEmpty
                      ? const _AnimatedHintText(text: 'start asking...')
                      : const SizedBox.shrink();
                },
              ),
              // Actual Input
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _onSubmitted(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
                cursorColor: AppColors.accent,
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
        // Checkmark indicator
        if (_showCheckmark)
          FadeTransition(
            opacity: _checkmarkController,
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.check, color: AppColors.textPrimary, size: 16),
            ),
          ),
      ],
    );
  }
}

// [Architect] NEW COMPONENT: Visible Thinking Indicator
// Replaces the invisible/subtle text with a clear animation
class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({super.key});

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
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

/// Minimal Message Row - No cards, no bubbles, just text
class _MinimalMessageRow extends StatelessWidget {
  final ChatMessage msg;

  const _MinimalMessageRow({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.sender == MessageSender.user;

    return Row(
      mainAxisAlignment: isUser
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start, // Align to top
      children: [
        // AI AVATAR (Left)
        if (!isUser) ...[
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.textPrimary.withValues(alpha: 0.12),
            child: const Icon(
              Icons.psychology,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
        ],

        // MESSAGE CONTENT
        Flexible(
          // Use Flexible to allow wrapping
          child: Container(
            constraints: BoxConstraints(
              maxWidth:
                  MediaQuery.of(context).size.width *
                  0.75, // Slightly reduced width to fit avatars
            ),
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Show thinking indicator if we are in thinking or sending status
                (msg.status == MessageStatus.thinking ||
                        msg.status == MessageStatus.sending)
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (msg.content.isNotEmpty &&
                              msg.content != 'Thinking...') ...[
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [TextSpan(text: msg.content)],
                                ),
                                textAlign: isUser
                                    ? TextAlign.right
                                    : TextAlign.left,
                                style: TextStyle(
                                  color: isUser
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          const Padding(
                            padding: EdgeInsets.only(top: 2.0),
                            child: ThinkingIndicator(),
                          ),
                        ],
                      )
                    : Text.rich(
                        TextSpan(children: [TextSpan(text: msg.content)]),
                        textAlign: isUser ? TextAlign.right : TextAlign.left,
                        style: TextStyle(
                          color: isUser
                              ? AppColors.textPrimary
                              : AppColors.textSecondary, // [Architect] AI Color
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),

                // SOURCES (If AI and has sources)
                if (!isUser && msg.sources.isNotEmpty)
                  _CollapsibleSources(
                    sources: msg.sources,
                    locationContext: msg.locationContext,
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
            backgroundColor: AppColors.surfaceHigh,
            child: const Icon(
              Icons.person,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Pill-Shaped Dock - Minimal, glass effect
class _PillDock extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabSelected;

  const _PillDock({required this.selectedIndex, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 280,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _DockItem(
                icon: Icons.bar_chart_rounded,
                label: 'Insights',
                isSelected: selectedIndex == 0,
                onTap: () => onTabSelected(0),
              ),
              _DockItem(
                icon: Icons.note_alt_outlined,
                label: 'Dump',
                isSelected: selectedIndex == 1,
                onTap: () => onTabSelected(1),
              ),
              _DockItem(
                icon: Icons.lightbulb_outline,
                label: 'Thoughts',
                isSelected: selectedIndex == 2,
                onTap: () => onTabSelected(2),
              ),
              _DockItem(
                icon: Icons.folder_copy_rounded,
                label: 'Vault',
                isSelected: selectedIndex == 3,
                onTap: () => onTabSelected(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DockItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Collapsible Sources Widget - Handles Option A and B for source display
class _CollapsibleSources extends StatefulWidget {
  final List<String> sources;
  final Map<String, dynamic>? locationContext;

  const _CollapsibleSources({required this.sources, this.locationContext});

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

    // Format location string
    String locationText = "";
    if (widget.locationContext != null) {
      final city = widget.locationContext!['city'] as String?;
      final type = widget.locationContext!['location_type'] as String?;

      if (city != null) {
        String cleanCity = city.replaceAll('(specific_location)', '').trim();
        locationText = " • at $cleanCity";
        if (type != null &&
            type != 'outdoor' &&
            type != 'Unknown Place' &&
            type != 'specific_location') {
          locationText += " ($type)";
        }
      }
    }

    // OPTION A: Subtle text "from X memories"
    if (_useOptionA) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'from ${widget.sources.length} memories$locationText',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
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
            child: Text(
              _isExpanded ? '↑ sources' : '↓ sources',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ),
        ),
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.sources.map((source) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.description,
                        color: AppColors.textSecondary,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        source, // Filename (e.g., notes.txt)
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

/// Animated Hint Text - Breathing effect, accepts configurable text
class _AnimatedHintText extends StatefulWidget {
  final String text;

  const _AnimatedHintText({this.text = 'start typing ...'});

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
        style: const TextStyle(
          color: AppColors.textPrimary, // Opacity handles the dimming
          fontSize: 20,
          fontWeight: FontWeight.w300,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
