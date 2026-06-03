import 'dart:ui' as ui;
import 'package:flutter/material.dart';

enum PaintTool {
  freehand, eraser, line, rectangle, circle, triangle, diamond, star, spray, bucket,  magnifier, text, eyedropper, pentagon, hexagon,
  roundedRectangle, arrowRight, arrowLeft, arrowUp, arrowDown, speechBubble, heart, cross, selection, selectionCircle, selectionFree, magicWand, aiErase
}

enum BrushType { solid, soft, neon, marker }

class DrawingAction {
  final PaintTool tool;
  final BrushType brushType;
  final Color color;
  final double strokeWidth;
  List<Offset> points;
  Offset? startPoint;
  Offset? endPoint;
  ui.Image? rasterImage;
  String? text;
  bool isEditing;
  bool isLifted;
  bool isMagicWand;
  bool isCrop;
  double angle;
  bool isBold;
  bool isItalic;
  String fontFamily;
  Rect? selectionRect;

  DrawingAction({
    required this.tool,
    this.brushType = BrushType.solid,
    required this.color,
    required this.strokeWidth,
    this.points = const [],
    this.startPoint,
    this.endPoint,
    this.rasterImage,
    this.text,
    this.isEditing = false,
    this.isLifted = false,
    this.isMagicWand = false,
    this.isCrop = false,
    this.angle = 0.0,
    this.isBold = false,
    this.isItalic = false,
    this.fontFamily = 'Arial',
    this.selectionRect,
  });

  DrawingAction copyWith({
    List<Offset>? points,
    Offset? startPoint,
    Offset? endPoint,
    String? text,
    bool? isEditing,
    bool? isLifted,
    bool? isMagicWand,
    bool? isCrop,
    double? angle,
    bool? isBold,
    bool? isItalic,
    String? fontFamily,
    Rect? selectionRect,
    ui.Image? rasterImage,
    bool clearRasterImage = false,
  }) {
    return DrawingAction(
      tool: tool,
      brushType: brushType,
      color: color,
      strokeWidth: strokeWidth,
      points: points ?? List.from(this.points),
      startPoint: startPoint ?? this.startPoint,
      endPoint: endPoint ?? this.endPoint,
      rasterImage: clearRasterImage ? null : (rasterImage ?? this.rasterImage),
      text: text ?? this.text,
      isEditing: isEditing ?? this.isEditing,
      isLifted: isLifted ?? this.isLifted,
      isMagicWand: isMagicWand ?? this.isMagicWand,
      isCrop: isCrop ?? this.isCrop,
      angle: angle ?? this.angle,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      fontFamily: fontFamily ?? this.fontFamily,
      selectionRect: selectionRect ?? this.selectionRect,
    );
  }

  // --- JSON SERIALIZATION (PACKING FOR NETWORK) ---
  Map<String, dynamic> toMap() {
    return {
      'tool': tool.name,
      'brushType': brushType.name,
      'color': color.value,
      'strokeWidth': strokeWidth,
      'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
      'startPoint': startPoint != null ? {'dx': startPoint!.dx, 'dy': startPoint!.dy} : null,
      'endPoint': endPoint != null ? {'dx': endPoint!.dx, 'dy': endPoint!.dy} : null,
      'text': text,
      'isEditing': isEditing,
      'angle': angle,
      'isBold': isBold,
      'isItalic': isItalic,
      'fontFamily': fontFamily,
      'selectionRect': selectionRect != null
          ? {'left': selectionRect!.left, 'top': selectionRect!.top, 'right': selectionRect!.right, 'bottom': selectionRect!.bottom}
          : null,
    };
  }

  // --- JSON DESERIALIZATION (UNPACKING FROM NETWORK) ---
  factory DrawingAction.fromMap(Map<String, dynamic> map) {
    return DrawingAction(
      tool: PaintTool.values.firstWhere((e) => e.name == map['tool']),
      brushType: BrushType.values.firstWhere((e) => e.name == map['brushType'], orElse: () => BrushType.solid),
      color: Color(map['color'] as int),
      strokeWidth: (map['strokeWidth'] as num).toDouble(),
      points: (map['points'] as List<dynamic>?)?.map((p) => Offset((p['dx'] as num).toDouble(), (p['dy'] as num).toDouble())).toList() ?? [],
      startPoint: map['startPoint'] != null ? Offset((map['startPoint']['dx'] as num).toDouble(), (map['startPoint']['dy'] as num).toDouble()) : null,
      endPoint: map['endPoint'] != null ? Offset((map['endPoint']['dx'] as num).toDouble(), (map['endPoint']['dy'] as num).toDouble()) : null,
      text: map['text'] as String?,
      isEditing: map['isEditing'] as bool? ?? false,
      angle: (map['angle'] as num?)?.toDouble() ?? 0.0,
      isBold: map['isBold'] as bool? ?? false,
      isItalic: map['isItalic'] as bool? ?? false,
      fontFamily: map['fontFamily'] as String? ?? 'Arial',
      selectionRect: map['selectionRect'] != null
          ? Rect.fromLTRB(
          (map['selectionRect']['left'] as num).toDouble(),
          (map['selectionRect']['top'] as num).toDouble(),
          (map['selectionRect']['right'] as num).toDouble(),
          (map['selectionRect']['bottom'] as num).toDouble()
      )
          : null,
    );
  }
}

class PaintLayer {
  String name;
  bool isVisible;
  List<DrawingAction> history;
  List<DrawingAction> redoStack;

  PaintLayer({
    required this.name,
    this.isVisible = true,
  })  : history = [],
        redoStack = [];

  PaintLayer copy() {
    final newLayer = PaintLayer(name: name, isVisible: isVisible);
    newLayer.history = List.from(history);
    newLayer.redoStack = List.from(redoStack);
    return newLayer;
  }
}