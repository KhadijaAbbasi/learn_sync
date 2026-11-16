import 'package:flutter/material.dart';

/// Keeps slides alongside course information on wide lecture screens.
class LiveLectureWorkspace extends StatefulWidget {
  const LiveLectureWorkspace({
    super.key,
    required this.controller,
    required this.courseIdentity,
    required this.lectureInfo,
    required this.slides,
    required this.attendees,
    this.controls = const [],
  });

  final ScrollController controller;
  final Widget courseIdentity;
  final Widget lectureInfo;
  final Widget slides;
  final Widget attendees;
  final List<Widget> controls;

  @override
  State<LiveLectureWorkspace> createState() => _LiveLectureWorkspaceState();
}

class _LiveLectureWorkspaceState extends State<LiveLectureWorkspace> {
  // Resizing the window must not reload the presenter deck or reset its page.
  final _slidesKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        final slideContent = KeyedSubtree(
          key: _slidesKey,
          child: widget.slides,
        );
        final content = wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [slideContent, ...widget.controls],
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 340,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        widget.courseIdentity,
                        const SizedBox(height: 16),
                        widget.lectureInfo,
                        const SizedBox(height: 16),
                        widget.attendees,
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  widget.courseIdentity,
                  const SizedBox(height: 14),
                  widget.lectureInfo,
                  const SizedBox(height: 14),
                  slideContent,
                  ...widget.controls,
                  widget.attendees,
                ],
              );
        return SingleChildScrollView(
          controller: widget.controller,
          padding: EdgeInsets.all(wide ? 28 : 18),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: content,
            ),
          ),
        );
      },
    );
  }
}
