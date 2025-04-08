import 'package:flutter/material.dart';
import 'package:flutter_story_presenter/flutter_story_presenter.dart';
import 'package:visibility_detector/visibility_detector.dart';

typedef OnTextStoryLoaded = void Function(bool isLoaded, bool isVisible);

class TextStoryView extends StatefulWidget {
  const TextStoryView({
    super.key,
    required this.storyItem,
    this.onVisibilityChanged,
  });

  final StoryItem storyItem;
  final OnTextStoryLoaded? onVisibilityChanged;

  @override
  State<TextStoryView> createState() => _TextStoryViewState();
}

class _TextStoryViewState extends State<TextStoryView> {
  @override
  void initState() {
    super.initState();
    widget.onVisibilityChanged?.call(true, false);
  }

  @override
  Widget build(BuildContext context) {
    final storyItem = widget.storyItem;

    return VisibilityDetector(
      key: UniqueKey(),
      onVisibilityChanged: (info) {
        if (info.visibleFraction == 0) {
          widget.onVisibilityChanged?.call(true, false);
        } else if (info.visibleFraction == 1) {
          widget.onVisibilityChanged?.call(true, true);
        }
      },
      child: Container(
        color: storyItem.textConfig?.backgroundColor,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (storyItem.textConfig?.backgroundWidget != null) ...{
              storyItem.textConfig!.backgroundWidget!,
            },
            if (storyItem.textConfig?.textWidget != null) ...{
              storyItem.textConfig!.textWidget!,
            } else ...{
              Align(
                alignment: widget.storyItem.textConfig?.textAlignment ??
                    Alignment.center,
                child: Text(
                  widget.storyItem.url!,
                ),
              ),
            }
          ],
        ),
      ),
    );
  }
}
