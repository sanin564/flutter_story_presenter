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
    required this.storyItem,
    this.onVideoLoad,
    this.looping,
    super.key,
  });

  /// The story item containing video data and configuration.
  final StoryItem storyItem;

  /// Callback function to notify when the video is loaded.
  final OnVideoLoad? onVideoLoad;

  /// In case of single video story
  final bool? looping;

  @override
  State<VideoStoryView> createState() => _VideoStoryViewState();
}

class _VideoStoryViewState extends State<VideoStoryView> {
  late final VideoPlayerController videoPlayerController;
  VideoStatus videoStatus = VideoStatus.loading;

  @override
  void initState() {
    _initialiseVideoPlayer();
    super.initState();
  }

  /// Initializes the video player controller based on the source of the video.
  Future<void> _initialiseVideoPlayer() async {
    try {
      final storyItem = widget.storyItem;
      if (storyItem.storyItemSource.isNetwork) {
        // Initialize video controller for network source.
        videoPlayerController =
            await VideoUtils.instance.videoControllerFromUrl(
          url: storyItem.url!,
          cacheFile: storyItem.videoConfig?.cacheVideo,
          videoPlayerOptions: storyItem.videoConfig?.videoPlayerOptions,
        );
      } else if (storyItem.storyItemSource.isFile) {
        // Initialize video controller for file source.
        videoPlayerController = VideoUtils.instance.videoControllerFromFile(
          file: File(storyItem.url!),
          videoPlayerOptions: storyItem.videoConfig?.videoPlayerOptions,
        );
      } else {
        // Initialize video controller for asset source.
        videoPlayerController = VideoUtils.instance.videoControllerFromAsset(
          assetPath: storyItem.url!,
          videoPlayerOptions: storyItem.videoConfig?.videoPlayerOptions,
        );
      }
      await videoPlayerController.initialize();
      videoStatus = VideoStatus.data;
      widget.onVideoLoad?.call(videoPlayerController);
      await videoPlayerController.play();
      await videoPlayerController.setLooping(widget.looping ?? false);
      await videoPlayerController.setVolume(storyItem.isMuteByDefault ? 0 : 1);
    } catch (e) {
      videoStatus = VideoStatus.error;
      debugPrint('$e');
    }
    setState(() {});
  }

  BoxFit get fit => widget.storyItem.videoConfig?.fit ?? BoxFit.cover;

  @override
  void dispose() {
    videoPlayerController.dispose();
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
        if (videoStatus == VideoStatus.data) ...{
          if (widget.storyItem.videoConfig?.useVideoAspectRatio ?? false) ...{
            // Display the video with aspect ratio if specified.
            AspectRatio(
              aspectRatio: videoPlayerController.value.aspectRatio,
              child: VideoPlayer(
                videoPlayerController,
              ),
            )
          } else ...{
            // Display the video fitted to the screen.
            FittedBox(
              fit: widget.storyItem.videoConfig?.fit ?? BoxFit.cover,
              alignment: Alignment.center,
              child: SizedBox(
                width: widget.storyItem.videoConfig?.width ??
                    videoPlayerController.value.size.width,
                height: widget.storyItem.videoConfig?.height ??
                    videoPlayerController.value.size.height,
                child: VideoPlayer(videoPlayerController),
              ),
            )
          },
        }
      ],
    );
  }
}
