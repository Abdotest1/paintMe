import 'package:flutter/material.dart';
import 'models.dart';

class TextToolHandler {
  static Future<void> showTextDialog({
    required BuildContext context,
    required DrawingAction action,
    required Function(DrawingAction) onTextAdded,
  }) async {
    String text = "";
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Enter Text"),
        content: TextField(
          autofocus: true,
          onChanged: (val) => text = val,
          decoration: const InputDecoration(hintText: "Type something..."),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              if (text.isNotEmpty) {
                final rect = Rect.fromPoints(action.startPoint!, action.endPoint!);
                final normalizedAction = action.copyWith(
                  text: text,
                  isEditing: true,
                  startPoint: rect.topLeft,
                  endPoint: rect.bottomRight,
                );
                onTextAdded(normalizedAction);
              }
              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }
}