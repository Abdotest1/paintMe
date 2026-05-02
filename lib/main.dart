import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

void main() => runApp(const MaterialApp(
  home: PaintMe(),
  debugShowCheckedModeBanner: false,
));

enum Tool { brush, eraser, fill }

class PaintMe extends StatefulWidget {
  const PaintMe({super.key});

  @override
  State<PaintMe> createState() => _PaintMeState();
}

class _PaintMeState extends State<PaintMe> {
  // --- STATE ---
  Tool selectedTool = Tool.brush;
  Color selectedColor = Colors.black;
  double brushSize = 8;
  ui.Image? staticImage;
  List<Offset> currentPath = [];
  Size? canvasSize;

  // --- CANVAS INIT ---
  Future<void> _initCanvas(Size size) async {
    canvasSize = size;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.white);
    final picture = recorder.endRecording();
    staticImage = await picture.toImage(size.width.toInt(), size.height.toInt());
    setState(() {});
  }

  // --- DRAWING LOGIC ---
  Future<void> _commitPath() async {
    if (staticImage == null || canvasSize == null || currentPath.isEmpty) return;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(staticImage!, Offset.zero, Paint());

    final paint = Paint()
      ..color = selectedTool == Tool.eraser ? Colors.white : selectedColor
      ..strokeWidth = brushSize
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(currentPath.first.dx, currentPath.first.dy);
    for (var point in currentPath) { path.lineTo(point.dx, point.dy); }
    canvas.drawPath(path, paint);

    final picture = recorder.endRecording();
    staticImage = await picture.toImage(canvasSize!.width.toInt(), canvasSize!.height.toInt());
    currentPath.clear();
    setState(() {});
  }

  // --- FAST FILL ---
  Future<void> _floodFill(Offset pos) async {
    if (staticImage == null) return;
    final byteData = await staticImage!.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return;

    final Uint8List pixels = byteData.buffer.asUint8List();
    final int width = staticImage!.width;
    final int height = staticImage!.height;
    int getOffset(int x, int y) => (y * width + x) * 4;
    final int startOffset = getOffset(pos.dx.toInt(), pos.dy.toInt());

    final int tr = pixels[startOffset], tg = pixels[startOffset + 1], tb = pixels[startOffset + 2], ta = pixels[startOffset + 3];
    final int fr = selectedColor.red, fg = selectedColor.green, fb = selectedColor.blue, fa = 255;

    if (tr == fr && tg == fg && tb == fb && ta == fa) return;

    final Queue<int> queue = Queue<int>()..add(pos.dx.toInt())..add(pos.dy.toInt());
    while (queue.isNotEmpty) {
      int x = queue.removeFirst(), y = queue.removeFirst();
      int cur = getOffset(x, y);
      while (y >= 0 && _match(pixels, cur, tr, tg, tb, ta)) { y--; cur -= width * 4; }
      y++; cur += width * 4;
      bool rL = false, rR = false;
      while (y < height && _match(pixels, cur, tr, tg, tb, ta)) {
        pixels[cur] = fr; pixels[cur + 1] = fg; pixels[cur + 2] = fb; pixels[cur + 3] = fa;
        if (x > 0) {
          if (_match(pixels, cur - 4, tr, tg, tb, ta)) { if (!rL) { queue.add(x - 1); queue.add(y); rL = true; } }
          else { rL = false; }
        }
        if (x < width - 1) {
          if (_match(pixels, cur + 4, tr, tg, tb, ta)) { if (!rR) { queue.add(x + 1); queue.add(y); rR = true; } }
          else { rR = false; }
        }
        y++; cur += width * 4;
      }
    }
    ui.decodeImageFromPixels(pixels, width, height, ui.PixelFormat.rgba8888, (img) => setState(() => staticImage = img));
  }

  bool _match(Uint8List p, int o, int r, int g, int b, int a) => p[o] == r && p[o+1] == g && p[o+2] == b && p[o+3] == a;

  // --- COLOR PICKER ---
  void _pickColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: selectedColor,
            onColorChanged: (c) => setState(() => selectedColor = c),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(title: const Text("PaintMe"), elevation: 1, backgroundColor: Colors.white, foregroundColor: Colors.black),
      body: LayoutBuilder(builder: (context, constraints) {
        if (staticImage == null) _initCanvas(Size(constraints.maxWidth, constraints.maxHeight));
        return GestureDetector(
          onPanStart: (d) => selectedTool == Tool.fill ? _floodFill(d.localPosition) : setState(() => currentPath = [d.localPosition]),
          onPanUpdate: (d) => selectedTool == Tool.fill ? null : setState(() => currentPath.add(d.localPosition)),
          onPanEnd: (d) => _commitPath(),
          child: CustomPaint(
            painter: MainPainter(staticImage: staticImage, currentPath: currentPath, color: selectedTool == Tool.eraser ? Colors.white : selectedColor, size: brushSize),
            size: Size.infinite,
          ),
        );
      }),
      bottomNavigationBar: _buildToolbar(),
    );
  }

  Widget _buildToolbar() {
    return BottomAppBar(
      height: 80,
      child: Row(
        children: [
          // THE COLOR BUTTON
          GestureDetector(
            onTap: _pickColor,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selectedColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: const Icon(Icons.colorize, color: Colors.white, size: 20),
            ),
          ),
          const VerticalDivider(width: 20, indent: 10, endIndent: 10),
          // TOOLS
          _toolIcon(Icons.brush, Tool.brush),
          _toolIcon(Icons.cleaning_services, Tool.eraser),
          _toolIcon(Icons.format_color_fill, Tool.fill),
          // SIZE SLIDER
          Expanded(child: Slider(value: brushSize, min: 1, max: 30, activeColor: selectedColor, onChanged: (v) => setState(() => brushSize = v))),
          Text("${brushSize.toInt()}px"),
        ],
      ),
    );
  }

  Widget _toolIcon(IconData icon, Tool tool) => IconButton(
    icon: Icon(icon, color: selectedTool == tool ? Colors.blue : Colors.black54),
    onPressed: () => setState(() => selectedTool = tool),
  );
}

class MainPainter extends CustomPainter {
  final ui.Image? staticImage;
  final List<Offset> currentPath;
  final Color color;
  final double size;
  MainPainter({this.staticImage, required this.currentPath, required this.color, required this.size});

  @override
  void paint(Canvas canvas, Size size) {
    if (staticImage != null) canvas.drawImage(staticImage!, Offset.zero, Paint());
    if (currentPath.isNotEmpty) {
      final paint = Paint()..color = color..strokeWidth = this.size..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..style = PaintingStyle.stroke;
      final path = Path()..moveTo(currentPath.first.dx, currentPath.first.dy);
      for (var p in currentPath) { path.lineTo(p.dx, p.dy); }
      canvas.drawPath(path, paint);
    }
  }
  @override
  bool shouldRepaint(MainPainter old) => true;
}