import 'package:flutter/material.dart';

/*
1 : BrainDumpInput is the primary text entry component.
It is designed to be borderless and full-screen style, 
facilitating a distraction-free 'writing trance'.
*/
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
    /*
    2 : Dynamic hint text personalizes the experience if the userName is known.
    */
    final hint = userName != null
        ? 'welcome back ${userName!.toLowerCase()}, start typing…'
        : 'just start typing…';

    return Padding(
      padding: const EdgeInsets.only(
        top: 40.0,
      ), // Ensure it's below status bar/neural trunk top
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        maxLines: null,
        // expands: true, // Removed to prevent full-screen hit-testing
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
      ),
    );
  }
}
