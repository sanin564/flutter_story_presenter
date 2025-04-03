import '../controller/flutter_story_controller.dart';

/// To Perform Action on Story with [FlutterStoryController]
enum StoryAction {
  play,
  pause,
  next,
  previous,
  mute,
  unMute,
}

/// Story Item Type to Display
enum StoryItemType {
  image,
  video,
  text,
  web,
  custom,
}

/// Story Item Source to Display Widgets from Asset/Network
enum StoryItemSource {
  asset,
  network,
  file,
}

extension StoryItemTypeExtensions on StoryItemType {
  bool get isImage => this == StoryItemType.image;

  bool get isVideo => this == StoryItemType.video;

  bool get isText => this == StoryItemType.text;

  bool get isWeb => this == StoryItemType.web;

  bool get isCustom => this == StoryItemType.custom;
}

extension StorySourceTypeExtensions on StoryItemSource {
  bool get isNetwork => this == StoryItemSource.network;

  bool get isAsset => this == StoryItemSource.asset;

  bool get isFile => this == StoryItemSource.file;
}
