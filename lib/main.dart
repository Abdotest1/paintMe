import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/services.dart';

//CORE
import 'core/models.dart';
import 'core/painter.dart';
import 'core/bucket_fill.dart';
import 'core/image_utils.dart';
import 'core/magnifier_view.dart';
import 'core/magic_wand.dart';
import 'core/ai_image_service.dart';
import 'core/network_manager.dart';

//UI COMPONENTS
import 'ui/bottom_tools_bar.dart';
import 'ui/top_menu_bar.dart';
import 'ui/layers_drawer.dart';
import 'ui/remote_controllers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const UltimatePaintApp());
}

class UltimatePaintApp extends StatefulWidget {
  const UltimatePaintApp({super.key});

  @override
  State<UltimatePaintApp> createState() => _UltimatePaintAppState();
}

class _UltimatePaintAppState extends State<UltimatePaintApp> {
  bool isDarkMode = false;

  void toggleTheme([bool? forceState]) {
    setState(() {
      isDarkMode = forceState ?? !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Paint me',
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.blue,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFFFFD700), // Pure Gold
        scaffoldBackgroundColor: const Color(0xFF0A0A0A), // Deep Black
        canvasColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD700),
          secondary: Color(0xFFDAA520), // Goldenrod
          surface: Color(0xFF1E1E1E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          foregroundColor: Color(0xFFFFD700),
          elevation: 0,
        ),
        dividerColor: Colors.white10,
      ),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: PaintWorkspace(
        isDarkMode: isDarkMode,
        toggleTheme: toggleTheme,
      ),
    );
  }
}

class PaintWorkspace extends StatefulWidget {
  final bool isDarkMode;
  final void Function([bool?]) toggleTheme; // 👇 Update this line

  const PaintWorkspace({
    super.key,
    required this.isDarkMode,
    required this.toggleTheme,
  });

  @override
  State<PaintWorkspace> createState() => _PaintWorkspaceState();
}

class _PaintWorkspaceState extends State<PaintWorkspace> {
  final TransformationController _transformationController = TransformationController();
  final TextEditingController _textEditingController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  final NetworkManager _networkManager = NetworkManager();
  bool _isSearchingNetwork = false;
  bool _isNetworkActive = false;
  Map<String, String> _discoveredHosts = {};

  double _zoomLevel = 1.0;

  List<PaintLayer> layers = [PaintLayer(name: 'Layer 1')];
  int activeLayerIndex = 0;
  PaintLayer get activeLayer => layers[activeLayerIndex];

  bool isBgLayerVisible = true;
  Color bgLayerColor = Colors.white;

  DrawingAction? currentAction;
  ui.Image? backgroundImage;

  PaintTool activeTool = PaintTool.freehand;
  BrushType activeBrush = BrushType.solid;
  Color selectedColor = Colors.black;
  double strokeWidth = 5.0;
  final Color backgroundColor = Colors.white;

  String selectedFont = 'Arial';
  final List<String> availableFonts = ['Arial', 'Courier New', 'Times New Roman', 'Comic Sans MS'];

  final GlobalKey _canvasKey = GlobalKey();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Random _random = Random();

  double canvasWidth = 350;
  double canvasHeight = 500;
  bool _isCanvasInitialized = false;
  bool _isProcessing = false;

  final List<List<PaintLayer>> _layersHistory = [];
  final List<Size> _canvasSizeHistory = [];
  final List<ui.Image?> _backgroundHistory = [];

  int? editingActionIndex;
  String _textDragMode = "none";
  String _selectionMode = "add";
  String _magicWandMode = "smart";
  List<Offset> aiErasePoints = [];

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(() {
      setState(() {
        _zoomLevel = _transformationController.value.getMaxScaleOnAxis();
      });
    });

    _networkManager.onConnectionChanged = () {
      if (mounted) {
        setState(() {});

        if (_networkManager.isHost) {
          _networkManager.broadcast({
            'type': 'resize_canvas',
            'width': canvasWidth,
            'height': canvasHeight
          });
          _networkManager.broadcast({'type': 'theme', 'isDarkMode': widget.isDarkMode});
        }
      }
    };

