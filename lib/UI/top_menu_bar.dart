import 'package:flutter/material.dart';

class TopMenuBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isDarkMode;
  final bool isNetworkActive;
  final bool isHost;
  final bool isProcessing;
  final bool canUndo;
  final bool canRedo;

  final VoidCallback onToggleTheme;
  final VoidCallback onShowNetworkSheet;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onOpenLayers;
  final VoidCallback onLoadImage;
  final VoidCallback onSaveImage;
  final VoidCallback onResizeCanvas;

  const TopMenuBar({
    super.key,
    required this.isDarkMode,
    required this.isNetworkActive,
    required this.isHost,
    required this.isProcessing,
    required this.canUndo,
    required this.canRedo,
    required this.onToggleTheme,
    required this.onShowNetworkSheet,
    required this.onUndo,
    required this.onRedo,
    required this.onOpenLayers,
    required this.onLoadImage,
    required this.onSaveImage,
    required this.onResizeCanvas,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: MediaQuery.of(context).size.width > 550 ? const Text('Paint me', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)) : null,
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
      actions: [
        IconButton(
          icon: Icon(
            isNetworkActive ? (isHost ? Icons.cell_tower : Icons.cast_connected) : Icons.cast,
            color: isNetworkActive ? Colors.greenAccent : Theme.of(context).iconTheme.color,
          ),
          tooltip: "Network Sync",
          onPressed: isProcessing ? null : onShowNetworkSheet,
        ),
        IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode, color: isDarkMode ? Theme.of(context).primaryColor : null),
            onPressed: isProcessing ? null : onToggleTheme
        ),
        const VerticalDivider(width: 20, indent: 15, endIndent: 15, color: Colors.white10),
        IconButton(
            icon: const Icon(Icons.undo),
            onPressed: isProcessing || !canUndo ? null : onUndo
        ),
        IconButton(
            icon: const Icon(Icons.redo),
            onPressed: isProcessing || !canRedo ? null : onRedo
        ),
        IconButton(
            icon: const Icon(Icons.layers),
            onPressed: isProcessing ? null : onOpenLayers
        ),
        PopupMenuButton<String>(
          enabled: !isProcessing,
          icon: const Icon(Icons.more_vert),
          tooltip: "More Options",
          onSelected: (value) {
            if (value == 'load') onLoadImage();
            else if (value == 'save') onSaveImage();
            else if (value == 'resize') onResizeCanvas();
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
                value: 'load',
                child: Row(children: [Icon(Icons.file_upload, color: Theme.of(context).primaryColor, size: 20), const SizedBox(width: 12), const Text('Load Image')])
            ),
            PopupMenuItem<String>(
                value: 'save',
                child: Row(children: [Icon(Icons.save, color: Theme.of(context).primaryColor, size: 20), const SizedBox(width: 12), const Text('Save Image')])
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
                value: 'resize',
                child: Row(children: [Icon(Icons.aspect_ratio, color: Theme.of(context).primaryColor, size: 20), const SizedBox(width: 12), const Text('Resize Canvas')])
            ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}