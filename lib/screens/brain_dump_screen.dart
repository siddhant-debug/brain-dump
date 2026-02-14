import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Features
import '../features/brain_dump/providers/brain_dump_provider.dart';
import '../features/brain_dump/widgets/brain_dump_input.dart';
// import '../features/brain_dump/widgets/interactive_neural_tree.dart'; // [Preserved]
import '../features/dock/providers/dock_provider.dart';
import '../features/dock/widgets/magnified_dock.dart';
import '../features/music/providers/music_provider.dart';
import '../features/notes/services/note_service.dart';

// Core / Shared
import '../core/widgets/minimal_icon_button.dart';
// import '../core/widgets/synaptic_roots_background.dart'; // [Preserved]
import '../core/widgets/synaptic_roots_background.dart';
import '../features/brain_dump/widgets/interactive_neural_tree.dart';
import '../features/auth/controllers/auth_controller.dart';
import '../features/vault/presentation/file_vault_screen.dart';
// import 'neural_canvas_page.dart'; // Preserved for reference
// [New Circuit Layout]

/*
1 : BrainDumpScreen is a ConsumerStatefulWidget that serves as the main interaction hub.
It uses Riverpod's ConsumerState to access providers and manage its local state.
*/
class BrainDumpScreen extends ConsumerStatefulWidget {
  const BrainDumpScreen({super.key});

  @override
  ConsumerState<BrainDumpScreen> createState() => _BrainDumpScreenState();
}

class _BrainDumpScreenState extends ConsumerState<BrainDumpScreen>
    with SingleTickerProviderStateMixin {
  /*
  2 : _controller manages the text input in the main brain dump field.
  _focusNode controls the keyboard focus for the input field.
  _dockIconKeys stores GlobalKeys for each dock item to calculate their global positions.
  _pulseController drives the ambient breathing animation of the UI.
  */
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<GlobalKey> _dockIconKeys = List.generate(4, (_) => GlobalKey());
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat(reverse: true);

    // Add listener to rebuild when typing starts/stops
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /*
  3 : _onSubmitted is the primary flow for saving thoughts.
  It triggers the noteServiceProvider to persist the text to the backend.
  Optimistically clears the input and refocuses on success.
  */
  Future<void> _onSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    try {
      await ref.read(noteServiceProvider).saveNote(text);
      if (!mounted) return;

      _controller.clear();
      _focusNode.requestFocus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thought saved to the Vault!'),
          backgroundColor: Colors.blueAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /*
  4 : _toggleDock manages the opening/closing of the magnified dock.
  It triggers a delayed position update to ensure the dock icons are rendered 
  before calculating their screen coordinates for the synaptic roots background.
  */
  void _toggleDock() {
    ref.read(dockProvider.notifier).toggle();
    if (ref.read(dockProvider).isOpen) {
      Future.delayed(const Duration(milliseconds: 360), _updateDockPositions);
    }
  }

  /*
  5 : _updateDockPositions calculates where the dock icons are on the screen.
  These coordinates are shared with the SynapticRootsBackground to draw connections.
  */
  void _updateDockPositions() {
    if (!mounted) return;
    final positions = <Offset>[];
    for (final key in _dockIconKeys) {
      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final pos = renderBox.localToGlobal(Offset.zero);
        final center =
            pos + Offset(renderBox.size.width / 2, renderBox.size.height / 2);
        positions.add(center);
      }
    }
    ref.read(dockProvider.notifier).updatePositions(positions);
  }

  @override
  Widget build(BuildContext context) {
    // [Architect] REACTIVE UI BINDINGS
    /*
    6 : dockState: Stores dock open/close status and icon positions.
    musicState: Tracks playing status of external apps (Spotify/Apple).
    brainDumpState: Manages the 'processing' state of the AI/Input.
    userState: Provides authenticated user info (fetched via /auth/me).
    */
    final dockState = ref.watch(dockProvider);
    final musicState = ref.watch(musicProvider);
    final brainDumpState = ref.watch(brainDumpProvider);
    final userState = ref.watch(userProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final isWriting = _controller.text.isNotEmpty;

            return Stack(
              children: [
                /*
                // ─── [ CIRCUIT LAYOUT ] ──────────────────────────────────────────────
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: isWriting ? 0.0 : 0.8,
                    duration: const Duration(milliseconds: 300),
                    child: const NeuralCanvasPage(),
                  ),
                ),
                */

                // [LEGACY BIOLOGY RESTORED]
                // 1. Synaptic roots background (Hidden while typing)
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: isWriting ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 400),
                    child: SynapticRootsBackground(
                      isDockOpen: dockState.isOpen,
                      dockIconPositions: dockState.iconPositions,
                      phase: _pulseController.value,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),

                // 2. Main Input Feature
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 16.0,
                    ),
                    child: BrainDumpInput(
                      controller: _controller,
                      focusNode: _focusNode,
                      onSubmitted: _onSubmitted,
                      userName: userState.when(
                        data: (user) =>
                            user?.fullName ?? user?.email.split('@')[0],
                        loading: () => null,
                        error: (_, __) => null,
                      ),
                    ),
                  ),
                ),

                // 3. Interactive Neural Tree Nodes (On top, hidden while typing)
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: isWriting ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 400),
                    child: InteractiveNeuralTree(phase: _pulseController.value),
                  ),
                ),

                // 4. Action Buttons (Lower UI)
                _buildActionButtons(brainDumpState),

                // 5. Overlays & Modals
                if (dockState.isOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => ref.read(dockProvider.notifier).close(),
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox.expand(),
                    ),
                  ),

                // 6. Dock Implementation
                MagnifiedDock(
                  isOpen: dockState.isOpen,
                  onToggle: _toggleDock,
                  iconKeys: _dockIconKeys,
                  activeApps: {
                    'apple': musicState.applePlaying,
                    'spotify': musicState.spotifyPlaying,
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /*
  8 : _buildActionButtons provides the bottom-row interactions:
  - Submit: Manual submission of the current thought.
  - The Vault: Navigates to the file storage screen.
  - Logout: Invalidates the auth session via AuthController.
  */
  Widget _buildActionButtons(BrainDumpState state) {
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 0, 80.0, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            MinimalIconButton(
              icon: Icons.send_rounded,
              tooltip: 'Submit',
              onPressed: () => _onSubmitted(_controller.text),
              isLoading: state.isProcessing,
            ),
            MinimalIconButton(
              icon: Icons.folder_copy_rounded,
              tooltip: 'The Vault',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const FileVaultScreen(),
                ),
              ),
            ),
            MinimalIconButton(
              icon: Icons.logout_rounded,
              tooltip: 'Logout',
              onPressed: () {
                debugPrint('Logout button pressed');
                ref.read(authControllerProvider.notifier).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}
