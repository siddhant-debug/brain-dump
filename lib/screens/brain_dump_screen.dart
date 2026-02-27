import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../features/brain_dump/models/chat_message.dart';
import '../features/brain_dump/providers/brain_dump_provider.dart';
import '../features/auth/controllers/auth_controller.dart';
import '../features/vault/presentation/file_vault_screen.dart';
import '../features/vault/presentation/thoughts_screen.dart';
import '../core/widgets/persistent_header.dart';
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
    with SingleTickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();

    _checkmarkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _checkmarkController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _onSubmitted() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // [Architect] UX FIX: CLEAN INPUT EARLY
    // We clear the input field immediately so the user doesn't feel "blocked".
    // The previous logic waited for the AI stream to finish, which was bad UX.
    _controller.clear();

    final isQuery = text.endsWith('?');

    try {
      if (isQuery) {
        // Query: Show in chat and get AI response
        await ref.read(brainDumpProvider.notifier).processInput(text);
      } else {
        // Note: Save silently with checkmark feedback
        await ref.read(brainDumpProvider.notifier).saveNoteSilently(text);
        if (!mounted) return;

        // Show checkmark animation
        setState(() => _showCheckmark = true);
        _checkmarkController.forward();

        // Hide checkmark after 1 second
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() => _showCheckmark = false);
            _checkmarkController.reset();
          }
        });
      }

      // [Architect] Invalidate analytics providers to force a refresh of the Insights tab
      ref.invalidate(consistencyProvider);
      ref.invalidate(themesProvider);
      ref.invalidate(loopsProvider);
      ref.invalidate(pipelineProvider);
    } catch (e) {
      debugPrint('[DEBUG] Error: $e');
      if (!mounted) return;

      String errorMsg = e.toString().replaceAll('Exception: ', '');
      if (e is DioException) {
        final detail = e.response?.data?['detail'];
        errorMsg = detail != null
            ? detail.toString()
            : e.message ?? 'Network error occurred';
      }

      // Show error in chat
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
      backgroundColor: const Color(0xFF000000), // Pure black
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // LAYER 1: CONTENT (Chat or Vault)
            Positioned.fill(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  const AnalyticsScreen(),
                  _buildChatLayer(brainDumpState),
                  const ThoughtsScreen(isEmbedded: true),
                  const FileVaultScreen(isEmbedded: true),
                ],
              ),
            ),

            // LAYER 2: MINIMAL INPUT (Only visible on Chat screen — tab 1)
            if (_selectedIndex == 1)
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

  Widget _buildChatLayer(BrainDumpState state) {
    return Column(
      children: [
        PersistentHeader(
          title: 'BrainDumps',
          actions: [
            // Clear History Button - Local only
            IconButton(
              icon: Icon(
                Theme.of(context).platform == TargetPlatform.iOS
                    ? Icons
                          .cleaning_services_rounded // Keeping material here as there isn't a great cupertino match for un-bespoke sweeping
                    : Icons.cleaning_services_rounded,
                color: Colors.white24,
                size: 20,
              ),
              onPressed: () {
                // Confirm before clearing
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1C1C1E),
                    title: const Text(
                      'Clear Screen?',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'This will clear messages from your screen but keep them in your brain.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white54),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      TextButton(
                        child: const Text(
                          'Clear',
                          style: TextStyle(color: Colors.redAccent),
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
              icon: Icon(
                Theme.of(context).platform == TargetPlatform.iOS
                    ? Icons
                          .logout_rounded // Keeping material since cupertino_icons doesn't have a direct logout
                    : Icons.logout_rounded,
                color: Colors.white24,
              ),
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
            ),
          ],
        ),
        Expanded(
          child: ListView.builder(
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
              final msg = state.messages[index];
              final isLast = index == state.messages.length - 1;

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
                      ? const _AnimatedHintText()
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
                style: const TextStyle(color: Colors.white, fontSize: 16),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: null, // Disabled in favor of animated hint
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
              child: Icon(Icons.check, color: Colors.white, size: 20),
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
        color: Colors.white54,
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
            backgroundColor: Colors.white12,
            child: const Icon(
              Icons.psychology,
              size: 18,
              color: Colors.white70,
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
                (msg.content.isEmpty &&
                        (msg.status == MessageStatus.thinking ||
                            msg.status == MessageStatus.sending))
                    ? const ThinkingIndicator()
                    : Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text:
                                  (msg.status == MessageStatus.thinking &&
                                      msg.content == 'Thinking...')
                                  ? '' // Hide the hardcoded 'Thinking...' text from Provider
                                  : msg.content,
                            ),
                            if (!isUser &&
                                (msg.status == MessageStatus.sending ||
                                    msg.status == MessageStatus.thinking))
                              const WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: ThinkingIndicator(),
                                ),
                              ),
                          ],
                        ),
                        textAlign: isUser ? TextAlign.right : TextAlign.left,
                        style: TextStyle(
                          color: isUser
                              ? Colors.white
                              : const Color(0xFFE0E0E0), // [Architect] AI Color
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
            backgroundColor: Colors.blueGrey.withValues(alpha: 0.2),
            child: const Icon(Icons.person, size: 18, color: Colors.blueGrey),
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
            color: const Color(0xFF1C1C1E).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                icon: Icons.chat_bubble_rounded,
                label: 'chat',
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
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.4),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
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

  const _CollapsibleSources({
    super.key,
    required this.sources,
    this.locationContext,
  });

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
        locationText = " • at $city";
        if (type != null && type != 'outdoor' && type != 'Unknown Place') {
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
            color: Colors.grey[500],
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
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
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
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.description,
                        color: Colors.white54,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        source, // Filename (e.g., notes.txt)
                        style: const TextStyle(
                          color: Colors.white70,
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

/// Animated Hint Text - Breathing effect + optional typewriter animation
class _AnimatedHintText extends StatefulWidget {
  const _AnimatedHintText({super.key});

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
      child: const Text(
        'start typing ...',
        style: TextStyle(
          color: Colors.white, // Opacity handles the dimming
          fontSize: 20,
          fontWeight: FontWeight.w300,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
