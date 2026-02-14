import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/*
1 : DockState encapsulates the visual state of the sidebar.
isOpen: Controls visibility and magnification capability.
iconPositions: Stores the screen coordinates of icons to allow the background
painter to morph roots towards them.
*/
class DockState {
  final bool isOpen;
  final List<Offset> iconPositions;

  DockState({this.isOpen = false, this.iconPositions = const []});

  DockState copyWith({bool? isOpen, List<Offset>? iconPositions}) {
    return DockState(
      isOpen: isOpen ?? this.isOpen,
      iconPositions: iconPositions ?? this.iconPositions,
    );
  }
}

/*
2 : DockNotifier manages the dock state transitions.
*/
class DockNotifier extends StateNotifier<DockState> {
  DockNotifier() : super(DockState());

  void toggle() {
    state = state.copyWith(isOpen: !state.isOpen);
  }

  void close() {
    state = state.copyWith(isOpen: false);
  }

  void updatePositions(List<Offset> positions) {
    state = state.copyWith(iconPositions: positions);
  }
}

final dockProvider = StateNotifierProvider<DockNotifier, DockState>((ref) {
  return DockNotifier();
});
