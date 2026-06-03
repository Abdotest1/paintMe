import 'package:flutter/material.dart';
import '../core/models.dart';

// ==========================================
// --- TOP BAR REMOTE CONTROLLER ---
// ==========================================
class TopBarRemoteController extends StatelessWidget {
  final bool isDarkMode;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onLoadImage;
  final VoidCallback onSaveImage;
  final VoidCallback onResizeCanvas;
  final VoidCallback onOpenLayers;
  final VoidCallback onToggleTheme; // 👈 Callback added here
  final VoidCallback onDisconnect;

  const TopBarRemoteController({
    super.key,
    required this.isDarkMode,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.onLoadImage,
    required this.onSaveImage,
    required this.onResizeCanvas,
    required this.onOpenLayers,
    required this.onToggleTheme,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Top Bar Controller"),
        actions: [
          IconButton(icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode), onPressed: onToggleTheme),
          IconButton(icon: const Icon(Icons.power_settings_new), onPressed: onDisconnect)
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          children: [
            _buildActionCard(context, Icons.undo, "Undo", canUndo ? onUndo : null),
            _buildActionCard(context, Icons.redo, "Redo", canRedo ? onRedo : null),
            _buildActionCard(context, Icons.file_upload, "Load Image", onLoadImage),
            _buildActionCard(context, Icons.save, "Save Image", onSaveImage),
            _buildActionCard(context, Icons.aspect_ratio, "Resize Canvas", onResizeCanvas),
            _buildActionCard(context, Icons.layers, "Layers", onOpenLayers),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, IconData icon, String label, VoidCallback? onTap) {
    final bool isEnabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black45 : Colors.black12,
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
          border: isDarkMode ? Border.all(color: Colors.white10) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: isEnabled ? Theme.of(context).primaryColor : Theme.of(context).disabledColor),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isEnabled ? Theme.of(context).textTheme.bodyLarge?.color : Theme.of(context).disabledColor,
            )),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// --- BOTTOM BAR REMOTE CONTROLLER ---
// ==========================================
class BottomBarRemoteController extends StatelessWidget {
  final bool isDarkMode;
  final PaintTool activeTool;
  final double strokeWidth;
  final Color selectedColor;

  final Function(PaintTool) onSetTool;
  final Function(double) onSetStrokeWidth;
  final VoidCallback onShowColorPicker;
  final VoidCallback onShowBrushes;
  final VoidCallback onShowShapes;
  final VoidCallback onShowSelection;
  final VoidCallback onShowAiTools;
  final VoidCallback onToggleTheme; // 👈 Callback added here
  final VoidCallback onDisconnect;

  const BottomBarRemoteController({
    super.key,
    required this.isDarkMode,
    required this.activeTool,
    required this.strokeWidth,
    required this.selectedColor,
    required this.onSetTool,
    required this.onSetStrokeWidth,
    required this.onShowColorPicker,
    required this.onShowBrushes,
    required this.onShowShapes,
    required this.onShowSelection,
    required this.onShowAiTools,
    required this.onToggleTheme,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Tools Controller"),
        actions: [
          IconButton(icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode), onPressed: onToggleTheme),
          IconButton(icon: const Icon(Icons.power_settings_new), onPressed: onDisconnect)
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.line_weight, color: Theme.of(context).iconTheme.color),
                        Expanded(child: Slider(value: strokeWidth, min: 1, max: 80, onChanged: onSetStrokeWidth, activeColor: Theme.of(context).primaryColor)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.color_lens),
                      label: const Text("Color Picker"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedColor,
                        foregroundColor: selectedColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: onShowColorPicker,
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildToolButton(context, Icons.brush, PaintTool.freehand, "Brush", onTapOverride: onShowBrushes),
                  _buildToolButton(context, Icons.auto_fix_high, PaintTool.eraser, "Eraser"),
                  _buildToolButton(context, Icons.format_color_fill, PaintTool.bucket, "Bucket"),
                  _buildToolButton(context, Icons.text_fields, PaintTool.text, "Text"),
                  _buildToolButton(context, Icons.colorize, PaintTool.eyedropper, "Picker"),
                  _buildToolButton(context, Icons.blur_on, PaintTool.spray, "Spray"),
                  _buildToolButton(context, Icons.category, PaintTool.rectangle, "Shapes", onTapOverride: onShowShapes),
                  _buildToolButton(context, Icons.select_all, PaintTool.selection, "Select", onTapOverride: onShowSelection),
                  _buildToolButton(context, Icons.smart_toy, PaintTool.aiErase, "AI Tools", onTapOverride: onShowAiTools),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton(BuildContext context, IconData icon, PaintTool tool, String label, {VoidCallback? onTapOverride}) {
    bool isActive = activeTool == tool;
    return InkWell(
      onTap: onTapOverride ?? () => onSetTool(tool),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? Theme.of(context).primaryColor.withOpacity(0.15) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isActive ? Theme.of(context).primaryColor : Colors.white10, width: isActive ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black45 : Colors.black12,
              blurRadius: 5,
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: isActive ? Theme.of(context).primaryColor : Theme.of(context).iconTheme.color),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isActive ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyMedium?.color,
            )),
          ],
        ),
      ),
    );
  }
}