import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants/api_constants.dart';
import '../../data/models/device_model.dart';

class MediaBackgroundWidget extends StatefulWidget {
  final String? mediaPath;
  final List<BgImage>? bgImgs;
  final bool? showVideo;
  final bool? showImages;
  final String? bgType;

  const MediaBackgroundWidget({
    super.key,
    this.mediaPath,
    this.bgImgs,
    this.showVideo,
    this.showImages,
    this.bgType,
  });

  @override
  State<MediaBackgroundWidget> createState() => _MediaBackgroundWidgetState();
}

class _MediaBackgroundWidgetState extends State<MediaBackgroundWidget> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _hasVideoError = false;
  String? _videoErrorMessage;

  Timer? _slideshowTimer;
  int _currentSlideIndex = 0;

  List<String> get _slideshowImages {
    if (widget.bgImgs != null && widget.bgImgs!.isNotEmpty) {
      final list = widget.bgImgs!
          .map((e) => e.bgImg)
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toList();
      if (list.isNotEmpty) return list;
    }
    return [];
  }

  bool get _mediaPathIsImage {
    if (widget.mediaPath == null || widget.mediaPath!.isEmpty) return false;
    final lower = widget.mediaPath!.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp') ||
        lower.contains('.jpg?') ||
        lower.contains('.jpeg?') ||
        lower.contains('.png?');
  }

  bool get _isVideoMode {
    final type = widget.bgType?.trim().toLowerCase();
    final images = _slideshowImages;
    bool result = false;

    if (type == "video" || type == "vid" || type == "1") {
      result = true;
    } else if (type == "image" ||
        type == "images" ||
        type == "img" ||
        type == "imgs" ||
        type == "slideshow" ||
        type == "0" ||
        type == "2") {
      result = false;
    } else if (widget.showVideo == true && widget.showImages != true) {
      result = true;
    } else if (widget.showImages == true || widget.showVideo == false) {
      result = false;
    } else if (images.isNotEmpty) {
      result = false;
    } else if (widget.mediaPath != null &&
        widget.mediaPath!.isNotEmpty &&
        !_mediaPathIsImage) {
      result = true;
    }

    debugPrint("=== [DEBUG] MediaBackgroundWidget._isVideoMode ===");
    debugPrint("-> bgType prop: '${widget.bgType}' (Normalized: '$type')");
    debugPrint("-> showVideo: ${widget.showVideo}, showImages: ${widget.showImages}");
    debugPrint("-> mediaPath: '${widget.mediaPath}'");
    debugPrint("-> slideshowImages count: ${images.length} -> $images");
    debugPrint("-> RESULT _isVideoMode = $result");
    debugPrint("=================================================");

    return result;
  }

  @override
  void initState() {
    super.initState();
    _initMedia();
  }

  @override
  void didUpdateWidget(covariant MediaBackgroundWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaPath != widget.mediaPath ||
        oldWidget.showVideo != widget.showVideo ||
        oldWidget.showImages != widget.showImages ||
        oldWidget.bgType != widget.bgType ||
        !_areListsEqual(oldWidget.bgImgs, widget.bgImgs)) {
      _disposeMedia();
      _initMedia();
    }
  }

  bool _areListsEqual(List<BgImage>? a, List<BgImage>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].bgImg != b[i].bgImg) return false;
    }
    return true;
  }

  void _initMedia() {
    final isVideo = _isVideoMode;
    final images = _slideshowImages;

    debugPrint("MediaBackgroundWidget _initMedia: bgType='${widget.bgType}', "
        "isVideoMode=$isVideo, mediaPath='${widget.mediaPath}', "
        "imagesCount=${images.length}");

    if (isVideo) {
      _slideshowTimer?.cancel();
      _slideshowTimer = null;
      _currentSlideIndex = 0;
      if (widget.mediaPath != null &&
          widget.mediaPath!.isNotEmpty &&
          !_mediaPathIsImage) {
        _startVideo();
      }
    } else {
      _videoController?.pause();
      _videoController?.dispose();
      _videoController = null;
      _isVideoInitialized = false;
      _hasVideoError = false;
      if (images.isNotEmpty) {
        _startSlideshowTimer(images.length);
      }
    }
  }

  void _startVideo() {
    setState(() {
      _hasVideoError = false;
      _videoErrorMessage = null;
      _isVideoInitialized = false;
    });

    final fullUrl = ApiConstants.getFullStorageUrl(widget.mediaPath);
    debugPrint("Initializing VideoPlayer with URL: $fullUrl");

    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(fullUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
            _hasVideoError = false;
          });
          _videoController?.setLooping(true);
          _videoController?.play();
        }
      }).catchError((error) {
        debugPrint("Video error: $error");
        if (mounted) {
          setState(() {
            _hasVideoError = true;
            _videoErrorMessage = error.toString();
          });
        }
      });
  }

  void _startSlideshowTimer(int count) {
    _slideshowTimer?.cancel();
    if (count <= 1) return;
    _slideshowTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        setState(() {
          _currentSlideIndex = (_currentSlideIndex + 1) % count;
        });
      }
    });
  }

  void _disposeMedia() {
    _slideshowTimer?.cancel();
    _slideshowTimer = null;
    _currentSlideIndex = 0;
    _videoController?.dispose();
    _videoController = null;
    _isVideoInitialized = false;
    _hasVideoError = false;
    _videoErrorMessage = null;
  }

  @override
  void dispose() {
    _disposeMedia();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = _isVideoMode;
    final images = _slideshowImages;

    if (isVideo) {
      if (_isVideoInitialized && _videoController != null) {
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          ),
        );
      }

      if (_hasVideoError) {
        return Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.amberAccent, size: 48),
              const SizedBox(height: 12),
              const Text(
                "Unable to load video background",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                _videoErrorMessage ?? '',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
      );
    }

    // Image / Slideshow
    if (images.isNotEmpty) {
      final safeIndex = _currentSlideIndex < images.length ? _currentSlideIndex : 0;
      final fullUrl = ApiConstants.getFullStorageUrl(images[safeIndex]);
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 1000),
        child: SizedBox.expand(
          key: ValueKey<String>(fullUrl),
          child: CachedNetworkImage(
            imageUrl: fullUrl,
            fit: BoxFit.fill,
            width: double.infinity,
            height: double.infinity,
            placeholder: (_, __) => Container(color: Colors.black),
            errorWidget: (_, __, ___) => Container(
              color: Colors.black,
              child: const Icon(Icons.broken_image, color: Colors.white54, size: 48),
            ),
          ),
        ),
      );
    }

    if (_mediaPathIsImage && widget.mediaPath != null) {
      final fullUrl = ApiConstants.getFullStorageUrl(widget.mediaPath);
      return SizedBox.expand(
        child: CachedNetworkImage(
          imageUrl: fullUrl,
          fit: BoxFit.fill,
          width: double.infinity,
          height: double.infinity,
          placeholder: (_, __) => Container(color: Colors.black),
          errorWidget: (_, __, ___) => Container(
            color: Colors.black,
            child: const Icon(Icons.broken_image, color: Colors.white54, size: 48),
          ),
        ),
      );
    }

    return Container(color: Colors.black);
  }
}
