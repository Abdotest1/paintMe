import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../core/models.dart';

class BottomToolsBar extends StatelessWidget {
  final bool isDarkMode;
  final PaintTool activeTool;
  final bool isProcessing;
  final String selectionMode;
  final double strokeWidth;
  final Color selectedColor;

  final Function(PaintTool) onToolSelected;
  final Function(double) onStrokeWidthChanged;
  final Function(String) onSelectionModeChanged;
  final VoidCallback showBrushesSheet;
  final VoidCallback showShapesSheet;
  final VoidCallback showSelectionSheet;
  final VoidCallback showAiToolsSheet;
  final VoidCallback onAiEraseStroke;
  final VoidCallback onClearAiErase;
  final VoidCallback onShowColorPicker;

  const BottomToolsBar({
    super.key,
    required this.isDarkMode,
    required this.activeTool,
    required this.isProcessing,
    required this.selectionMode,
    required this.strokeWidth,
    required this.selectedColor,
    required this.onToolSelected,
    required this.onStrokeWidthChanged,
    required this.onSelectionModeChanged,
    required this.showBrushesSheet,
    required this.showShapesSheet,
    required this.showSelectionSheet,
    required this.showAiToolsSheet,
    required this.onAiEraseStroke,
    required this.onClearAiErase,
    required this.onShowColorPicker,
  });

  bool _isShapeTool() => [
    PaintTool.line, PaintTool.rectangle, PaintTool.roundedRectangle, PaintTool.circle,
    PaintTool.triangle, PaintTool.diamond, PaintTool.star, PaintTool.heart,
    PaintTool.pentagon, PaintTool.hexagon, PaintTool.cross, PaintTool.arrowRight
  ].contains(activeTool);

  bool _isSelectionTool() => [
    PaintTool.selection, PaintTool.selectionCircle, PaintTool.selectionFree, PaintTool.magicWand
  ].contains(activeTool);

  IconData _getSelectionIcon() {
    switch (activeTool) {
      case PaintTool.selectionCircle: return Icons.circle_outlined;
      case PaintTool.selectionFree: return CupertinoIcons.scribble;
      case PaintTool.magicWand: return Icons.auto_fix_normal;
      default: return Icons.select_all;
    }
  }

  Widget _toolButton(BuildContext context, IconData icon, PaintTool tool, String t) {
    bool act = activeTool == tool;
    return IconButton(
      // Uses the active theme's primary color if selected, otherwise uses the theme's default icon color
      icon: Icon(icon, color: act ? Theme.of(context).colorScheme.primary : Theme.of(context).iconTheme.color),
      tooltip: t,
      onPressed: () => onToolSelected(tool),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the default icon color for the current theme
    final Color? defaultIconColor = Theme.of(context).iconTheme.color;
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(8.0),
      // Automatically uses a proper dark/light background color based on the theme
      color: Theme.of(context).cardColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: Icon(Icons.brush, color: activeTool == PaintTool.freehand ? primaryColor : defaultIconColor), onPressed: showBrushesSheet),
                IconButton(icon: Icon(Icons.category, color: _isShapeTool() ? primaryColor : defaultIconColor), onPressed: showShapesSheet),
                _toolButton(context, Icons.format_color_fill, PaintTool.bucket, "Fill"),
                _toolButton(context, Icons.colorize, PaintTool.eyedropper, "Picker"),
                IconButton(icon: Icon(_getSelectionIcon(), color: _isSelectionTool() ? primaryColor : defaultIconColor), onPressed: showSelectionSheet),
                _toolButton(context, Icons.text_fields, PaintTool.text, "Text"),
                _toolButton(context, Icons.blur_on, PaintTool.spray, "Spray"),
                _toolButton(context, Icons.auto_fix_high, PaintTool.eraser, "Eraser"),
                // 👇 RE-IMPLEMENTED: Magnifying Glass tool for Zooming and Panning
                _toolButton(context, Icons.search, PaintTool.magnifier, "Zoom & Pan"),
                IconButton(icon: Icon(Icons.smart_toy, color: defaultIconColor), onPressed: isProcessing ? null : showAiToolsSheet),
                if (activeTool == PaintTool.aiErase) ...[
                  IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: isProcessing ? null : onAiEraseStroke),
                  IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.red), onPressed: onClearAiErase),
                ],
                if (_isSelectionTool()) ...[
                  IconButton(icon: Icon(Icons.add_circle_outline, color: selectionMode == "add" ? primaryColor : Theme.of(context).disabledColor), onPressed: () => onSelectionModeChanged("add")),
                  IconButton(icon: Icon(Icons.remove_circle_outline, color: selectionMode == "subtract" ? primaryColor : Theme.of(context).disabledColor), onPressed: () => onSelectionModeChanged("subtract")),
                ],
              ],
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: onShowColorPicker,
                child: Container(
                  margin: const EdgeInsets.only(left: 8.0, right: 12.0),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selectedColor, // Shows the currently selected color
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                        width: 2
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                    ],
                  ),
                ),
              ),

              Icon(Icons.line_weight, size: 20, color: defaultIconColor),
              Expanded(child: Slider(value: strokeWidth, min: 1, max: 80, onChanged: onStrokeWidthChanged)),
              Container(width: 30, height: 30, decoration: BoxDecoration(color: selectedColor, shape: BoxShape.circle, border: Border.all(color: Colors.grey))),
            ],
          ),
        ],
      ),
    );
  }
}