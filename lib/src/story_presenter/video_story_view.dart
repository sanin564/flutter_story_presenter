import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/story_item.dart';
import '../story_presenter/story_view.dart';
import '../utils/story_utils.dart';
import '../utils/video_utils.dart';

/// A widget that displays a video story view, supporting different video sources
/// (network, file, asset) and optional thumbnail and error widgets.
class VideoStoryView extends StatefulWidget {
  /// Creates a [VideoStoryView] widget.
  const VideoStoryView({
    super.key,
    required this.storyItem,
    this.onVideoLoad,
    this.looping,
    this.onEnd,
  });

  /// The story item containing video data and configuration.
  final StoryItem storyItem;

  /// Callback function to notify when the video is loaded.
  final OnVideoLoad? onVideoLoad;

  /// In case of single video story
  final bool? looping;

  final VoidCallback? onEnd;

  @override
  State<VideoStoryView> createState() => _VideoStoryViewState();
}

class _VideoStoryViewState extends State<VideoStoryView> {
  late final VideoPlayerController controller;
  VideoStatus videoStatus = VideoStatus.loading;

  @override
  void initState() {
    super.initState();
    _initialiseVideoPlayer().then((_) {
      if (videoStatus.isLive) {
        controller.addListener(videoListener);
      }
    });
  }

  /// Initializes the video player controller based on the source of the video.
  Future<void> _initialiseVideoPlayer() async {
    try {
      final storyItem = widget.storyItem;
      if (storyItem.storyItemSource.isNetwork) {
        // Initialize video controller for network source.
        controller = await VideoUtils.instance.videoControllerFromUrl(
          url: storyItem.url!,
          cacheFile: storyItem.videoConfig?.cacheVideo,
          videoPlayerOptions: storyItem.videoConfig?.videoPlayerOptions,
        );
      } else if (storyItem.storyItemSource.isFile) {
        // Initialize video controller for file source.
        controller = VideoUtils.instance.videoControllerFromFile(
          file: File(storyItem.url!),
          videoPlayerOptions: storyItem.videoConfig?.videoPlayerOptions,
        );
      } else {
        // Initialize video controller for asset source.
        controller = VideoUtils.instance.videoControllerFromAsset(
          assetPath: storyItem.url!,
          videoPlayerOptions: storyItem.videoConfig?.videoPlayerOptions,
        );
      }
      await controller.initialize();
      videoStatus = VideoStatus.live;
      widget.onVideoLoad?.call(controller);
      await controller.play();
      await controller.setLooping(widget.looping ?? false);
      await controller.setVolume(storyItem.isMuteByDefault ? 0 : 1);
    } catch (e) {
      videoStatus = VideoStatus.error;
      debugPrint('$e');
    }
    if (mounted) {
      setState(() {});
    }
  }

  void videoListener() {
    if (controller.value.position >= controller.value.duration) {
      widget.onEnd?.call();
    }
  }

  BoxFit get fit => widget.storyItem.videoConfig?.fit ?? BoxFit.cover;

  @override
  void dispose() {
    if (videoStatus.isLive) {
      controller.removeListener(videoListener);
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: (fit == BoxFit.cover) ? Alignment.topCenter : Alignment.center,
      fit: (fit == BoxFit.cover) ? StackFit.expand : StackFit.loose,
      children: [
        if (widget.storyItem.videoConfig?.loadingWidget != null) ...{
          widget.storyItem.videoConfig!.loadingWidget!,
        },
        if (widget.storyItem.errorWidget != null && videoStatus.hasError) ...{
          // Display the error widget if an error occurred.
          widget.storyItem.errorWidget!,
        },
        if (videoStatus == VideoStatus.live) ...{
          if (widget.storyItem.videoConfig?.useVideoAspectRatio ?? false) ...{
            // Display the video with aspect ratio if specified.
            AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(
                controller,
              ),
            )
          } else ...{
            // Display the video fitted to the screen.
            FittedBox(
              fit: widget.storyItem.videoConfig?.fit ?? BoxFit.cover,
              alignment: Alignment.center,
              child: SizedBox(
                width: widget.storyItem.videoConfig?.width ??
                    controller.value.size.width,
                height: widget.storyItem.videoConfig?.height ??
                    controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            )
          },
        }
      ],
    );
  }
}
