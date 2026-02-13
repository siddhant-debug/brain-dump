# Interactive Neural Tree Implementation

## Overview
The **Interactive Neural Tree** is a visualization that maps file system objects (Files/Notes) to "synaptic nodes" on a living, breathing background. It solves the problem of making a `CustomPainter` interactive by overlaying invisible touch targets.

## Core Components

### 1. The Background (`SynapticRootsBackground`)
- **Role**: Purely visual. It draws the organic, moving lines.
- **Tech**: `CustomPainter`.
- **Animation**: Uses a recursive fractal algorithm. The "sway" is driven by a `sine` wave function of the current `phase` (0..1) from an `AnimationController`.
- **Connection Logic**: When the Dock opens, the tips of the roots "morph" using vector interpolation to connect to the specific coordinate of the dock icons.

### 2. The Interactive Layer (`InteractiveNeuralTree`)
- **Role**: Handles clicks and labels.
- **Tech**: `Stack` + `Positioned` widgets.
- **Synchronization**:
    - It uses **the exact same recursive algorithm** and seed (`Random(77)`) as the Background Painter.
    - Instead of drawing lines, it calculates the (x,y) coordinates of where the "nodes" (branch tips) *would be*.
    - It places `GestureDetector` widgets at those exact coordinates.

## Implementation Details

### The "Ghost Tree" Technique
To make a painted tree interactive without complex hit-testing on the canvas:

1.  **Deterministic Randomness**: We use `Random(77)` in both the Painter and the Widget Builder. This ensures the tree structure is identical in both layers.
2.  **Shared State**: Both widgets share the same `AnimationController` value (`phase`). As the background sways, the interactive nodes calculate the same sway offset, keeping them perfectly pinned to the moving branches.
3.  **Layering**:
    ```dart
    Stack(
      children: [
        SynapticRootsBackground(), // Paints lines
        InteractiveNeuralTree(),   // Places invisible buttons
      ],
    )
    ```

### Code Snippet: Node Calculation
```dart
// precise math to match the painter's sway
final sway = sin(phase * pi * 2 + depth * 1.2) * 0.05 * (depth + 1);
final naturalAngle = angle + sway;

final end = Offset(
  start.dx + cos(naturalAngle) * length,
  start.dy + sin(naturalAngle) * length,
);
```

## Interaction Flow
1.  **User Tap**: The user taps a glowing node.
2.  **Hit Test**: The `GestureDetector` at that position intercepts the touch.
3.  **Action**: The app navigates to `FileViewer(file)` using the file metadata associated with that specific node index.
