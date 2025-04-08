import 'package:flutter/material.dart';
import 'package:flutter_story_presenter/flutter_story_presenter.dart';
import 'package:visibility_detector/visibility_detector.dart';

class StoryCustomWidgetWrapper extends StatelessWidget {
  const StoryCustomWidgetWrapper({
    super.key,
    required this.builder,
    this.isAutoStart = true,
    this.onVisibilityChanged,
    required this.storyItem,
  });

  final CustomViewBuilder builder;

  /// The story item containing image data and configuration.
  final StoryItem storyItem;

  final bool isAutoStart;
  final Function(bool isVisible)? onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: UniqueKey(),
      onVisibilityChanged: (info) {
        if (info.visibleFraction == 0) {
          onVisibilityChanged?.call(false);
        } else if (info.visibleFraction == 1) {
          onVisibilityChanged?.call(true);
        }
      },
      child: Builder(
        builder: (context) {
          return builder();
        },
      ),
    );
  }
}