    _networkManager.onMessageReceived = (data) {
      if (!mounted) return;
      setState(() {
        try {
          switch (data['type']) {
            case 'tool_change':
              activeTool = PaintTool.values.firstWhere((e) => e.name == data['tool']);
              break;
            case 'brush_change':
              activeBrush = BrushType.values.firstWhere((e) => e.name == data['brush']);
              break;
            case 'color_change':
              selectedColor = Color(data['color']);
              break;
            case 'stroke_width_change':
              strokeWidth = data['width'].toDouble();
              break;
            case 'draw_action':
              activeLayer.history.add(DrawingAction.fromMap(data['action']));
              break;
            case 'resize_canvas':
              _updateCanvasSize(data['width'].toDouble(), data['height'].toDouble(), sync: false);
              break;
            case 'add_layer':
              _addLayer(sync: false);
              break;
            case 'delete_layer':
              _deleteLayer(data['index'], sync: false);
              break;
            case 'select_layer':
              _selectLayer(data['index'], sync: false);
              break;
            case 'toggle_layer_visibility':
              _toggleLayerVisibility(data['index'], sync: false);
              break;
            case 'reorder_layers':
              _reorderLayers(data['oldIndex'], data['newIndex'], sync: false);
              break;
            case 'rename_layer':
              _renameLayer(data['index'], data['name'], sync: false);
              break;
            case 'toggle_bg_visibility':
              _toggleBgVisibility(sync: false);
              break;
            case 'change_bg_color':
              _changeBgColor(Color(data['color']), sync: false);
              break;
            case 'theme':
              widget.toggleTheme(data['isDarkMode']);
              break;
            case 'command':
              final action = data['action'];
              if (action == 'undo') _performLocalUndo();
              else if (action == 'redo') _performLocalRedo();
              else if (action == 'load') _handleLoadImage();
              else if (action == 'save') _handleSaveImage();
              break;
          }
        } catch (e) {
          debugPrint("Network Sync Parse Error: $e");
        }
      });
    };
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _textEditingController.dispose();
    _textFocusNode.dispose();
    _networkManager.shutdown();
    super.dispose();
  }

  // --- NETWORK SYNCHRONIZED CORE ACTIONS ---
  void _setTool(PaintTool tool) {
    setState(() => activeTool = tool);
    if (_isNetworkActive) _networkManager.broadcast({'type': 'tool_change', 'tool': tool.name});
  }

  void _setBrush(BrushType brush, {bool sync = true}) {
    setState(() => activeBrush = brush);
    if (sync && _isNetworkActive) _networkManager.broadcast({'type': 'brush_change', 'brush': brush.name});
  }

  void _setColor(Color color) {
    setState(() => selectedColor = color);
    if (_isNetworkActive) _networkManager.broadcast({'type': 'color_change', 'color': color.value});
  }

  void _setStrokeWidth(double width) {
    setState(() => strokeWidth = width);
    if (_isNetworkActive) _networkManager.broadcast({'type': 'stroke_width_change', 'width': width});
  }

  void _updateCanvasSize(double width, double height, {bool sync = true}) {
    setState(() {
      canvasWidth = width;
      canvasHeight = height;
    });
    if (sync && _isNetworkActive) {
      _networkManager.broadcast({'type': 'resize_canvas', 'width': width, 'height': height});
    }
  }

  void _addLayer({bool sync = true}) {
    setState(() {
      layers.add(PaintLayer(name: 'Layer ${layers.length + 1}'));
      activeLayerIndex = layers.length - 1;
    });
    if (sync && _isNetworkActive) _networkManager.broadcast({'type': 'add_layer'});
  }

  void _deleteLayer(int i, {bool sync = true}) {
    if (layers.length > 1) {
      setState(() {
        layers.removeAt(i);
        if (activeLayerIndex >= layers.length) activeLayerIndex = layers.length - 1;
      });
      if (sync && _isNetworkActive) _networkManager.broadcast({'type': 'delete_layer', 'index': i});
    }
  }

  void _selectLayer(int i, {bool sync = true}) {
    setState(() => activeLayerIndex = i);
    if (sync && _isNetworkActive) _networkManager.broadcast({'type': 'select_layer', 'index': i});
  }

  void _toggleLayerVisibility(int i, {bool sync = true}) {
    setState(() => layers[i].isVisible = !layers[i].isVisible);
    if (sync && _isNetworkActive) _networkManager.broadcast({'type': 'toggle_layer_visibility', 'index': i});
  }

  void _reorderLayers(int oldIdx, int newIdx, {bool sync = true}) {
    setState(() {
      if (newIdx > oldIdx) newIdx -= 1;
      final item = layers.removeAt(oldIdx);
      layers.insert(newIdx, item);
      activeLayerIndex = layers.indexOf(item);
    });
    if (sync && _isNetworkActive) _networkManager.broadcast({'type': 'reorder_layers', 'oldIndex': oldIdx, 'newIndex': newIdx});
  }

  void _renameLayer(int i, String newName, {bool sync = true}) {
    setState(() => layers[i].name = newName);
    if (sync && _isNetworkActive) _networkManager.broadcast({'type': 'rename_layer', 'index': i, 'name': newName});
  }

  void _toggleBgVisibility({bool sync = true}) {
    setState(() => isBgLayerVisible = !isBgLayerVisible);
    if (sync && _isNetworkActive) _networkManager.broadcast({'type': 'toggle_bg_visibility'});
  }

  void _changeBgColor(Color color, {bool sync = true}) {
    setState(() => bgLayerColor = color);
    if (sync && _isNetworkActive) _networkManager.broadcast({'type': 'change_bg_color', 'color': color.value});
  }

  void _sendCommand(String action) {
    if (_isNetworkActive) _networkManager.broadcast({'type': 'command', 'action': action});
  }

  void _resetZoom() {
    setState(() {
      _transformationController.value = Matrix4.identity();
      _zoomLevel = 1.0;
    });
  }

  void _commitEditing() {
    if (editingActionIndex != null) {
      setState(() {
        final index = editingActionIndex!;
        if (index >= 0 && index < activeLayer.history.length) {
          final action = activeLayer.history[index];

          if (action.tool == PaintTool.text) {
            if (action.text == null || action.text!.trim().isEmpty) {
              activeLayer.history.removeAt(index);
            } else {
              activeLayer.history[index] = action.copyWith(isEditing: false);
            }
          } else {
            if (action.startPoint != null && action.endPoint != null) {
              final rect = Rect.fromPoints(action.startPoint!, action.endPoint!);
              if (rect.right < 0 || rect.left > canvasWidth || rect.bottom < 0 || rect.top > canvasHeight) {
                activeLayer.history[index] = action.copyWith(
                  isEditing: false,
                  isLifted: true,
                  clearRasterImage: true,
                );
              } else {
                activeLayer.history[index] = action.copyWith(isEditing: false);
              }
            } else {
              activeLayer.history[index] = action.copyWith(isEditing: false);
            }
          }
        }
        editingActionIndex = null;
        _textFocusNode.unfocus();
      });
    }
  }

  void _saveWorkspaceState() {
    _layersHistory.add(layers.map((l) => l.copy()).toList());
    _canvasSizeHistory.add(Size(canvasWidth, canvasHeight));
    _backgroundHistory.add(backgroundImage);
  }

  void undo() {
    _performLocalUndo();
    _sendCommand('undo');
  }

  void _performLocalUndo() {
    _commitEditing();
    if (activeLayer.history.isNotEmpty && activeLayer.history.last.isCrop) {
      setState(() {
        activeLayer.history.removeLast();
        layers = _layersHistory.removeLast();
        final prevSize = _canvasSizeHistory.removeLast();
        canvasWidth = prevSize.width;
        canvasHeight = prevSize.height;
        backgroundImage = _backgroundHistory.removeLast();
      });
      return;
    }
    if (activeLayer.history.isNotEmpty) {
      setState(() => activeLayer.redoStack.add(activeLayer.history.removeLast()));
    } else if (_layersHistory.isNotEmpty) {
      setState(() {
        layers = _layersHistory.removeLast();
        final prevSize = _canvasSizeHistory.removeLast();
        canvasWidth = prevSize.width;
        canvasHeight = prevSize.height;
        backgroundImage = _backgroundHistory.removeLast();
      });
    }
  }

  void redo() {
    _performLocalRedo();
    _sendCommand('redo');
  }

  void _performLocalRedo() {
    _commitEditing();
    if (activeLayer.redoStack.isNotEmpty) {
      setState(() => activeLayer.history.add(activeLayer.redoStack.removeLast()));
    }
  }

  void clearActiveLayer() {
    setState(() {
      activeLayer.history.clear();
      activeLayer.redoStack.clear();
      currentAction = null;
    });
  }

  Future<void> _handleSelectionEnd(DrawingAction action) async {
    Rect rect;
    bool isMagicWand = action.isMagicWand;

    if (action.tool == PaintTool.selectionFree) {
      if (isMagicWand) {
        rect = action.selectionRect!;
      } else {
        if (action.points.length < 3) return;
        final path = Path()..moveTo(action.points.first.dx, action.points.first.dy);
        for (int i = 1; i < action.points.length; i++) {
          path.lineTo(action.points[i].dx, action.points[i].dy);
        }
        path.close();
        rect = path.getBounds();
      }
    } else {
      rect = Rect.fromPoints(action.startPoint!, action.endPoint!);
    }

    if (rect.width < 5 || rect.height < 5) return;

    final double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    setState(() {
      _isProcessing = true;
    });

    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    try {
      RenderRepaintBoundary boundary = _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image canvasImage = await boundary.toImage(pixelRatio: pixelRatio);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final double scaledWidth = rect.width * pixelRatio;
      final double scaledHeight = rect.height * pixelRatio;

      if (action.tool == PaintTool.selectionCircle) {
        canvas.clipPath(Path()..addOval(Rect.fromLTWH(0, 0, scaledWidth, scaledHeight)));
      } else if (action.tool == PaintTool.selectionFree) {
        if (isMagicWand) {
          final maskPaint = Paint()..color = Colors.black;
          canvas.saveLayer(Rect.fromLTWH(0, 0, scaledWidth, scaledHeight), Paint());

          final List<Offset> maskPoints = action.points
              .map((p) => Offset((p.dx - rect.left) * pixelRatio, (p.dy - rect.top) * pixelRatio))
              .toList();
          canvas.drawPoints(ui.PointMode.points, maskPoints, maskPaint..strokeWidth = pixelRatio * 1.5);

          canvas.saveLayer(null, Paint()..blendMode = ui.BlendMode.srcIn);
        } else {
          final localPath = Path();
          final first = action.points.first;
          localPath.moveTo((first.dx - rect.left) * pixelRatio, (first.dy - rect.top) * pixelRatio);
          for (int i = 1; i < action.points.length; i++) {
            final p = action.points[i];
            localPath.lineTo((p.dx - rect.left) * pixelRatio, (p.dy - rect.top) * pixelRatio);
          }
          localPath.close();
          canvas.clipPath(localPath);
        }
      }

      canvas.drawImageRect(
        canvasImage,
        Rect.fromLTWH(rect.left * pixelRatio, rect.top * pixelRatio, scaledWidth, scaledHeight),
        Rect.fromLTWH(0, 0, scaledWidth, scaledHeight),
        Paint()..isAntiAlias = true..filterQuality = ui.FilterQuality.high,
      );

      if (isMagicWand) {
        canvas.restore();
        canvas.restore();
      }

      final picture = recorder.endRecording();
      final croppedImage = await picture.toImage(scaledWidth.toInt(), scaledHeight.toInt());

      setState(() {
        final selectionAction = action.copyWith(
          selectionRect: rect,
          rasterImage: croppedImage,
          isEditing: true,
          isLifted: false,
          startPoint: rect.topLeft,
          endPoint: rect.bottomRight,
        );
        activeLayer.history.add(selectionAction);
        editingActionIndex = activeLayer.history.length - 1;
      });
    } catch (e) {
      debugPrint("Selection Error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _handleCropToSelection() {
    if (editingActionIndex == null) return;
    final action = activeLayer.history[editingActionIndex!];
    if (action.rasterImage == null || action.selectionRect == null) return;

    setState(() {
      _saveWorkspaceState();

      final Rect rect = action.selectionRect!;

      canvasWidth = rect.width;
      canvasHeight = rect.height;

      final List<Offset> shiftedPoints = action.points
          .map((p) => Offset(p.dx - rect.left, p.dy - rect.top))
          .toList();

      final croppedAction = action.copyWith(
        isEditing: false,
        isLifted: true,
        isCrop: true,
        startPoint: Offset.zero,
        endPoint: Offset(canvasWidth, canvasHeight),
        points: shiftedPoints,
        selectionRect: Rect.fromLTWH(0, 0, canvasWidth, canvasHeight),
      );

      activeLayer.history.clear();
      activeLayer.history.add(croppedAction);
      backgroundImage = null;
      editingActionIndex = null;

      _resetZoom();
    });
  }

  Future<void> _handleMagicWand(Offset tapPosition) async {
    if (_isProcessing) return;

    List<Offset> existingPoints = [];
    if (editingActionIndex != null) {
      final action = activeLayer.history[editingActionIndex!];
      if (action.tool == PaintTool.selectionFree) {
        existingPoints = action.points;
      }
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 60));
      RenderRepaintBoundary boundary = _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image canvasImage = await boundary.toImage(pixelRatio: 1.0);

      final result = await executeMagicWand(
        canvasImage: canvasImage,
        tapPosition: tapPosition,
      );

      if (result != null && mounted) {
        List<Offset> newPoints = [];
        final Offset roundedTap = Offset(tapPosition.dx.roundToDouble(), tapPosition.dy.roundToDouble());

        if (_magicWandMode == "smart") {
          newPoints = (result['points'] as List<Offset>).map((p) => Offset(p.dx.roundToDouble(), p.dy.roundToDouble())).toList();
        } else if (_magicWandMode == "pixel") {
          for (double x = -1; x <= 1; x++) {
            for (double y = -1; y <= 1; y++) {
              newPoints.add(roundedTap + Offset(x, y));
            }
          }
        } else if (_magicWandMode == "group") {
          final double radius = strokeWidth;
          for (double x = -radius; x <= radius; x++) {
            for (double y = -radius; y <= radius; y++) {
              if (x * x + y * y <= radius * radius) {
                newPoints.add(Offset((tapPosition.dx + x).roundToDouble(), (tapPosition.dy + y).roundToDouble()));
              }
            }
          }
        }

        List<Offset> combinedPoints;
        final Set<Offset> existingSet = existingPoints.map((p) => Offset(p.dx.roundToDouble(), p.dy.roundToDouble())).toSet();
        final Set<Offset> newSet = newPoints.toSet();

        if (_selectionMode == "add") {
          combinedPoints = existingSet.union(newSet).toList();
        } else {
          combinedPoints = existingSet.difference(newSet).toList();
        }

        if (combinedPoints.isEmpty) {
          setState(() {
            if (editingActionIndex != null) {
              activeLayer.history.removeAt(editingActionIndex!);
              editingActionIndex = null;
            }
          });
          return;
        }

        double minX = combinedPoints.first.dx;
        double maxX = combinedPoints.first.dx;
        double minY = combinedPoints.first.dy;
        double maxY = combinedPoints.first.dy;

        for (Offset p in combinedPoints) {
          if (p.dx < minX) minX = p.dx;
          if (p.dx > maxX) maxX = p.dx;
          if (p.dy < minY) minY = p.dy;
          if (p.dy > maxY) maxY = p.dy;
        }
        Rect combinedRect = Rect.fromLTRB(minX, minY, maxX + 1, maxY + 1);

        if (editingActionIndex != null) {
          activeLayer.history.removeAt(editingActionIndex!);
          editingActionIndex = null;
        }

        final action = DrawingAction(
          tool: PaintTool.selectionFree,
          isMagicWand: true,
          color: Colors.transparent,
          strokeWidth: 0,
          startPoint: combinedRect.topLeft,
          endPoint: combinedRect.bottomRight,
          points: combinedPoints,
          selectionRect: combinedRect,
        );

        await _handleSelectionEnd(action);
      }
    } catch (e) {
      debugPrint("Magic Wand Error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _handleEyedropper(Offset tapPosition) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      RenderRepaintBoundary boundary = _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image canvasImage = await boundary.toImage(pixelRatio: 1.0);
      ByteData? byteData = await canvasImage.toByteData(format: ui.ImageByteFormat.rawRgba);

      if (byteData != null) {
        final int x = tapPosition.dx.toInt().clamp(0, canvasImage.width - 1);
        final int y = tapPosition.dy.toInt().clamp(0, canvasImage.height - 1);
        final int index = (y * canvasImage.width + x) * 4;

        _setColor(Color.fromARGB(byteData.getUint8(index + 3), byteData.getUint8(index), byteData.getUint8(index + 1), byteData.getUint8(index + 2)));
        _setTool(PaintTool.freehand);
      }
    } catch (e) {
      debugPrint("Eyedropper Error: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleBucketFill(Offset tapPosition) async {
    if (_isProcessing || !activeLayer.isVisible) return;
    setState(() => _isProcessing = true);

    try {
      RenderRepaintBoundary boundary = _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image canvasImage = await boundary.toImage(pixelRatio: 1.0);

      ui.Image? resultImage = await executeBucketFill(
        canvasImage: canvasImage,
        tapPosition: tapPosition,
        selectedColor: selectedColor,
      );

      if (resultImage != null && mounted) {
        setState(() {
          activeLayer.redoStack.clear();
          final act = DrawingAction(
            tool: PaintTool.bucket,
            color: selectedColor,
            strokeWidth: 0,
            rasterImage: resultImage,
          );
          activeLayer.history.add(act);
          if (_isNetworkActive) _networkManager.broadcast({'type': 'draw_action', 'action': act.toMap()});
        });
      }
    } catch (e) {
      debugPrint("Bucket Fill Error: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleLoadImage() async {
    try {
      final ui.Image? image = await ImageUtils.pickImageFromGallery();
      if (image != null) setState(() => backgroundImage = image);
    } catch (e) {
      debugPrint("Error loading image: $e");
    }
  }

  Future<void> _handleRemoveBackground() async {
    if (backgroundImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please load a background image first.')));
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final bytes = await ImageUtils.imageToBytes(backgroundImage!);
      final processedBytes = await AiImageService.removeBackground(bytes);

      if (processedBytes != null) {
        final processedImage = await ImageUtils.bytesToImage(processedBytes);
        setState(() {
          backgroundImage = processedImage;
          _saveWorkspaceState();
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Background removed!')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to remove background. Check API key/balance.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleRemoveObject() async {
    if (backgroundImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please load image first')));
      return;
    }
    setState(() { _isProcessing = true; });
    try {
      final imageBytes = await ImageUtils.imageToBytes(backgroundImage!);
      final imageUrl = await AiImageService.uploadToCloudinary(imageBytes);
      if (imageUrl == null) throw Exception("Cloudinary upload failed");

      final aiUrl = AiImageService.generateRemoveUrl(imageUrl);
      final response = await http.get(Uri.parse(aiUrl));
      if (response.statusCode != 200) throw Exception("Failed to download AI image");

      final processedImage = await ImageUtils.bytesToImage(response.bodyBytes);
      setState(() { backgroundImage = processedImage; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Object removed successfully!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  Future<void> _handleAiBrushErase() async {
    if (backgroundImage == null) return;
    setState(() { _isProcessing = true; });

    try {
      ui.Image processImg = backgroundImage!;
      const int maxDimension = 1536;
      if (processImg.width > maxDimension || processImg.height > maxDimension) {
        double ratio = processImg.width / processImg.height;
        int newWidth, newHeight;
        if (ratio > 1) { newWidth = maxDimension; newHeight = (maxDimension / ratio).round(); }
        else { newHeight = maxDimension; newWidth = (maxDimension * ratio).round(); }
        processImg = await ImageUtils.resizeImage(processImg, newWidth, newHeight);
      }

      final imageBytes = await ImageUtils.imageToBytes(processImg);
      final maskBytes = await generateAiMask(processImg.width, processImg.height);

      final resultBytes = await AiImageService.eraseWithStability(
        imageBytes: imageBytes,
        maskBytes: maskBytes,
      );

      if (resultBytes == null) throw Exception("AI erase failed");

      final processedImage = await ImageUtils.bytesToImage(resultBytes);

      setState(() {
        backgroundImage = processedImage;
        activeLayer.history.removeWhere((a) => a.tool == PaintTool.aiErase);
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brush AI erase complete!')));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
    } finally {
      setState(() { _isProcessing = false; });
    }
  }

  Future<void> _applyAiEraseStroke() async {
    if (aiErasePoints.isEmpty) return;
    setState(() {
      activeLayer.history.add(
        DrawingAction(
          tool: PaintTool.aiErase,
          color: Colors.red,
          strokeWidth: strokeWidth,
          points: List.from(aiErasePoints),
        ),
      );
      aiErasePoints.clear();
    });
  }

  Future<Uint8List> generateAiMask(int width, int height) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final double scaleX = width / canvasWidth;
    final double scaleY = height / canvasHeight;

    canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = Colors.black);

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = strokeWidth * scaleX
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final action in activeLayer.history) {
      if (action.tool == PaintTool.aiErase) {
        if (action.points.length > 1) {
          final path = Path()..moveTo(action.points.first.dx * scaleX, action.points.first.dy * scaleY);
          for (int i = 1; i < action.points.length; i++) {
            path.lineTo(action.points[i].dx * scaleX, action.points[i].dy * scaleY);
          }
          canvas.drawPath(path, paint);
        }
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _handleSaveImage() async {
    setState(() => _isProcessing = true);
    try {
      await ImageUtils.saveCanvasToGallery(
        canvasKey: _canvasKey,
        isBgVisible: isBgLayerVisible,
        bgColor: bgLayerColor,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Gallery!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showColorPicker() {
    Color tempPickerColor = selectedColor;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick a color!'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: tempPickerColor,
              onColorChanged: (Color color) => tempPickerColor = color,
              enableAlpha: true,
              labelTypes: const [ColorLabelType.rgb, ColorLabelType.hex, ColorLabelType.hsl],
            ),
          ),
          actions: <Widget>[
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
            ElevatedButton(child: const Text('Got it'), onPressed: () {
              _setColor(tempPickerColor);
              Navigator.of(context).pop();
            }),
          ],
        );
      },
    );
  }

  void _showResizeDialog() {
    TextEditingController wCtrl = TextEditingController(text: canvasWidth.toInt().toString());
    TextEditingController hCtrl = TextEditingController(text: canvasHeight.toInt().toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Resize Canvas"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: wCtrl, decoration: const InputDecoration(labelText: "Width"), keyboardType: TextInputType.number),
            TextField(controller: hCtrl, decoration: const InputDecoration(labelText: "Height"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () {
            final double w = double.tryParse(wCtrl.text) ?? canvasWidth;
            final double h = double.tryParse(hCtrl.text) ?? canvasHeight;
            _updateCanvasSize(w, h); // 👈 Modified: Triggers automated multi-device bounds syncing
            Navigator.pop(context);
          }, child: const Text("Apply"))
        ],
      ),
    );
  }

  void _showBrushesBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(16.0), child: Text("Select Brush", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            _brushTile(BrushType.solid, Icons.brush, "Solid Brush"),
            _brushTile(BrushType.soft, Icons.blur_linear, "Soft Brush"),
            _brushTile(BrushType.neon, Icons.wb_incandescent_outlined, "Neon Brush"),
            _brushTile(BrushType.marker, Icons.highlight, "Highlighter"),
          ],
        ),
      ),
    );
  }

  void _showAiToolsBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(16.0), child: Text("AI Magic Tools", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ListTile(
              leading: const Icon(Icons.no_photography, color: Colors.blue),
              title: const Text("Remove Background"),
              onTap: () { Navigator.pop(context); _handleRemoveBackground(); },
            ),
            ListTile(
              leading: const Icon(Icons.cut, color: Colors.orange),
              title: const Text("Remove Objects"),
              onTap: () { Navigator.pop(context); _handleRemoveObject(); },
            ),
            ListTile(
              leading: const Icon(Icons.format_paint, color: Colors.purple),
              title: const Text("AI Brush Tool"),
              subtitle: const Text("Paint over objects to erase them"),
              onTap: () { Navigator.pop(context); setState(() => activeTool = PaintTool.aiErase); },
            ),
          ],
        ),
      ),
    );
  }

  Widget _brushTile(BrushType brush, IconData icon, String title) {
    final bool isActive = activeBrush == brush && activeTool == PaintTool.freehand;
    return ListTile(
      leading: CircleAvatar(backgroundColor: isActive ? Colors.blueAccent : Colors.grey, child: Icon(icon, color: isActive ? Colors.white : Colors.black87)),
      title: Text(title),
      onTap: () {
        _commitEditing();
        _setBrush(brush); // 👈 Fix: Correctly syncs the brush change profile across the backend
        _setTool(PaintTool.freehand);
        Navigator.pop(context);
      },
    );
  }

  void _showSelectionBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(16.0), child: Text("Select Mode", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _selectionGridItem(PaintTool.selection, Icons.select_all, "Rect"),
                _selectionGridItem(PaintTool.selectionCircle, Icons.circle_outlined, "Circle"),
                _selectionGridItem(PaintTool.selectionFree, CupertinoIcons.scribble, "Lasso"),
                _selectionGridItem(PaintTool.magicWand, Icons.auto_fix_normal, "Magic Wand"),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _selectionGridItem(PaintTool tool, IconData icon, String title) {
    final bool isActive = activeTool == tool;
    return GestureDetector(
      onTap: () {
        _setTool(tool);
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: isActive ? Colors.blue.withValues(alpha: 0.2) : Colors.grey, shape: BoxShape.circle),
            child: Icon(icon, color: isActive ? Colors.blueAccent : Colors.black87),
          ),
          Text(title, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _showShapesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            const Padding(padding: EdgeInsets.all(16.0), child: Text("Select Shape", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            Expanded(
              child: GridView.count(
                crossAxisCount: 4,
                children: [
                  _shapeGridItem(PaintTool.line, Icons.horizontal_rule, "Line"),
                  _shapeGridItem(PaintTool.rectangle, Icons.square_outlined, "Rect"),
                  _shapeGridItem(PaintTool.roundedRectangle, Icons.rectangle_outlined, "R-Rect"),
                  _shapeGridItem(PaintTool.circle, Icons.circle_outlined, "Circle"),
                  _shapeGridItem(PaintTool.triangle, Icons.change_history, "Triangle"),
                  _shapeGridItem(PaintTool.diamond, CupertinoIcons.rhombus, "Diamond"),
                  _shapeGridItem(PaintTool.pentagon, Icons.pentagon_outlined, "Pentagon"),
                  _shapeGridItem(PaintTool.hexagon, Icons.hexagon_outlined, "Hexagon"),
                  _shapeGridItem(PaintTool.star, Icons.star_border, "Star"),
                  _shapeGridItem(PaintTool.cross, Icons.add, "Cross"),
                  _shapeGridItem(PaintTool.arrowRight, Icons.arrow_forward, "Right"),
                  _shapeGridItem(PaintTool.heart, Icons.favorite_border, "Heart"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shapeGridItem(PaintTool tool, IconData icon, String title) {
    final bool isActive = activeTool == tool;
    return GestureDetector(
      onTap: () {
        _commitEditing();
        _setTool(tool);
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: isActive ? Colors.blue.withValues(alpha: 0.2) : Colors.grey, shape: BoxShape.circle),
            child: Icon(icon, color: isActive ? Colors.blueAccent : Colors.black87),
          ),
          Text(title, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  void _showNetworkBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text("Network Sync", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    if (_isNetworkActive) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 48),
                            const SizedBox(height: 10),
                            Text("Connected as ${_networkManager.currentRole.name.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.power_settings_new),
                        label: const Text("Disconnect"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                        onPressed: () {
                          _networkManager.shutdown();
                          setState(() {
                            _isNetworkActive = false;
                            _isSearchingNetwork = false;
                            _discoveredHosts.clear();
                          });
                          Navigator.pop(context);
                        },
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.desktop_windows),
                        label: const Text("Start Main Canvas (Host)", style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                        onPressed: () async {
                          await _networkManager.startHost();
                          setState(() => _isNetworkActive = true);
                          if (mounted) Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text("- OR -", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: _isSearchingNetwork ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 2)) : const Icon(Icons.search),
                        label: Text(_isSearchingNetwork ? "Searching Wi-Fi..." : "Find Host to Join", style: const TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: widget.isDarkMode ? Colors.grey : Colors.white, foregroundColor: Colors.blueAccent),
                        onPressed: _isSearchingNetwork ? null : () async {
                          setState(() { _isSearchingNetwork = true; _discoveredHosts.clear(); });
                          setModalState(() { _isSearchingNetwork = true; _discoveredHosts.clear(); });

                          _networkManager.onHostDiscovered = (ip, name) {
                            try {
                              setModalState(() => _discoveredHosts[ip] = name);
                            } catch (_) {}
                          };

                          _networkManager.onDiscoveryTimeout = () {
                            if (mounted) {
                              setState(() => _isSearchingNetwork = false);
                              try {
                                setModalState(() => _isSearchingNetwork = false);
                              } catch (_) {}
                            }
                          };

                          await _networkManager.startDiscovery();
                        },
                      ),
                      if (_discoveredHosts.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text("Available Hosts:", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(color: widget.isDarkMode ? Colors.black54 : Colors.grey, borderRadius: BorderRadius.circular(12)),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _discoveredHosts.length,
                            itemBuilder: (context, index) {
                              String ip = _discoveredHosts.keys.elementAt(index);
                              String name = _discoveredHosts[ip]!;
                              return ListTile(
                                leading: const Icon(Icons.wifi, color: Colors.green),
                                title: Text(name),
                                subtitle: Text(ip, style: const TextStyle(fontSize: 12)),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () { Navigator.pop(context); _showRoleSelectionDialog(ip, name); },
                              );
                            },
                          ),
                        ),
                      ]
                    ]
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showRoleSelectionDialog(String ip, String hostName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Join $hostName"),
        content: const Text("What role will this device play?"),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.vertical_align_top),
            label: const Text("Top Bar Only"),
            onPressed: () async {
              Navigator.pop(context);
              await _networkManager.connectToHost(ip, role: DeviceRole.topBarOnly);
              setState(() => _isNetworkActive = true);
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.vertical_align_bottom),
            label: const Text("Bottom Bar Only"),
            onPressed: () async {
              Navigator.pop(context);
              await _networkManager.connectToHost(ip, role: DeviceRole.bottomBarOnly);
              setState(() => _isNetworkActive = true);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCanvasInitialized) {
      final size = MediaQuery.of(context).size;

      if (size.width > 0 && size.height > 0) {
        canvasWidth = size.width * 0.9;
        canvasHeight = size.height * 0.65;
        _isCanvasInitialized = true;
      }
    }

    if (_networkManager.currentRole == DeviceRole.topBarOnly) {
      return TopBarRemoteController(
        isDarkMode: widget.isDarkMode,
        canUndo: activeLayer.history.isNotEmpty,
        canRedo: activeLayer.redoStack.isNotEmpty,
        onUndo: () => _sendCommand('undo'),
        onRedo: () => _sendCommand('redo'),
        onLoadImage: () => _sendCommand('load'),
        onSaveImage: () => _sendCommand('save'),
        onResizeCanvas: _showResizeDialog,
        onOpenLayers: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (context) => LayersDrawer(
              layers: layers,
              activeLayerIndex: activeLayerIndex,
              isBgLayerVisible: isBgLayerVisible,
              bgLayerColor: bgLayerColor,
              onAddLayer: _addLayer,
              onReorderLayers: _reorderLayers,
              onToggleLayerVisibility: _toggleLayerVisibility,
              onDeleteLayer: _deleteLayer,
              onSelectLayer: _selectLayer,
              onRenameLayer: _renameLayer,
              onToggleBgVisibility: _toggleBgVisibility,
              onChangeBgColor: _changeBgColor,
            ),
          );
        },
        onToggleTheme: () {
          bool newMode = !widget.isDarkMode;
          widget.toggleTheme(newMode);
          _networkManager.broadcast({
            'type': 'theme',
            'isDarkMode': newMode,
          });
        },
        onDisconnect: () {
          _networkManager.shutdown();
          setState(() {
            _isNetworkActive = false;
            _isSearchingNetwork = false;
            _discoveredHosts.clear();
          });
        },
      );
    }

    if (_networkManager.currentRole == DeviceRole.bottomBarOnly) {
      return BottomBarRemoteController(
        isDarkMode: widget.isDarkMode,
        activeTool: activeTool,
        strokeWidth: strokeWidth,
        selectedColor: selectedColor,
        onSetTool: (tool) {
          if (!([PaintTool.selection, PaintTool.selectionCircle, PaintTool.selectionFree, PaintTool.magicWand].contains(activeTool) && [PaintTool.selection, PaintTool.selectionCircle, PaintTool.selectionFree, PaintTool.magicWand].contains(tool))) {
            _commitEditing();
          }
          _setTool(tool);
        },
        onSetStrokeWidth: _setStrokeWidth,
        onShowColorPicker: _showColorPicker,
        onShowBrushes: _showBrushesBottomSheet,
        onShowShapes: _showShapesBottomSheet,
        onShowSelection: _showSelectionBottomSheet,
        onShowAiTools: _showAiToolsBottomSheet,
        onToggleTheme: () {
          bool newMode = !widget.isDarkMode;
          widget.toggleTheme(newMode);
          _networkManager.broadcast({
            'type': 'theme',
            'isDarkMode': newMode,
          });
        },
        onDisconnect: () {
          _networkManager.shutdown();
          setState(() {
            _isNetworkActive = false;
            _isSearchingNetwork = false;
            _discoveredHosts.clear();
          });
        },
      );
    }

    bool hideTopBar = _networkManager.isRoleConnected(DeviceRole.topBarOnly);
    bool hideBottomBar = _networkManager.isRoleConnected(DeviceRole.bottomBarOnly);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: widget.isDarkMode ? const Color(0xFF1A1A1A) : Colors.grey[200],

      floatingActionButton: (hideTopBar && _networkManager.isHost)
          ? FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.cell_tower, color: Colors.white),
        onPressed: _showNetworkBottomSheet,
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,

      appBar: hideTopBar ? null : TopMenuBar(
        isDarkMode: widget.isDarkMode,
        isNetworkActive: _isNetworkActive,
        isHost: _networkManager.isHost,
        isProcessing: _isProcessing,
        canUndo: activeLayer.history.isNotEmpty,
        canRedo: activeLayer.redoStack.isNotEmpty,
        onToggleTheme: () {
          bool newMode = !widget.isDarkMode;
          widget.toggleTheme(newMode); // Update the host locally

          // Broadcast the change so the controllers follow suit!
          _networkManager.broadcast({
            'type': 'theme',
            'isDarkMode': newMode,
          });
        },
        onShowNetworkSheet: _showNetworkBottomSheet,
        onUndo: undo,
        onRedo: redo,
        onOpenLayers: () => _scaffoldKey.currentState?.openEndDrawer(),
        onLoadImage: _handleLoadImage,
        onSaveImage: _handleSaveImage,
        onResizeCanvas: _showResizeDialog,
      ),

      endDrawer: LayersDrawer(
        layers: layers,
        activeLayerIndex: activeLayerIndex,
        isBgLayerVisible: isBgLayerVisible,
        bgLayerColor: bgLayerColor,
        onAddLayer: _addLayer,
        onReorderLayers: _reorderLayers,
        onToggleLayerVisibility: _toggleLayerVisibility,
        onDeleteLayer: _deleteLayer,
        onSelectLayer: _selectLayer,
        onRenameLayer: _renameLayer,
        onToggleBgVisibility: _toggleBgVisibility,
        onChangeBgColor: _changeBgColor,
      ),

      body: Column(
        children: [
          Expanded(
            child: MagnifierView(
              transformationController: _transformationController,
              activeTool: activeTool,
              child: Center(
                child: Container(
                  width: canvasWidth,
                  height: canvasHeight,
                  decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(child: ClipRect(child: CustomPaint(painter: CheckerboardPainter()))),
                      if (isBgLayerVisible) Positioned.fill(child: Container(color: bgLayerColor)),
                      Positioned.fill(
                        child: RepaintBoundary(
                          key: _canvasKey,
                          child: IgnorePointer(
                            ignoring: activeTool == PaintTool.magnifier || _isProcessing,
                            child: GestureDetector(
                              onTapDown: (details) {
                                if (!activeLayer.isVisible) return;
                                if (editingActionIndex != null) {
                                  final action = activeLayer.history[editingActionIndex!];
                                  final rect = Rect.fromPoints(action.startPoint!, action.endPoint!);
                                  if (activeTool == PaintTool.text) {
                                    if (!rect.inflate(20).contains(details.localPosition)) _commitEditing();
                                    else return;
                                  } else if ([PaintTool.selection, PaintTool.selectionCircle, PaintTool.selectionFree, PaintTool.magicWand].contains(activeTool)) {
                                    if (!rect.contains(details.localPosition)) _commitEditing();
                                    return;
                                  } else if (activeTool != PaintTool.magicWand) {
                                    if (!rect.inflate(20).contains(details.localPosition)) _commitEditing();
                                    return;
                                  }
                                }
                                if (activeTool == PaintTool.bucket) _handleBucketFill(details.localPosition);
                                else if (activeTool == PaintTool.eyedropper) _handleEyedropper(details.localPosition);
                                else if (activeTool == PaintTool.magicWand) _handleMagicWand(details.localPosition);
                                else if (activeTool == PaintTool.text && editingActionIndex == null) {
                                  final start = details.localPosition;
                                  final end = Offset(start.dx + 150, start.dy + 50);
                                  _textEditingController.text = "";
                                  setState(() {
                                    activeLayer.history.add(DrawingAction(tool: PaintTool.text, color: selectedColor, strokeWidth: strokeWidth, startPoint: start, endPoint: end, fontFamily: selectedFont, isEditing: true));
                                    editingActionIndex = activeLayer.history.length - 1;
                                  });
                                  Future.delayed(const Duration(milliseconds: 50), () => _textFocusNode.requestFocus());
                                }
                              },
                              onPanStart: (details) {
                                if (activeTool == PaintTool.bucket || activeTool == PaintTool.eyedropper) return;
                                if (!activeLayer.isVisible) return;
                                if (editingActionIndex != null) {
                                  final action = activeLayer.history[editingActionIndex!];
                                  if (activeTool == PaintTool.text) {
                                    final rect = Rect.fromPoints(action.startPoint!, action.endPoint!);
                                    const double h = 30.0;
                                    if (Rect.fromCenter(center: rect.topLeft, width: h, height: h).contains(details.localPosition)) _textDragMode = "resize_tl";
                                    else if (Rect.fromCenter(center: rect.topRight, width: h, height: h).contains(details.localPosition)) _textDragMode = "resize_tr";
                                    else if (Rect.fromCenter(center: rect.bottomLeft, width: h, height: h).contains(details.localPosition)) _textDragMode = "resize_bl";
                                    else if (Rect.fromCenter(center: rect.bottomRight, width: h, height: h).contains(details.localPosition)) _textDragMode = "resize_br";
                                    else if (rect.inflate(20).contains(details.localPosition)) _textDragMode = "move";
                                    else { _textDragMode = "none"; _commitEditing(); }
                                    return;
                                  }
                                  if ([PaintTool.selection, PaintTool.selectionCircle, PaintTool.selectionFree, PaintTool.magicWand].contains(activeTool)) {
                                    final rect = Rect.fromPoints(action.startPoint!, action.endPoint!);
                                    if (rect.contains(details.localPosition)) {
                                      _textDragMode = "move";
                                      if (!action.isLifted) setState(() => activeLayer.history[editingActionIndex!] = action.copyWith(isLifted: true));
                                      return;
                                    } else _commitEditing();
                                  }
                                }
                                if (activeTool == PaintTool.text && editingActionIndex == null) {
                                  _textEditingController.text = "";
                                  setState(() => currentAction = DrawingAction(tool: PaintTool.text, color: selectedColor, strokeWidth: strokeWidth, startPoint: details.localPosition, endPoint: details.localPosition, fontFamily: selectedFont, isEditing: true));
                                  return;
                                }
                                setState(() {
                                  activeLayer.redoStack.clear();
                                  currentAction = DrawingAction(tool: activeTool, brushType: activeBrush, color: selectedColor, strokeWidth: strokeWidth, startPoint: details.localPosition, endPoint: details.localPosition, points: [details.localPosition], isEditing: [PaintTool.selection, PaintTool.selectionCircle, PaintTool.selectionFree, PaintTool.magicWand].contains(activeTool));
                                });
                              },
                              onPanUpdate: (details) {
                                bool isSelection = [PaintTool.selection, PaintTool.selectionCircle, PaintTool.selectionFree, PaintTool.magicWand].contains(activeTool);
                                if ((activeTool == PaintTool.text || isSelection) && editingActionIndex != null && _textDragMode != "none") {
                                  final action = activeLayer.history[editingActionIndex!];
                                  if (isSelection && !action.isLifted && _textDragMode == "move") return;
                                  setState(() {
                                    if (_textDragMode == "move") activeLayer.history[editingActionIndex!] = action.copyWith(startPoint: action.startPoint! + details.delta, endPoint: action.endPoint! + details.delta);
                                    else if (_textDragMode == "resize_tl") activeLayer.history[editingActionIndex!] = action.copyWith(startPoint: details.localPosition);
                                    else if (_textDragMode == "resize_br") activeLayer.history[editingActionIndex!] = action.copyWith(endPoint: details.localPosition);
                                  });
                                  return;
                                }
                                if (activeTool == PaintTool.aiErase) {
                                  setState(() => aiErasePoints.add(details.localPosition));
                                  return;
                                }
                                if (currentAction == null || activeTool == PaintTool.bucket) return;

                                setState(() {
                                  if (activeTool == PaintTool.freehand || activeTool == PaintTool.eraser || activeTool == PaintTool.selectionFree) currentAction!.points.add(details.localPosition);
                                  else if (activeTool == PaintTool.spray) {
                                    for (int i = 0; i < 5; i++) {
                                      double a = _random.nextDouble() * 2 * pi; double r = _random.nextDouble() * (strokeWidth / 2);
                                      currentAction!.points.add(details.localPosition + Offset(r * cos(a), r * sin(a)));
                                    }
                                  } else currentAction = currentAction!.copyWith(endPoint: details.localPosition);
                                });
                              },
                              onPanEnd: (details) {
                                bool isSelection = [PaintTool.selection, PaintTool.selectionCircle, PaintTool.selectionFree, PaintTool.magicWand].contains(activeTool);
                                if (activeTool == PaintTool.aiErase) { _applyAiEraseStroke(); return; }
                                if ((activeTool == PaintTool.text || isSelection) && editingActionIndex != null) {
                                  _textDragMode = "none";
                                  final action = activeLayer.history[editingActionIndex!];
                                  final rect = Rect.fromPoints(action.startPoint!, action.endPoint!);
                                  if (activeTool != PaintTool.text && (rect.right < 0 || rect.left > canvasWidth || rect.bottom < 0 || rect.top > canvasHeight)) {
                                    setState(() {
                                      activeLayer.history[editingActionIndex!] = action.copyWith(isEditing: false, isLifted: true, clearRasterImage: true);
                                      editingActionIndex = null;
                                    });
                                  }
                                  return;
                                }
                                if (currentAction != null) {
                                  if (activeTool == PaintTool.text) {
                                    setState(() {
                                      var r = Rect.fromPoints(currentAction!.startPoint!, currentAction!.endPoint!);
                                      if (r.width < 50) r = Rect.fromLTRB(r.left, r.top, r.left + 50, r.bottom);
                                      if (r.height < 30) r = Rect.fromLTRB(r.left, r.top, r.right, r.top + 30);
                                      activeLayer.history.add(currentAction!.copyWith(startPoint: r.topLeft, endPoint: r.bottomRight));
                                      editingActionIndex = max(0, activeLayer.history.length - 1);
                                      currentAction = null;
                                    });
                                    Future.delayed(const Duration(milliseconds: 50), () => _textFocusNode.requestFocus());
                                  } else if (isSelection) {
                                    final act = currentAction!;
                                    setState(() => currentAction = null);
                                    _handleSelectionEnd(act);
                                  } else {
                                    setState(() {
                                      activeLayer.history.add(currentAction!);
                                      if (_isNetworkActive) _networkManager.broadcast({'type': 'draw_action', 'action': currentAction!.toMap()});
                                      currentAction = null;
                                    });
                                  }
                                }
                              },
                              child: ClipRect(
                                child: CustomPaint(
                                  painter: AdvancedPainter(layers: layers, activeLayerIndex: activeLayerIndex, currentAction: currentAction, bgColor: backgroundColor, backgroundImage: backgroundImage, editingActionIndex: editingActionIndex),
                                  size: Size(canvasWidth, canvasHeight),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (editingActionIndex != null && activeLayer.history[editingActionIndex!].tool == PaintTool.text)
                        _buildTextOverlay(activeLayer.history[editingActionIndex!]),
                      if (editingActionIndex != null) _buildActionMenus(),
                      if (_isProcessing) Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.3), child: const Center(child: CircularProgressIndicator(color: Colors.white)))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: hideBottomBar ? null : AbsorbPointer(
        absorbing: _isProcessing,
        child: Opacity(
          opacity: _isProcessing ? 0.5 : 1.0,
          child: BottomToolsBar(
            isDarkMode: widget.isDarkMode,
            activeTool: activeTool,
            isProcessing: _isProcessing,
            selectionMode: _selectionMode,
            strokeWidth: strokeWidth,
            selectedColor: selectedColor,
            onShowColorPicker: _showColorPicker,
            onToolSelected: (tool) {
              if (!([PaintTool.selection, PaintTool.selectionCircle, PaintTool.selectionFree, PaintTool.magicWand].contains(activeTool) && [PaintTool.selection, PaintTool.selectionCircle, PaintTool.selectionFree, PaintTool.magicWand].contains(tool))) {
                _commitEditing();
              }
              _setTool(tool);
            },
            onStrokeWidthChanged: _setStrokeWidth,
            onSelectionModeChanged: (mode) => setState(() => _selectionMode = mode),
            showBrushesSheet: _showBrushesBottomSheet,
            showShapesSheet: _showShapesBottomSheet,
            showSelectionSheet: _showSelectionBottomSheet,
            showAiToolsSheet: _showAiToolsBottomSheet,
            onAiEraseStroke: _handleAiBrushErase,
            onClearAiErase: () => setState(() => activeLayer.history.removeWhere((a) => a.tool == PaintTool.aiErase)),
          ),
        ),
      ),
    );
  }

  Widget _buildTextOverlay(DrawingAction action) {
    final rect = Rect.fromPoints(action.startPoint!, action.endPoint!);
    return Positioned(
      left: rect.left, top: rect.top, width: rect.width, height: rect.height,
      child: TextField(
        controller: _textEditingController, focusNode: _textFocusNode, maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top,
        style: TextStyle(color: action.color, fontSize: action.strokeWidth * 2, fontWeight: action.isBold ? FontWeight.bold : FontWeight.normal, fontStyle: action.isItalic ? FontStyle.italic : FontStyle.normal, fontFamily: action.fontFamily, height: 1.0),
        decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(4.0)),
        onChanged: (val) => setState(() => activeLayer.history[editingActionIndex!] = action.copyWith(text: val)),
      ),
    );
  }

  Widget _buildActionMenus() {
    final action = activeLayer.history[editingActionIndex!];
    if (action.tool == PaintTool.text) return _buildTextFloatingToolbar(action);
    else return Stack(clipBehavior: Clip.none, children: [_buildSelectionActionButtons(action), _buildRotationHandle(action)]);
  }

  Widget _buildTextFloatingToolbar(DrawingAction action) {
    final rect = Rect.fromPoints(action.startPoint!, action.endPoint!);
    double top = rect.bottom + 15; if (top > canvasHeight - 60) top = rect.top - 60; top = top.clamp(10.0, max(10.0, canvasHeight - 60.0));
    double left = (rect.center.dx - 100).clamp(10.0, max(10.0, canvasWidth - 250.0));
    return Positioned(
      left: left, top: top,
      child: Material(
        elevation: 6, borderRadius: BorderRadius.circular(12), color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: action.fontFamily, underline: const SizedBox(), icon: const Icon(Icons.arrow_drop_down, size: 16),
                items: availableFonts.map((font) => DropdownMenuItem(value: font, child: Text(font, style: TextStyle(fontFamily: font, fontSize: 12)))).toList(),
                onChanged: (val) { if (val != null) setState(() { selectedFont = val; activeLayer.history[editingActionIndex!] = action.copyWith(fontFamily: val); }); },
              ),
              Container(width: 1, height: 24, color: Colors.grey),
              IconButton(icon: Icon(Icons.format_bold, color: action.isBold ? Colors.blue : Colors.black87), onPressed: () => setState(() => activeLayer.history[editingActionIndex!] = action.copyWith(isBold: !action.isBold))),
              IconButton(icon: Icon(Icons.format_italic, color: action.isItalic ? Colors.blue : Colors.black87), onPressed: () => setState(() => activeLayer.history[editingActionIndex!] = action.copyWith(isItalic: !action.isItalic))),
              Container(width: 1, height: 24, color: Colors.grey),
              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() { activeLayer.history.removeAt(editingActionIndex!); editingActionIndex = null; _textFocusNode.unfocus(); })),
              IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: _commitEditing),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionActionButtons(DrawingAction action) {
    final rect = Rect.fromPoints(action.startPoint!, action.endPoint!);
    double top = rect.bottom + 15; if (top > canvasHeight - 60) top = rect.top - 60; top = top.clamp(10.0, max(10.0, canvasHeight - 60.0));
    double left = (rect.center.dx - 72).clamp(10.0, max(10.0, canvasWidth - 160.0));
    return Positioned(
      left: left, top: top,
      child: Material(
        elevation: 6, borderRadius: BorderRadius.circular(12), color: Colors.white,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onPanUpdate: (details) => setState(() => activeLayer.history[editingActionIndex!] = action.copyWith(startPoint: action.startPoint! + details.delta, endPoint: action.endPoint! + details.delta, isLifted: true)),
              onPanEnd: (details) {
                final r = Rect.fromPoints(action.startPoint!, action.endPoint!);
                if (r.right < 0 || r.left > canvasWidth || r.bottom < 0 || r.top > canvasHeight) setState(() { activeLayer.history[editingActionIndex!] = action.copyWith(isEditing: false, isLifted: true, clearRasterImage: true); editingActionIndex = null; });
              },
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), color: Colors.transparent, child: const Icon(Icons.open_with, color: Colors.black54)),
            ),
            Container(width: 1, height: 24, color: Colors.grey),
            IconButton(icon: const Icon(Icons.crop, color: Colors.blue), onPressed: _handleCropToSelection),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), tooltip: "Delete", onPressed: () => setState(() { activeLayer.history[editingActionIndex!] = action.copyWith(isEditing: false, isLifted: true, clearRasterImage: true); editingActionIndex = null; })),
          ],
        ),
      ),
    );
  }

  Widget _buildRotationHandle(DrawingAction action) {
    final rect = Rect.fromPoints(action.startPoint!, action.endPoint!);
    final double cx = rect.center.dx, cy = rect.center.dy, distance = (rect.height / 2) + 30, visualAngle = action.angle - (pi / 2);
    double hx = cx + distance * cos(visualAngle); double hy = cy + distance * sin(visualAngle);
    hx = hx.clamp(16.0, max(16.0, canvasWidth - 16.0)); hy = hy.clamp(16.0, max(16.0, canvasHeight - 16.0));
    return Positioned(
      left: hx - 16, top: hy - 16,
      child: GestureDetector(
        onPanUpdate: (details) {
          RenderBox? canvasBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?; if (canvasBox == null) return;
          Offset localFinger = canvasBox.globalToLocal(details.globalPosition);
          setState(() => activeLayer.history[editingActionIndex!] = action.copyWith(angle: atan2(localFinger.dy - cy, localFinger.dx - cx) + (pi / 2), isLifted: true));
        },
        child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.blueAccent, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]), child: const Icon(Icons.rotate_right, size: 16, color: Colors.blueAccent)),
      ),
    );
  }
}