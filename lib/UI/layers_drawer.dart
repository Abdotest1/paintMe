import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../core/models.dart';

class LayersDrawer extends StatefulWidget {
  final List<PaintLayer> layers;
  final int activeLayerIndex;
  final bool isBgLayerVisible;
  final Color bgLayerColor;

  final VoidCallback onAddLayer;
  final Function(int oldIndex, int newIndex) onReorderLayers;
  final Function(int) onToggleLayerVisibility;
  final Function(int) onDeleteLayer;
  final Function(int) onSelectLayer;
  final Function(int, String) onRenameLayer;
  final VoidCallback onToggleBgVisibility;
  final Function(Color) onChangeBgColor;

  const LayersDrawer({
    super.key,
    required this.layers,
    required this.activeLayerIndex,
    required this.isBgLayerVisible,
    required this.bgLayerColor,
    required this.onAddLayer,
    required this.onReorderLayers,
    required this.onToggleLayerVisibility,
    required this.onDeleteLayer,
    required this.onSelectLayer,
    required this.onRenameLayer,
    required this.onToggleBgVisibility,
    required this.onChangeBgColor,
  });

  @override
  State<LayersDrawer> createState() => _LayersDrawerState();
}

class _LayersDrawerState extends State<LayersDrawer> {
  void _editLayerName(BuildContext context, int index) {
    TextEditingController nameCtrl = TextEditingController(text: widget.layers[index].name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rename Layer"),
        content: TextField(controller: nameCtrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: () {
            widget.onRenameLayer(index, nameCtrl.text.trim().isEmpty ? "Layer" : nameCtrl.text.trim());
            Navigator.pop(context);
          }, child: const Text("Save")),
        ],
      ),
    );
  }

  void _showBackgroundColorPicker(BuildContext context) {
    Color tempPickerColor = widget.bgLayerColor;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Background Color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: tempPickerColor,
              onColorChanged: (Color color) => tempPickerColor = color,
            ),
          ),
          actions: <Widget>[
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
            ElevatedButton(child: const Text('Apply'), onPressed: () {
              widget.onChangeBgColor(tempPickerColor);
              Navigator.pop(context);
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 300,
      child: Column(
        children: [
          AppBar(
              title: const Text('Layers'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(icon: const Icon(Icons.add), onPressed: widget.onAddLayer)
              ]
          ),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: widget.layers.length,
              onReorder: widget.onReorderLayers,
              itemBuilder: (ctx, i) => ListTile(
                key: ValueKey(widget.layers[i]),
                tileColor: widget.activeLayerIndex == i ? Theme.of(context).primaryColor.withOpacity(0.15) : null,
                leading: IconButton(
                    icon: Icon(widget.layers[i].isVisible ? Icons.visibility : Icons.visibility_off,
                    color: widget.activeLayerIndex == i ? Theme.of(context).primaryColor : null),
                    onPressed: () => widget.onToggleLayerVisibility(i)
                ),
                title: Text(widget.layers[i].name, style: TextStyle(
                  fontWeight: widget.activeLayerIndex == i ? FontWeight.bold : FontWeight.normal,
                  color: widget.activeLayerIndex == i ? Theme.of(context).primaryColor : null,
                )),
                trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => widget.onDeleteLayer(i)
                ),
                onTap: () {
                  widget.onSelectLayer(i);
                  Navigator.pop(ctx);
                },
                onLongPress: () => _editLayerName(context, i),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Container(
            color: Theme.of(context).cardColor,
            child: ListTile(
              leading: IconButton(
                  icon: Icon(widget.isBgLayerVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: widget.onToggleBgVisibility
              ),
              title: const Text("Background", style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
              trailing: IconButton(
                  icon: Icon(Icons.palette, color: widget.bgLayerColor, shadows: const [Shadow(color: Colors.black45, blurRadius: 4)]),
                  onPressed: () => _showBackgroundColorPicker(context)
              ),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}