import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Features
import '../features/brain_dump/providers/brain_dump_provider.dart';
import '../features/brain_dump/widgets/brain_dump_input.dart';
import '../features/brain_dump/widgets/interactive_neural_tree.dart';
import '../features/dock/providers/dock_provider.dart';
import '../features/dock/widgets/magnified_dock.dart';
import '../features/music/providers/music_provider.dart';
import '../features/notes/services/note_service.dart';

// Core / Shared
import '../core/widgets/minimal_icon_button.dart';
import '../core/widgets/synaptic_roots_background.dart';
import '../features/auth/controllers/auth_controller.dart';
import '../features/vault/presentation/file_vault_screen.dart';

class BrainDumpScreen extends ConsumerStatefulWidget {
  const BrainDumpScreen({super.key});

  @override
  ConsumerState<BrainDumpScreen> createState() => _BrainDumpScreenState();
}

class _BrainDumpScreenState extends ConsumerState<BrainDumpScreen>
    with SingleTickerProviderStateMixin {
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

  Future<void> _onSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    // Show loading? BrainDumpInput handles its own if needed, but we can do it here.
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

      // Optionally refresh notes list if we had one here
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

  void _toggleDock() {
    ref.read(dockProvider.notifier).toggle();
    if (ref.read(dockProvider).isOpen) {
      // Defer position update until animation settles
      Future.delayed(const Duration(milliseconds: 360), _updateDockPositions);
    }
  }

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
    // `ref.watch` subscribes this widget to changes in these providers.
    // If any of these states change, Flutter will re-run this build() method.
    final dockState = ref.watch(dockProvider);
    final musicState = ref.watch(musicProvider);
    final brainDumpState = ref.watch(
      brainDumpProvider,
    ); // Rebuilds on isProcessing changes
    final userState = ref.watch(
      userProvider,
    ); // Fetches user data asynchronously

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

                // 1.5 Interactive Neural Tree Nodes (Hidden while typing)
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: isWriting ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 400),
                    child: IgnorePointer(
                      ignoring: isWriting,
                      child: InteractiveNeuralTree(
                        phase: _pulseController.value,
                      ),
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

                // 3. Action Buttons (Lower UI)
                _buildActionButtons(brainDumpState),

                // 4. Overlays & Modals
                if (dockState.isOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => ref.read(dockProvider.notifier).close(),
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox.expand(),
                    ),
                  ),

                // 5. Dock Implementation
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
