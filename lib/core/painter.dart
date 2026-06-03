import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'models.dart';

class AdvancedPainter extends CustomPainter {
  final List<PaintLayer> layers;
  final int activeLayerIndex;
  final DrawingAction? currentAction;
  final Color bgColor;
  final ui.Image? backgroundImage;
  final int? editingActionIndex;

  AdvancedPainter({
    required this.layers,
    required this.activeLayerIndex,
    required this.currentAction,
    required this.bgColor,
    this.backgroundImage,
    this.editingActionIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (backgroundImage != null) {
      paintImage(canvas: canvas, rect: Offset.zero & size, image: backgroundImage!, fit: BoxFit.contain);
    }

    for (int i = 0; i < layers.length; i++) {
      if (!layers[i].isVisible) continue;

      canvas.saveLayer(Offset.zero & size, Paint());

      for (int j = 0; j < layers[i].history.length; j++) {
        bool isEditingThis = (i == activeLayerIndex && j == editingActionIndex);
        _drawAction(canvas, layers[i].history[j], showMarquee: isEditingThis);
      }

      if (currentAction != null && i == activeLayerIndex) {
        _drawAction(canvas, currentAction!, showMarquee: true);
      }

      canvas.restore();
    }
  }

  void _drawAction(Canvas canvas, DrawingAction action, {bool showMarquee = true}) {
    if (action.tool == PaintTool.bucket && action.rasterImage != null) {
      canvas.drawImage(action.rasterImage!, Offset.zero, Paint());
      return;
    }

    final paint = Paint()
      ..color = action.tool == PaintTool.eraser ? Colors.transparent : action.color
      ..blendMode = action.tool == PaintTool.eraser ? ui.BlendMode.clear : ui.BlendMode.srcOver
      ..strokeWidth = action.tool == PaintTool.spray ? 2.0 : action.strokeWidth
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (action.tool != PaintTool.spray && action.tool != PaintTool.bucket && action.tool != PaintTool.eraser) {
      switch (action.brushType) {
        case BrushType.soft: paint.maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, action.strokeWidth / 2); break;
        case BrushType.neon: if (action.tool != PaintTool.eraser) { paint.maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 3); paint.strokeWidth += 2; } break;
        case BrushType.marker: if (action.tool != PaintTool.eraser) { paint.color = action.color.withValues(alpha: 0.4); paint.strokeCap = ui.StrokeCap.square; } break;
        case BrushType.solid: break;
      }
    }

