import 'package:flutter/material.dart';

class BrainDumpInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final String? userName;

  const BrainDumpInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final hint = userName != null
        ? 'welcome back ${userName!.toLowerCase()}, start typing…'
        : 'just start typing…';

    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: true,
      maxLines: null,
      expands: true,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textAlignVertical: TextAlignVertical.top,
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0x30FFFFFF),
          fontSize: 18,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.5,
        ),
      ),
      style: const TextStyle(
        color: Color(0xD9FFFFFF),
        fontSize: 18,
        height: 1.6,
        fontWeight: FontWeight.w300,
        letterSpacing: 0.3,
      ),
      cursorColor: const Color(0x99FFFFFF),
      cursorWidth: 1.5,
      onSubmitted: onSubmitted,
    );
  }
}
