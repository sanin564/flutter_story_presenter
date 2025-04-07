import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_story_presenter/src/story_presenter/story_custom_view_wrapper.dart';
import 'package:just_audio/just_audio.dart';
import '../story_presenter/story_view_indicator.dart';
import '../models/story_item.dart';
import '../models/story_view_indicator_config.dart';
import '../controller/flutter_story_controller.dart';
import '../story_presenter/image_story_view.dart';
import '../story_presenter/video_story_view.dart';
import '../story_presenter/web_story_view.dart';
import '../story_presenter/text_story_view.dart';
import '../utils/smooth_video_progress.dart';
import '../utils/story_utils.dart';
import 'package:video_player/video_player.dart';

typedef OnStoryChanged = void Function(int);
typedef OnCompleted = Future<void> Function();
typedef OnLeftTap = Future<bool> Function();
typedef OnRightTap = Future<bool> Function();
typedef OnDrag = void Function();
typedef OnItemBuild = Widget? Function(int, Widget);
typedef OnVideoLoad = void Function(VideoPlayerController?);
typedef OnAudioLoaded = void Function(AudioPlayer);
typedef CustomViewBuilder = Widget Function(AudioPlayer);
typedef OnSlideDown = void Function(DragUpdateDetails);
typedef OnSlideStart = void Function(DragStartDetails);
typedef OnPause = Future<bool> Function();
typedef OnResume = Future<bool> Function();
typedef IndicatorWrapper = Widget Function(Widget child);

class StoryPresenter extends StatefulWidget {
  const StoryPresenter({
    this.storyController,
    this.items = const [],
    this.onStoryChanged,
    this.onLeftTap,
    this.onRightTap,
    this.onCompleted,
    this.onPreviousCompleted,
    this.storyViewIndicatorConfig,
    this.onVideoLoad,
    this.headerWidget,
    this.footerWidget,
    this.onSlideDown,
    this.onSlideStart,
    this.onPause,
    this.onResume,
    this.indicatorWrapper,
    super.key,
  });

  /// List of StoryItem objects to display in the story view.
  final List<StoryItem> items;

  /// Controller for managing the current playing media.
  final StoryController? storyController;

  /// Callback function triggered whenever the story changes or the user navigates to the previous/next story.
  final OnStoryChanged? onStoryChanged;

  /// Callback function triggered when all items in the list have been played.
  final OnCompleted? onCompleted;

  /// Callback function triggered when all items in the list have been played.
  final OnCompleted? onPreviousCompleted;

  /// Callback function triggered when the user taps on the left half of the screen.
  ///
  /// It must return a boolean future with true if this child will handle the request;
  /// otherwise, return a boolean future with false.
  final OnLeftTap? onLeftTap;

  /// Callback function triggered when the user taps on the right half of the screen.
  ///
  /// It must return a boolean future with true if this child will handle the request;
  /// otherwise, return a boolean future with false.
  final OnRightTap? onRightTap;

  /// Callback function triggered when user drag downs the storyview.
  final OnSlideDown? onSlideDown;

  /// Callback function triggered when user starts drag downs the storyview.
  final OnSlideStart? onSlideStart;

  /// Configuration and styling options for the story view indicator.
  final StoryViewIndicatorConfig? storyViewIndicatorConfig;

  /// Callback function to retrieve the VideoPlayerController when it is initialized and ready to play.
  final OnVideoLoad? onVideoLoad;

  /// Widget to display user profile or other details at the top of the screen.
  final Widget? headerWidget;

  /// Widget to display text field or other content at the bottom of the screen.
  final Widget? footerWidget;

  /// called when status is paused by user, typically when user tap and holds
  /// on the screen.
  ///
  /// It must return a boolean future with true if this child will handle the request;
  /// otherwise, return a boolean future with false.
  final OnPause? onPause;

  /// called when status is resumed after user paused the view, typically when
  /// user releases the tap from a long press.
  ///
  /// It must return a boolean future with true if this child will handle the request;
  /// otherwise, return a boolean future with false.
  final OnResume? onResume;

  final IndicatorWrapper? indicatorWrapper;

  @override
  State<StoryPresenter> createState() => _StoryPresenterState();
}