    switch (action.tool) {
      case PaintTool.freehand:

      case PaintTool.eraser:
        if (action.points.length > 1) { final path = Path()..moveTo(action.points.first.dx, action.points.first.dy); for (int i = 1; i < action.points.length; i++) path.lineTo(action.points[i].dx, action.points[i].dy); canvas.drawPath(path, paint); }
        else if (action.points.isNotEmpty) { canvas.drawPoints(ui.PointMode.points, [action.points.first], paint); }
        break;
      case PaintTool.aiErase:

        final erasePaint = Paint()
          ..color = Colors.red.withOpacity(0.5)
          ..strokeWidth = action.strokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        if (action.points.length > 1) {

          final path = Path()
            ..moveTo(
              action.points.first.dx,
              action.points.first.dy,
            );

          for (int i = 1; i < action.points.length; i++) {
            path.lineTo(
              action.points[i].dx,
              action.points[i].dy,
            );
          }

          canvas.drawPath(path, erasePaint);
        }

        break;
      case PaintTool.spray: canvas.drawPoints(ui.PointMode.points, action.points, paint); break;
      case PaintTool.line: if (action.startPoint != null && action.endPoint != null) canvas.drawLine(action.startPoint!, action.endPoint!, paint); break;
      case PaintTool.rectangle: if (action.startPoint != null && action.endPoint != null) canvas.drawRect(Rect.fromPoints(action.startPoint!, action.endPoint!), paint); break;
      case PaintTool.circle: if (action.startPoint != null && action.endPoint != null) canvas.drawOval(Rect.fromPoints(action.startPoint!, action.endPoint!), paint); break;
      case PaintTool.triangle: if (action.startPoint != null && action.endPoint != null) canvas.drawPath(_getTrianglePath(Rect.fromPoints(action.startPoint!, action.endPoint!)), paint); break;
      case PaintTool.diamond: if (action.startPoint != null && action.endPoint != null) canvas.drawPath(_getDiamondPath(Rect.fromPoints(action.startPoint!, action.endPoint!)), paint); break;
      case PaintTool.star: if (action.startPoint != null && action.endPoint != null) canvas.drawPath(_getStarPath(Rect.fromPoints(action.startPoint!, action.endPoint!), 5), paint); break;
      case PaintTool.cross: if (action.startPoint != null && action.endPoint != null) canvas.drawPath(_getCrossPath(Rect.fromPoints(action.startPoint!, action.endPoint!)), paint); break;
      case PaintTool.roundedRectangle: if (action.startPoint != null && action.endPoint != null) canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromPoints(action.startPoint!, action.endPoint!), Radius.circular(Rect.fromPoints(action.startPoint!, action.endPoint!).width * 0.1)), paint); break;
      case PaintTool.arrowRight: if (action.startPoint != null && action.endPoint != null) canvas.drawPath(_getArrowPath(Rect.fromPoints(action.startPoint!, action.endPoint!), "right"), paint); break;
      case PaintTool.heart: if (action.startPoint != null && action.endPoint != null) canvas.drawPath(_getHeartPath(Rect.fromPoints(action.startPoint!, action.endPoint!)), paint); break;
      case PaintTool.pentagon: if (action.startPoint != null && action.endPoint != null) canvas.drawPath(_getPolygonPath(Rect.fromPoints(action.startPoint!, action.endPoint!), 5), paint); break;
      case PaintTool.hexagon: if (action.startPoint != null && action.endPoint != null) canvas.drawPath(_getPolygonPath(Rect.fromPoints(action.startPoint!, action.endPoint!), 6), paint); break;

      case PaintTool.text:
        if (action.startPoint != null && action.endPoint != null) {
          final rect = Rect.fromPoints(action.startPoint!, action.endPoint!);

          if (showMarquee && action.isEditing) {
            final mPaint = Paint()..color = Colors.blue..style = PaintingStyle.stroke..strokeWidth = 1.0;
            _drawDashedRect(canvas, rect, mPaint);

            final handlePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
            final handleBorder = Paint()..color = Colors.blue..style = PaintingStyle.stroke;
            for (var pt in [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight]) {
              canvas.drawRect(Rect.fromCenter(center: pt, width: 8, height: 8), handlePaint);
              canvas.drawRect(Rect.fromCenter(center: pt, width: 8, height: 8), handleBorder);
            }
          }

          if (!action.isEditing && action.text != null && action.text!.isNotEmpty) {
            final tp = TextPainter(
                text: TextSpan(
                    text: action.text,
                    style: TextStyle(
                      color: action.color,
                      fontSize: action.strokeWidth * 2,
                      fontWeight: action.isBold ? FontWeight.bold : FontWeight.normal,
                      fontStyle: action.isItalic ? FontStyle.italic : FontStyle.normal,
                      fontFamily: action.fontFamily, // NEW: Apply the selected font
                    )
                ),
                textDirection: TextDirection.ltr
            );
            tp.layout(maxWidth: max(0.1, rect.width - 8.0));
            tp.paint(canvas, rect.topLeft + const Offset(4.0, 4.0));
          }
        }
        break;

      case PaintTool.selection:
      case PaintTool.selectionCircle:
      case PaintTool.selectionFree:
        if (action.selectionRect != null) {
          if (action.isLifted) {
            final holePaint = Paint()..blendMode = ui.BlendMode.clear;
            if (action.tool == PaintTool.selectionCircle) canvas.drawOval(action.selectionRect!, holePaint);
            else if (action.tool == PaintTool.selectionFree) {
              if (action.isMagicWand) canvas.drawPoints(ui.PointMode.points, action.points, holePaint..strokeWidth = 2.0);
              else { final path = Path()..moveTo(action.points.first.dx, action.points.first.dy); for (var p in action.points) path.lineTo(p.dx, p.dy); canvas.drawPath(path..close(), holePaint); }
            } else canvas.drawRect(action.selectionRect!, holePaint);
          }

          canvas.save();
          final Rect currentRect = (action.startPoint != null && action.endPoint != null)
              ? Rect.fromPoints(action.startPoint!, action.endPoint!)
              : action.selectionRect!;

          if (action.angle != 0) {
            canvas.translate(currentRect.center.dx, currentRect.center.dy);
            canvas.rotate(action.angle);
            canvas.translate(-currentRect.center.dx, -currentRect.center.dy);
          }

          if (action.rasterImage != null) {
            final dest = (action.startPoint ?? action.selectionRect!.topLeft) & action.selectionRect!.size;
            canvas.drawImageRect(action.rasterImage!, Offset.zero & Size(action.rasterImage!.width.toDouble(), action.rasterImage!.height.toDouble()), dest, Paint()..filterQuality = ui.FilterQuality.high);
          }

          if (showMarquee && action.isEditing && action.startPoint != null && action.endPoint != null) {
            final mPaint = Paint()..color = Colors.blue..style = PaintingStyle.stroke..strokeWidth = 1.0;
            final p1 = Offset(currentRect.center.dx, currentRect.top);
            final p2 = Offset(currentRect.center.dx, currentRect.top - 30);
            canvas.drawLine(p1, p2, mPaint);
            if (action.isMagicWand) _drawPixelMarquee(canvas, action.points, mPaint, (action.startPoint! - action.selectionRect!.topLeft));
            else if (action.tool == PaintTool.selectionCircle) _drawDashedOval(canvas, Rect.fromPoints(action.startPoint!, action.endPoint!), mPaint);
            else if (action.tool == PaintTool.selectionFree) {
              final Offset delta = action.isLifted ? (action.startPoint! - action.selectionRect!.topLeft) : Offset.zero;
              final movedPoints = action.points.map((p) => p + delta).toList();
              _drawDashedPath(canvas, movedPoints, mPaint, isClosed: action.selectionRect != null);
            } else _drawDashedRect(canvas, Rect.fromPoints(action.startPoint!, action.endPoint!), mPaint);
          }
          canvas.restore();
        } else if (showMarquee && action.startPoint != null && action.endPoint != null) {
          final mPaint = Paint()..color = Colors.blue..style = PaintingStyle.stroke..strokeWidth = 1.0;
          if (action.tool == PaintTool.selectionCircle) _drawDashedOval(canvas, Rect.fromPoints(action.startPoint!, action.endPoint!), mPaint);
          else if (action.tool == PaintTool.selectionFree) _drawDashedPath(canvas, action.points, mPaint, isClosed: false);
          else _drawDashedRect(canvas, Rect.fromPoints(action.startPoint!, action.endPoint!), mPaint);
        }
        break;
      default: break;
    }
  }

  void _drawPixelMarquee(Canvas canvas, List<Offset> points, Paint paint, Offset delta) {
    final Set<Offset> pSet = points.toSet();
    for (var p in points) {
      bool isEdge = !pSet.contains(p + const Offset(1, 0)) || !pSet.contains(p - const Offset(1, 0)) || !pSet.contains(p + const Offset(0, 1)) || !pSet.contains(p - const Offset(0, 1));
      if (isEdge && (p.dx + p.dy).toInt() % 8 < 4) canvas.drawRect((p + delta) & const Size(1, 1), Paint()..color = paint.color);
    }
  }

  Path _getTrianglePath(Rect r) => Path()..moveTo(r.center.dx, r.top)..lineTo(r.left, r.bottom)..lineTo(r.right, r.bottom)..close();
  Path _getDiamondPath(Rect r) => Path()..moveTo(r.center.dx, r.top)..lineTo(r.right, r.center.dy)..lineTo(r.center.dx, r.bottom)..lineTo(r.left, r.center.dy)..close();
  Path _getStarPath(Rect r, int p) {
    final path = Path(); final double cx = r.center.dx, cy = r.center.dy, rad = min(r.width, r.height) / 2, irad = rad / 2.5, step = pi / p;
    for (int i = 0; i < 2 * p; i++) { final double curRad = i.isEven ? rad : irad, a = i * step - pi / 2; if (i == 0) path.moveTo(cx + curRad * cos(a), cy + curRad * sin(a)); else path.lineTo(cx + curRad * cos(a), cy + curRad * sin(a)); }
    return path..close();
  }
  Path _getCrossPath(Rect r) {
    final double th = min(r.width, r.height) * 0.3, x1 = r.center.dx - th / 2, x2 = r.center.dx + th / 2, y1 = r.center.dy - th / 2, y2 = r.center.dy + th / 2;
    return Path()..moveTo(x1, r.top)..lineTo(x2, r.top)..lineTo(x2, y1)..lineTo(r.right, y1)..lineTo(r.right, y2)..lineTo(x2, y2)..lineTo(x2, r.bottom)..lineTo(x1, r.bottom)..lineTo(x1, y2)..lineTo(r.left, y2)..lineTo(r.left, y1)..lineTo(x1, y1)..close();
  }
  Path _getHeartPath(Rect r) => Path()..moveTo(r.center.dx, r.top + r.height * 0.3)..cubicTo(r.center.dx, r.top, r.left, r.top, r.left, r.top + r.height * 0.3)..cubicTo(r.left, r.top + r.height * 0.6, r.center.dx, r.bottom, r.center.dx, r.bottom)..cubicTo(r.center.dx, r.bottom, r.right, r.top + r.height * 0.6, r.right, r.top + r.height * 0.3)..cubicTo(r.right, r.top, r.center.dx, r.top, r.center.dx, r.top + r.height * 0.3)..close();
  Path _getPolygonPath(Rect r, int s) {
    final path = Path(); final double cx = r.center.dx, cy = r.center.dy, rad = min(r.width, r.height) / 2, step = (2 * pi) / s;
    for (int i = 0; i < s; i++) { final double a = i * step - pi / 2; if (i == 0) path.moveTo(cx + rad * cos(a), cy + rad * sin(a)); else path.lineTo(cx + rad * cos(a), cy + rad * sin(a)); }
    return path..close();
  }
  Path _getArrowPath(Rect r, String d) {
    final path = Path();
    final double w = r.width, h = r.height, l = r.left, t = r.top;
    path
      ..moveTo(l, t + h * 0.3)
      ..lineTo(l + w * 0.6, t + h * 0.3)
      ..lineTo(l + w * 0.6, t)
      ..lineTo(l + w, t + h * 0.5)
      ..lineTo(l + w * 0.6, t + h)
      ..lineTo(l + w * 0.6, t + h * 0.7)
      ..lineTo(l, t + h * 0.7);
    return path..close();
  }
  void _drawDashedRect(Canvas canvas, Rect r, Paint p) {
    final path = Path()..addRect(r); final ui.PathMetrics metrics = path.computeMetrics();
    for (final m in metrics) { double d = 0.0; while (d < m.length) { canvas.drawPath(m.extractPath(d, min(d + 5, m.length)), p); d += 8; } }
  }
  void _drawDashedOval(Canvas canvas, Rect r, Paint p) {
    final path = Path()..addOval(r); final ui.PathMetrics metrics = path.computeMetrics();
    for (final m in metrics) { double d = 0.0; while (d < m.length) { canvas.drawPath(m.extractPath(d, min(d + 5, m.length)), p); d += 8; } }
  }
  void _drawDashedPath(Canvas canvas, List<Offset> pts, Paint p, {bool isClosed = true}) {
    if (pts.length < 2) return; final path = Path()..moveTo(pts.first.dx, pts.first.dy); for (var pt in pts) path.lineTo(pt.dx, pt.dy); if (isClosed) path.close();
    final ui.PathMetrics metrics = path.computeMetrics();
    for (final m in metrics) { double d = 0.0; while (d < m.length) { canvas.drawPath(m.extractPath(d, min(d + 5, m.length)), p); d += 8; } }
  }
  @override bool shouldRepaint(covariant AdvancedPainter oldDelegate) => true;
}

class CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    const double squareSize = 16.0;
    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        bool isEven = ((x / squareSize).floor() + (y / squareSize).floor()) % 2 == 0;
        paint.color = isEven ? const Color(0xFFCCCCCC) : Colors.white;
        canvas.drawRect(Rect.fromLTWH(x, y, squareSize, squareSize), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}