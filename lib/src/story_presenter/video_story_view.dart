import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_story_presenter/flutter_story_presenter.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../utils/video_utils.dart';

/// A widget that displays a video story view, supporting different video sources
/// (network, file, asset) and optional thumbnail and error widgets.
///

typedef OnVisibilityChanged = void Function(
    VideoPlayerController? videoPlayer, bool isvisible);

class VideoStoryView extends StatefulWidget {
  /// Creates a [VideoStoryView] widget.
  const VideoStoryView({
    super.key,
    required this.storyItem,
    this.looping,
    this.onEnd,
    this.onVisibilityChanged,
  });

  /// The story item containing video data and configuration.
  final StoryItem storyItem;

  /// In case of single video story
  final bool? looping;
  final OnVisibilityChanged? onVisibilityChanged;
  final VoidCallback? onEnd;

  @override
  State<VideoStoryView> createState() => _VideoStoryViewState();
}

class _VideoStoryViewState extends State<VideoStoryView> {
  VideoPlayerController? controller;
  VideoStatus videoStatus = VideoStatus.loading;

  @override
  void initState() {
    super.initState();
    _initialiseVideoPlayer().then((_) {
      if (videoStatus.isLive) {
        controller?.addListener(videoListener);
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
      await controller?.initialize();
      videoStatus = VideoStatus.live;
      if (controller != null) {
        widget.onVisibilityChanged?.call(controller!, false);
      }
      await controller?.setLooping(widget.looping ?? false);
      await controller?.setVolume(storyItem.isMuteByDefault ? 0 : 1);
    } catch (e) {
      videoStatus = VideoStatus.error;
      debugPrint('$e');
    }
    if (mounted) {
      setState(() {});
    }
  }

  void videoListener() {
    final pos = controller?.value.position ?? Duration.zero;
    final dur = controller?.value.duration ?? Duration.zero;
    if (pos >= dur) {
      widget.onEnd?.call();
    }
  }

  BoxFit get fit => config.fit ?? BoxFit.cover;

  StoryViewVideoConfig get config =>
      widget.storyItem.videoConfig ?? const StoryViewVideoConfig();

  @override
  void dispose() {
    if (videoStatus.isLive) {
      controller?.removeListener(videoListener);
      controller?.dispose();
      controller = null;
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: UniqueKey(),
      onVisibilityChanged: (info) {
        if (info.visibleFraction == 1) {
          widget.onVisibilityChanged?.call(controller, true);
        } else if (info.visibleFraction == 0) {
          widget.onVisibilityChanged?.call(controller, false);
        }
      },
      child: Stack(
        alignment:
            (fit == BoxFit.cover) ? Alignment.topCenter : Alignment.center,
        fit: (fit == BoxFit.cover) ? StackFit.expand : StackFit.loose,
        children: [
          if (config.loadingWidget != null) ...{
            config.loadingWidget!,
          },
          if (widget.storyItem.errorWidget != null && videoStatus.hasError) ...{
            // Display the error widget if an error occurred.
            widget.storyItem.errorWidget!,
          },
          if (videoStatus.isLive && controller != null) ...{
            if (config.useVideoAspectRatio) ...{
              // Display the video with aspect ratio if specified.
              AspectRatio(
                aspectRatio: controller!.value.aspectRatio,
                child: VideoPlayer(controller!),
              )
            } else ...{
              // Display the video fitted to the screen.
              FittedBox(
                fit: config.fit ?? BoxFit.cover,
                alignment: Alignment.center,
                child: SizedBox(
                    width: config.width ?? controller?.value.size.width,
                    height: config.height ?? controller?.value.size.height,
                    child: VideoPlayer(controller!)),
              )
            },
          }
        ],
      ),
    );
  }
}
