import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_story_presenter/src/story_presenter/story_custom_view_wrapper.dart';
import '../story_presenter/story_view_indicator.dart';
import '../models/story_item.dart';
import '../models/story_view_indicator_config.dart';
import '../controller/flutter_story_controller.dart';
import '../story_presenter/image_story_view.dart';
import '../story_presenter/video_story_view.dart';
import '../story_presenter/web_story_view.dart';
import '../story_presenter/text_story_view.dart';
import '../utils/story_utils.dart';
import 'package:video_player/video_player.dart';

typedef OnStoryChanged = void Function(int);
typedef OnCompleted = Future<void> Function();
typedef OnLeftTap = Future<bool> Function();
typedef OnRightTap = Future<bool> Function();
typedef OnDrag = void Function();
typedef OnItemBuild = Widget? Function(int, Widget);
typedef OnVideoLoad = void Function(VideoPlayerController);
typedef CustomViewBuilder = Widget Function();
typedef OnSlideDown = void Function(DragUpdateDetails);
typedef OnSlideStart = void Function(DragStartDetails);
typedef OnPause = Future<bool> Function();
typedef OnResume = Future<bool> Function();
typedef IndicatorWrapper = Widget Function(Widget child);

final durationNotifier = ValueNotifier(const Duration(seconds: 5));

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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  VideoPlayerController? _currentVideoPlayer;

  late final StoryController _storyController;
  late final PageController pageController;

  @override
  void initState() {
    super.initState();

    _initStoryController();

    _animationController = AnimationController(
      vsync: this,
    );

    pageController = PageController(initialPage: _storyController.page);

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
    _animationController.dispose();

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _disposeStoryController() {
    _storyController.removeListener(_storyControllerListener);
    if (widget.storyController == null) {
      _storyController.dispose();
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
      _currentVideoPlayer?.play();
      _animationController.forward(from: _animationController.value);
    }

    /// Pauses the media playback.
    void pauseMedia() {
      _currentVideoPlayer?.pause();
      _animationController.stop(canceled: false);
    }

    /// Plays the next story item.
    void playNext() async {
      if (_storyController.page == widget.items.length - 1) {
        await widget.onCompleted?.call();
        return;
      } else {
        _storyController.page += 1;
        pageController.jumpToPage(_storyController.page);
      }
    }

    /// Plays the previous story item.
    void playPrevious() {
      if (_storyController.page == 0) {
        widget.onPreviousCompleted?.call();
      } else {
        _storyController.page -= 1;
        pageController.jumpToPage(_storyController.page);
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
    _animationController.reset();
    _animationController.removeStatusListener(animationStatusListener);
  }

  /// Starts the countdown for the story item duration.
  void _startStoryCountdown(Duration duration) {
    Future(() {
      _resetAnimation();

      durationNotifier.value = duration;
      _animationController.duration = duration;
      _animationController.addStatusListener(animationStatusListener);
      _animationController.forward();
    });
  }

  /// Listener for the animation status.
  void animationStatusListener(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _storyController.next();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: pageController,
      allowImplicitScrolling: true,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: (index) {
        _resetAnimation();
        _currentVideoPlayer?.pause();
        _currentVideoPlayer?.seekTo(Duration.zero);
        widget.onStoryChanged?.call(index);
      },
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];

        return Stack(
          fit: StackFit.expand,
          children: [
            _buildContent(context, index, item),
            _buildProgressBar(context, index, item),
            ..._buildGestures(context, index, item),
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
      },
    );
  }

  Widget _buildContent(BuildContext context, int index, StoryItem item) {
    switch (item.storyItemType) {
      case StoryItemType.image:
        return ImageStoryView(
          key: UniqueKey(),
          storyItem: item,
          onVisibilityChanged: (isVisible, isLoaded) {
            if (isVisible && isLoaded) {
              _startStoryCountdown(item.duration);
            }
          },
        );

      case StoryItemType.video:
        return VideoStoryView(
          storyItem: item,
          key: UniqueKey(),
          looping: false,
          onVisibilityChanged: (videoPlayer, isvisible) {
            if (isvisible && videoPlayer != null) {
              _currentVideoPlayer = videoPlayer;
              videoPlayer.play();

              _startStoryCountdown(videoPlayer.value.duration);
            } else {
              _currentVideoPlayer = null;
              videoPlayer?.pause();
              videoPlayer?.seekTo(Duration.zero);
            }
          },
        );

      case StoryItemType.text:
        return TextStoryView(
          storyItem: item,
          key: UniqueKey(),
          onVisibilityChanged: (isLoaded, isVisible) {
            if (isLoaded && isVisible) {
              _startStoryCountdown(item.duration);
            }
          },
        );

      case StoryItemType.web:
        return WebStoryView(
          storyItem: item,
          key: UniqueKey(),
          onWebViewLoaded: (controller, loaded) {
            if (loaded) {
              _startStoryCountdown(item.duration);
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
          builder: () {
            return item.customWidget!(widget.storyController) ??
                const SizedBox.shrink();
          },
          storyItem: item,
          onVisibilityChanged: (isVisible) {
            if (isVisible) {
              _startStoryCountdown(item.duration);
            }
          },
        );
    }
  }

  Widget _buildProgressBar(BuildContext context, int index, StoryItem item) {
    final child = ValueListenableBuilder(
        valueListenable: durationNotifier,
        builder: (context, duration, child) {
          return Align(
            alignment: storyViewIndicatorConfig.alignment,
            child: Padding(
              padding: storyViewIndicatorConfig.margin,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return StoryViewIndicator(
                    currentIndex: index,
                    currentItemAnimatedValue: _animationController.value,
                    totalItems: widget.items.length,
                    storyViewIndicatorConfig: storyViewIndicatorConfig,
                  );
                },
              ),
            ),
          );
        });

    return widget.indicatorWrapper?.call(child) ?? child;
  }

  List<Widget> _buildGestures(BuildContext context, int index, StoryItem item) {
    final mdSize = MediaQuery.sizeOf(context);

    return [
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
            key: UniqueKey(),
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
    ];
  }
}