class _StoryPresenterState extends State<StoryPresenter>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  AnimationController? _animationController;
  Animation? _currentProgressAnimation;
  double currentItemProgress = 0;
  VideoPlayerController? _currentVideoPlayer;
  AudioPlayer? _audioPlayer;
  Duration? _totalAudioDuration;
  StreamSubscription? _audioDurationSubscriptionStream;
  StreamSubscription? _audioPlayerStateStream;

  late final StoryController _storyController;
  late final PageController pageController;

  @override
  void initState() {
    super.initState();

    _initStoryController();
    _disposeAnimeController();

    pageController = PageController(initialPage: _storyController.page);

    _animationController = AnimationController(
      vsync: this,
    );

    widget.onStoryChanged?.call(_storyController.page);

    WidgetsBinding.instance.addObserver(this);
  }

  void _initStoryController() {
    _storyController = widget.storyController ?? StoryController();
    _storyController.addListener(_storyControllerListener);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    log("STATE ==> $state");
    switch (state) {
      case AppLifecycleState.resumed:
        _storyController.play();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _storyController.pause();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    pageController.dispose();

    _disposeStoryController();
    _disposeAnimeController();

    _audioDurationSubscriptionStream?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _disposeStoryController() {
    _storyController.removeListener(_storyControllerListener);
    if (widget.storyController == null) {
      _storyController.dispose();
    }
  }

  void _disposeAnimeController() {
    if (_animationController != null) {
      _animationController!.reset();
      _animationController!.dispose();
      _animationController = null;
    }
  }

  void _disposeVideoController() {
    if (_currentVideoPlayer != null) {
      _currentVideoPlayer?.removeListener(videoListener);
      _currentVideoPlayer = null;
    }
  }

  void _forwardAnimation({double? from}) {
    if (_animationController?.duration != null) {
      _animationController!.forward(from: from);
    }
  }

  /// Returns the current story item.
  StoryItem get currentItem => widget.items[_storyController.page];

  /// Returns the configuration for the story view indicator.
  StoryViewIndicatorConfig get storyViewIndicatorConfig =>
      widget.storyViewIndicatorConfig ?? const StoryViewIndicatorConfig();

  /// Listener for the story controller to handle various story actions.
  void _storyControllerListener() {
    /// Resumes the media playback.
    void resumeMedia() {
      _audioPlayer?.play();
      _currentVideoPlayer?.play();
      if (_currentProgressAnimation != null) {
        _forwardAnimation(from: _currentProgressAnimation!.value);
      }
    }

    /// Pauses the media playback.
    void pauseMedia() {
      _audioPlayer?.pause();
      _currentVideoPlayer?.pause();
      _animationController?.stop(canceled: false);
    }

    /// Plays the next story item.
    void playNext() async {
      if (_storyController.page == widget.items.length - 1) {
        await widget.onCompleted?.call();
        return;
      } else {
        _disposeVideoController();
        _storyController.page += 1;
        pageController.jumpToPage(_storyController.page);
      }

      _resetAnimation();
      if (mounted) {
        setState(() {});
      }
    }

    /// Plays the previous story item.
    void playPrevious() {
      if (_audioPlayer != null) {
        _audioPlayer?.dispose();
        _audioDurationSubscriptionStream?.cancel();
        _audioPlayerStateStream?.cancel();
      }
      _disposeVideoController();

      if (_storyController.page == 0) {
        _resetAnimation();
        _startStoryCountdown();
        if (mounted) {
          setState(() {});
        }
        widget.onPreviousCompleted?.call();
        return;
      }

      _storyController.page -= 1;
      _resetAnimation();
      if (mounted) {
        setState(() {});
      }
    }

    /// Toggles mute/unmute for the media.
    void toggleMuteUnMuteMedia() {
      if (_currentVideoPlayer != null) {
        final videoPlayerValue = _currentVideoPlayer!.value;
        if (videoPlayerValue.volume == 1) {
          _currentVideoPlayer!.setVolume(0);
        } else {
          _currentVideoPlayer!.setVolume(1);
        }
      }
    }

    final storyStatus = _storyController.storyStatus;

    switch (storyStatus) {
      case StoryAction.play:
        resumeMedia();
        break;

      case StoryAction.pause:
        pauseMedia();
        break;

      case StoryAction.next:
        playNext();
        break;

      case StoryAction.previous:
        playPrevious();
        break;

      case StoryAction.mute:
      case StoryAction.unMute:
        toggleMuteUnMuteMedia();
        break;
    }
  }

  /// Resets the animation controller and its listeners.
  void _resetAnimation() {
    _animationController?.reset();
    _forwardAnimation();
    _animationController
      ?..removeListener(animationListener)
      ..removeStatusListener(animationStatusListener);
  }

  /// Starts the countdown for the story item duration.
  void _startStoryCountdown() {
    if (currentItem.storyItemType.isVideo) {
      if (_currentVideoPlayer != null) {
        _animationController ??= AnimationController(
          vsync: this,
        );
        _animationController?.duration = _currentVideoPlayer!.value.duration;
        _currentVideoPlayer!.addListener(videoListener);
      }
      return;
    }

    if (currentItem.audioConfig != null) {
      _audioPlayer?.durationFuture?.then((v) {
        _totalAudioDuration = v;
        _animationController ??= AnimationController(
          vsync: this,
        );

        _animationController?.duration = v;

        _currentProgressAnimation =
            Tween<double>(begin: 0, end: 1).animate(_animationController!)
              ..addListener(animationListener)
              ..addStatusListener(animationStatusListener);

        _forwardAnimation();
      });
      _audioDurationSubscriptionStream =
          _audioPlayer?.positionStream.listen(audioPositionListener);
      _audioPlayerStateStream = _audioPlayer?.playerStateStream.listen(
        (event) {
          if (event.playing) {
            if (event.processingState == ProcessingState.loading) {
              _storyController.pause();
            } else {
              _storyController.play();
            }
          }
        },
      );

      return;
    }

    _animationController ??= AnimationController(
      vsync: this,
    );

    _animationController?.duration = currentItem.duration;

    _currentProgressAnimation =
        Tween<double>(begin: 0, end: 1).animate(_animationController!)
          ..addListener(animationListener)
          ..addStatusListener(animationStatusListener);

    _forwardAnimation();
  }

  /// Listener for the video player's state changes.
  void videoListener() {
    if (_currentVideoPlayer != null) {
      final dur = _currentVideoPlayer!.value.duration.inMilliseconds;
      final pos = _currentVideoPlayer!.value.position.inMilliseconds;

      if (pos == dur) {
        _storyController.next();
        return;
      }

      if (_currentVideoPlayer!.value.isBuffering) {
        _animationController?.stop(canceled: false);
      }

      if (_currentVideoPlayer!.value.isPlaying) {
        if (_currentProgressAnimation != null) {
          _forwardAnimation(from: _currentProgressAnimation?.value);
        }
      }
    }
  }

  void audioPositionListener(Duration position) {
    final dur = position.inMilliseconds;
    final pos = _totalAudioDuration?.inMilliseconds;

    if (pos == dur) {
      _storyController.next();
      return;
    }
  }

  /// Listener for the animation progress.
  void animationListener() {
    currentItemProgress = _animationController?.value ?? 0;
  }

  /// Listener for the animation status.
  void animationStatusListener(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _storyController.next();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mdSize = MediaQuery.sizeOf(context);
    return Stack(
      children: [
        PageView.builder(
          controller: pageController,
          allowImplicitScrolling: true,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: widget.onStoryChanged,
          itemCount: widget.items.length,
          itemBuilder: (context, index) {
            final item = widget.items[index];

            switch (item.storyItemType) {
              case StoryItemType.image:
                return ImageStoryView(
                  key: ValueKey('${_storyController.page}'),
                  storyItem: item,
                  onImageLoaded: (isLoaded) {
                    _startStoryCountdown();
                  },
                  onAudioLoaded: (audioPlayer) {
                    _audioPlayer = audioPlayer;

                    _startStoryCountdown();
                  },
                );

              case StoryItemType.video:
                return VideoStoryView(
                  storyItem: item,
                  key: ValueKey('${_storyController.page}'),
                  looping: false,
                  onVideoLoad: (videoPlayer) {
                    _currentVideoPlayer = videoPlayer;
                    widget.onVideoLoad?.call(videoPlayer);
                    _startStoryCountdown();
                    if (mounted) {
                      setState(() {});
                    }
                  },
                );

              case StoryItemType.text:
                return TextStoryView(
                  storyItem: item,
                  key: ValueKey('${_storyController.page}'),
                  onTextStoryLoaded: (loaded) {
                    _startStoryCountdown();
                  },
                  onAudioLoaded: (audioPlayer) {
                    _audioPlayer = audioPlayer;
                    _startStoryCountdown();
                  },
                );

              case StoryItemType.web:
                return WebStoryView(
                  storyItem: item,
                  key: ValueKey('${_storyController.page}'),
                  onWebViewLoaded: (controller, loaded) {
                    if (loaded) {
                      _startStoryCountdown();
                    }
                    item.webConfig?.onWebViewLoaded?.call(
                      controller,
                      loaded,
                    );
                  },
                );

              case StoryItemType.custom:
                return StoryCustomWidgetWrapper(
                  isAutoStart: true,
                  key: UniqueKey(),
                  builder: (audioPlayer) {
                    return item.customWidget!(
                            widget.storyController, audioPlayer) ??
                        const SizedBox.shrink();
                  },
                  storyItem: item,
                  onLoaded: () {
                    _startStoryCountdown();
                  },
                  onAudioLoaded: (audioPlayer) {
                    _audioPlayer = audioPlayer;
                    _startStoryCountdown();
                  },
                );
            }
          },
        ),
        Builder(
          builder: (context) {
            final child = Align(
              alignment: storyViewIndicatorConfig.alignment,
              child: Padding(
                padding: storyViewIndicatorConfig.margin,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _currentVideoPlayer != null
                        ? SmoothVideoProgress(
                            controller: _currentVideoPlayer!,
                            builder: (context, progress, duration, child) {
                              return StoryViewIndicator(
                                currentIndex: _storyController.page,
                                currentItemAnimatedValue:
                                    progress.inMilliseconds /
                                        duration.inMilliseconds,
                                totalItems: widget.items.length,
                                storyViewIndicatorConfig:
                                    storyViewIndicatorConfig,
                              );
                            })
                        : _animationController != null
                            ? AnimatedBuilder(
                                animation: _animationController!,
                                builder: (context, child) => StoryViewIndicator(
                                  currentIndex: _storyController.page,
                                  currentItemAnimatedValue: currentItemProgress,
                                  totalItems: widget.items.length,
                                  storyViewIndicatorConfig:
                                      storyViewIndicatorConfig,
                                ),
                              )
                            : StoryViewIndicator(
                                currentIndex: _storyController.page,
                                currentItemAnimatedValue: currentItemProgress,
                                totalItems: widget.items.length,
                                storyViewIndicatorConfig:
                                    storyViewIndicatorConfig,
                              ),
                  ],
                ),
              ),
            );

            return widget.indicatorWrapper?.call(child) ?? child;
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: mdSize.width * .2,
            height: mdSize.height,
            child: GestureDetector(
              onTap: () async {
                final willUserHandle = await widget.onLeftTap?.call() ?? false;
                if (!willUserHandle) _storyController.previous();
              },
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: mdSize.width * .8,
            height: mdSize.height,
            child: GestureDetector(
              onTap: () async {
                final willUserHandle = await widget.onRightTap?.call() ?? false;
                if (!willUserHandle) _storyController.next();
              },
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: mdSize.width,
            height: mdSize.height,
            child: GestureDetector(
              key: ValueKey('${_storyController.page}'),
              onLongPressDown: (details) async {
                final willUserHandle = await widget.onPause?.call() ?? false;
                if (!willUserHandle) _storyController.pause();
              },
              onLongPressUp: () async {
                final willUserHandle = await widget.onResume?.call() ?? false;
                if (!willUserHandle) _storyController.play();
              },
              onLongPressEnd: (details) async {
                final willUserHandle = await widget.onResume?.call() ?? false;
                if (!willUserHandle) _storyController.play();
              },
              onLongPressCancel: () async {
                final willUserHandle = await widget.onResume?.call() ?? false;
                if (!willUserHandle) _storyController.play();
              },
              onVerticalDragStart: widget.onSlideStart?.call,
              onVerticalDragUpdate: widget.onSlideDown?.call,
            ),
          ),
        ),
        if (widget.headerWidget != null) ...{
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              bottom: storyViewIndicatorConfig.enableBottomSafeArea,
              top: storyViewIndicatorConfig.enableTopSafeArea,
              child: widget.headerWidget!,
            ),
          ),
        },
        if (widget.footerWidget != null) ...{
          Align(
            alignment: Alignment.bottomCenter,
            child: widget.footerWidget!,
          ),
        },
      ],
    );
  }
}
