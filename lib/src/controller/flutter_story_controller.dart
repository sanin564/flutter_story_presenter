import 'package:flutter/material.dart';

import '../utils/story_utils.dart';

/// A controller to manage the state and actions of a story view
class StoryController extends ChangeNotifier {
  StoryController({int initialIndex = 0}) : page = initialIndex;

  StoryAction _storyStatus = StoryAction.play;
  int page = 0;

  /// The current action status of the story. Defaults to playing.
  StoryAction get storyStatus => _storyStatus;

  set _setStatus(StoryAction status) {
    if (status == _storyStatus) return;
    _storyStatus = status;
    notifyListeners();
  }

  /// Sets the story status to play and notifies listeners of the change.
  void play() {
    _setStatus = StoryAction.play;
  }

  /// Sets the story status to pause and notifies listeners of the change.
  void pause() {
    _setStatus = StoryAction.pause;
  }

  /// Sets the story status to next (move to the next story) and notifies listeners of the change.
  void next() {
    _setStatus = StoryAction.next;
  }

  /// Sets the story status to mute (mute audio) and notifies listeners of the change.
  void mute() {
    _setStatus = StoryAction.mute;
  }

  /// Sets the story status to unMute (un-mute audio) and notifies listeners of the change.
  void unMute() {
    _setStatus = StoryAction.unMute;
  }

  /// Sets the story status to previous (move to the previous story) and notifies listeners of the change.
  void previous() {
    _setStatus = StoryAction.previous;
  }
}
