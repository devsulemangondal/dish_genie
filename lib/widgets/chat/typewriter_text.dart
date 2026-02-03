import 'package:flutter/material.dart';

/// A widget that displays text with a typewriter effect (character by character animation)
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration speed;
  final bool animate;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.speed = const Duration(milliseconds: 15),
    this.animate = true,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayedText = '';
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.animate && widget.text.isNotEmpty) {
      _startTyping();
    } else {
      _displayedText = widget.text;
    }
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If text changed, handle streaming updates
    if (oldWidget.text != widget.text) {
      if (widget.animate && widget.text.isNotEmpty) {
        // If new text is longer and is an extension of old text (streaming)
        if (widget.text.length > oldWidget.text.length && 
            widget.text.startsWith(oldWidget.text)) {
          // Text was appended via streaming, continue typing from current position
          // Don't reset, just continue animating the new characters
          // The _continueTyping() will handle showing new characters
          if (_currentIndex >= widget.text.length) {
            // We've already displayed all the text we have, just update
            _displayedText = widget.text;
          }
          // Continue typing if we haven't caught up yet
          if (_currentIndex < widget.text.length) {
            _continueTyping();
          }
        } else if (widget.text.length <= oldWidget.text.length) {
          // Text got shorter (shouldn't happen, but handle it)
          _currentIndex = widget.text.length;
          _displayedText = widget.text;
        } else {
          // Completely different text, restart animation
          _currentIndex = 0;
          _displayedText = '';
          _startTyping();
        }
      } else {
        _displayedText = widget.text;
        _currentIndex = widget.text.length;
      }
    }
  }

  void _startTyping() {
    _displayedText = '';
    _currentIndex = 0;
    _continueTyping();
  }

  void _continueTyping() {
    if (_currentIndex < widget.text.length && mounted) {
      setState(() {
        _displayedText = widget.text.substring(0, _currentIndex + 1);
        _currentIndex++;
      });
      
      // Schedule next character
      Future.delayed(widget.speed, () {
        if (mounted) {
          _continueTyping();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayedText,
      style: widget.style,
    );
  }
}
