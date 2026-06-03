import 'package:flutter/material.dart';
import 'models.dart';

class MagnifierView extends StatelessWidget {
  final TransformationController transformationController;
  final PaintTool activeTool;
  final Widget child;

  const MagnifierView({
    super.key,
    required this.transformationController,
    required this.activeTool,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: transformationController,
      boundaryMargin: const EdgeInsets.all(500),
      minScale: 0.1,
      maxScale: 10.0,
      panEnabled: activeTool == PaintTool.magnifier,
      scaleEnabled: activeTool == PaintTool.magnifier,
      child: child,
    );
  }
}