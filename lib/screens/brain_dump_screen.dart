import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // For ScrollDirection
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../features/brain_dump/models/chat_message.dart';
import '../features/brain_dump/providers/brain_dump_provider.dart';
import '../features/auth/controllers/auth_controller.dart';
import '../features/vault/presentation/file_vault_screen.dart';

// [Architect] TermiChat-Style Terminal UI
// Design Philosophy:
// 1. Authentic Terminal: Header, version, initialization message
// 2. Command-line Prompts: username@terminal:~$ format
// 3. Timestamps: HH:mm:ss format for all messages
// 4. Debug Logging: Show API endpoint status

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
  int _selectedIndex = 0; // 0: Chat (Home), 1: Vault (Library)

  // Message tracking
  int _previousMessageCount = 0;

  // Dock Animation
  double _dockOpacity = 1.0;
  double _dockBottomPosition = 20.0;

  // Typing indicator animation
  late AnimationController _typingAnimationController;

  // Username for terminal prompt
  String _username = 'guest';

  @override
  void initState() {
    super.initState();

    // Typing indicator animation
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Scroll listener for dock animation
    _scrollController.addListener(_handleScroll);

    // Auto-focus on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedIndex == 0) {
        _focusNode.requestFocus();
      }
      _loadUsername();
    });
  }

  Future<void> _loadUsername() async {
    // Try to get user email from auth
    try {
      final storage = const FlutterSecureStorage();
      final email = await storage.read(key: 'user_email');
      if (email != null && mounted) {
        setState(() {
          _username = email.split('@')[0]; // Use email prefix as username
        });
      }
    } catch (e) {
      // Keep default 'guest'
    }
  }

  void _handleScroll() {
    if (_scrollController.hasClients) {
      final scrollPosition = _scrollController.position;
      final isScrollingDown =
          scrollPosition.userScrollDirection == ScrollDirection.reverse;

      setState(() {
        if (isScrollingDown) {
          _dockOpacity = 0.3;
          _dockBottomPosition = 10.0;
        } else {
          _dockOpacity = 1.0;
          _dockBottomPosition = 20.0;
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
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

  void _autoFocusAfterResponse() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _selectedIndex == 0) {
        _focusNode.requestFocus();
      }
    });
  }

  Future<void> _onSubmitted() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    try {
      await ref.read(brainDumpProvider.notifier).processInput(text);
      if (!mounted) return;
      _controller.clear();
      _focusNode.requestFocus();
    } catch (e) {
      debugPrint('[DEBUG] Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final brainDumpState = ref.watch(brainDumpProvider);

    // Auto-scroll and auto-focus when new messages arrive
    if (brainDumpState.messages.length > _previousMessageCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
        // Only auto-focus if the last message is from AI (response received)
        if (brainDumpState.messages.isNotEmpty &&
            brainDumpState.messages.last.sender == MessageSender.ai &&
            brainDumpState.messages.last.status == MessageStatus.sent) {
          _autoFocusAfterResponse();
        }
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
                  _buildChatLayer(),
                  const FileVaultScreen(isEmbedded: true),
                ],
              ),
            ),

            // LAYER 2: TERMINAL INPUT (Only visible on Chat screen)
            if (_selectedIndex == 0)
              Positioned(
                bottom: 100, // Above dock
                left: 20,
                right: 20,
                child: _buildTerminalInput(),
              ),

            // LAYER 3: iOS-STYLE GLASS DOCK
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              bottom: _dockBottomPosition,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _dockOpacity,
                child: Center(
                  child: _GlassDock(
                    selectedIndex: _selectedIndex,
                    onTabSelected: (index) {
                      setState(() {
                        _selectedIndex = index;
                        if (index == 0) {
                          Future.delayed(const Duration(milliseconds: 100), () {
                            _focusNode.requestFocus();
                          });
                        }
                      });
                    },
                  ),
                ),
              ),
            ),

            // LAYER 4: LOGOUT (Top Right - Minimal)
            Positioned(
              top: 50,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white24),
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).signOut(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatLayer() {
    final brainDumpState = ref.watch(brainDumpProvider);
    final hasMessages = brainDumpState.messages.isNotEmpty;

    return Column(
      children: [
        // Terminal Header
        _buildTerminalHeader(),

        // Initialization Message (only show if no messages)
        if (!hasMessages) _buildInitMessage(),

        // Chat Messages
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 180, // Space for input + dock
            ),
            itemCount: brainDumpState.messages.length,
            itemBuilder: (context, index) {
              final msg = brainDumpState.messages[index];
              return _MessageRow(
                msg: msg,
                username: _username,
                typingAnimation: _typingAnimationController,
              );
            },
          ),
        ),
      ],
    );
  }

  // Terminal Header (TermiChat style)
  Widget _buildTerminalHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Green dot indicator
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF00FF00),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          // App name
          const Text(
            'BRAIN',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const Text(
            'DUMP',
            style: TextStyle(
              color: Color(0xFF666666),
              fontSize: 16,
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 12),
          // Version badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF00FF00)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'v1.0.0',
              style: TextStyle(
                color: Color(0xFF00FF00),
                fontSize: 10,
                fontFamily: 'Courier',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Initialization Message
  Widget _buildInitMessage() {
    final now = DateFormat('HH:mm:ss').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '[INFO] System initialized. Secure',
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 14,
              fontFamily: 'Courier',
              height: 1.5,
            ),
          ),
          const Text(
            '       connection established via',
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 14,
              fontFamily: 'Courier',
              height: 1.5,
            ),
          ),
          const Text(
            '       RAG Engine. Awaiting input.',
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 14,
              fontFamily: 'Courier',
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            now,
            style: const TextStyle(
              color: Color(0xFF444444),
              fontSize: 12,
              fontFamily: 'Courier',
            ),
          ),
        ],
      ),
    );
  }

  // Terminal-style Input Field with username@terminal:~$ prompt
  Widget _buildTerminalInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFF00FF00).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // Terminal prompt: username@terminal:~$
          Text(
            '$_username@terminal:~\$',
            style: const TextStyle(
              color: Color(0xFF00FF00),
              fontSize: 14,
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _onSubmitted(),
              style: const TextStyle(
                color: Color(0xFF00FFFF), // Cyan for user input
                fontSize: 14,
                fontFamily: 'Courier',
              ),
              cursorColor: const Color(0xFF00FF00),
              decoration: const InputDecoration(
                hintText: 'Type command or message',
                hintStyle: TextStyle(
                  color: Color(0xFF444444),
                  fontFamily: 'Courier',
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Terminal-style Message Row with Timestamp
class _MessageRow extends StatelessWidget {
  final ChatMessage msg;
  final String username;
  final AnimationController typingAnimation;

  const _MessageRow({
    required this.msg,
    required this.username,
    required this.typingAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = msg.sender == MessageSender.user;
    final isThinking = msg.status == MessageStatus.thinking;
    final isMemorizing = msg.status == MessageStatus.memorizing;

    // Terminal color scheme
    Color textColor = const Color(0xFF00FF00); // AI: Terminal green
    if (isUser) textColor = const Color(0xFF00FFFF); // User: Cyan
    if (isMemorizing) textColor = const Color(0xFFFFFF00); // Memorizing: Yellow
    if (msg.content.startsWith('Error:'))
      textColor = const Color(0xFFFF0000); // Error: Red

    // Debug log prefix
    String debugPrefix = '';
    if (msg.content.startsWith('Error:')) {
      debugPrefix = '[ERROR] ';
    } else if (isMemorizing || msg.content.contains('Memorized')) {
      debugPrefix = '[DEBUG] ';
    }

    // Timestamp
    final timestamp = DateFormat('HH:mm:ss').format(msg.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Message with prompt
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Terminal prompt
              Text(
                isUser ? '$username@terminal:~\$' : r'system@brain:~$',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              // Message content
              Expanded(
                child: isThinking
                    ? _TypingIndicator(animation: typingAnimation)
                    : Text(
                        '$debugPrefix${msg.content}',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontFamily: 'Courier',
                          height: 1.4,
                        ),
                      ),
              ),
            ],
          ),
          // Timestamp
          Padding(
            padding: const EdgeInsets.only(left: 0, top: 2),
            child: Text(
              timestamp,
              style: const TextStyle(
                color: Color(0xFF444444),
                fontSize: 11,
                fontFamily: 'Courier',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Terminal-style Typing Indicator
class _TypingIndicator extends StatelessWidget {
  final AnimationController animation;

  const _TypingIndicator({required this.animation});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: const Text(
        '...',
        style: TextStyle(
          color: Color(0xFF00FF00), // Terminal green
          fontSize: 14,
          fontFamily: 'Courier',
          letterSpacing: 4,
        ),
      ),
    );
  }
}

// iOS-Style Glass Dock
class _GlassDock extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabSelected;

  const _GlassDock({required this.selectedIndex, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(35),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 320,
          height: 75,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(35),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _DockItem(
                icon: Icons.radio_button_checked,
                label: 'Home',
                isSelected: selectedIndex == 0,
                onTap: () => onTabSelected(0),
              ),
              _DockItem(
                icon: Icons.grid_view_rounded,
                label: 'Library',
                isSelected: selectedIndex == 1,
                onTap: () => onTabSelected(1),
              ),
              _DockItem(
                icon: Icons.stream,
                label: 'Flow',
                isSelected: false,
                onTap: () {},
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
            color: isSelected ? const Color(0xFFFA2D48) : Colors.white24,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white24,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
