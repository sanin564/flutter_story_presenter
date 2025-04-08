import 'package:flutter/material.dart';
import 'package:flutter_story_presenter/flutter_story_presenter.dart';

class StoryCustomWidgetWrapper extends StatelessWidget {
  const StoryCustomWidgetWrapper({
    super.key,
    required this.builder,
    this.isAutoStart = true,
    this.onLoaded,
    required this.storyItem,
  });

  final CustomViewBuilder builder;

  /// The story item containing image data and configuration.
  final StoryItem storyItem;

  final bool isAutoStart;
  final Function()? onLoaded;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return builder();
      },
    );
  }
}
