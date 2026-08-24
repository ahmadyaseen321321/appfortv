import 'dart:convert';
import 'package:flutter/foundation.dart';

class DeviceResponse {
  final bool? status;
  final String? message;
  final DeviceData? data;
  final List<DeviceData>? dataList;

  DeviceResponse({
    this.status,
    this.message,
    this.data,
    this.dataList,
  });

  factory DeviceResponse.fromJson(Map<String, dynamic> json) {
    DeviceData? singleData;
    List<DeviceData>? listData;

    final rawData = json['data'];
    if (rawData is List) {
      listData = rawData.map((e) => DeviceData.fromJson(e as Map<String, dynamic>)).toList();
      if (listData.isNotEmpty) {
        singleData = listData.first;
      }
    } else if (rawData is Map<String, dynamic>) {
      singleData = DeviceData.fromJson(rawData);
    }

    return DeviceResponse(
      status: json['status'] as bool?,
      message: json['message'] as String?,
      data: singleData,
      dataList: listData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'data': data?.toJson(),
    };
  }
}

class BgImage {
  final int? id;
  final int? deviceId;
  final String? bgImg;

  BgImage({this.id, this.deviceId, this.bgImg});

  factory BgImage.fromJson(Map<String, dynamic> json) {
    return BgImage(
      id: json['id'] is int ? json['id'] as int? : int.tryParse(json['id']?.toString() ?? ''),
      deviceId: json['device_id'] is int ? json['device_id'] as int? : int.tryParse(json['device_id']?.toString() ?? ''),
      bgImg: json['bg_img']?.toString() ?? json['image']?.toString() ?? json['url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'bg_img': bgImg,
    };
  }
}

class DeviceData {
  final int? id;
  final int? userId;
  final String? deviceVideo;
  final String? deviceLogo;
  final String? tvName;
  final int? count;
  final String? guestName;
  final String? deviceCode;
  final String? guestMessage;
  final String? lat;
  final String? longitude;
  final String? temprature;
  final String? deviceStatus;
  final String? createdAt;
  final String? updatedAt;
  final String? deviceWifi;
  final String? devicePassword;
  final String? randomToken;
  final String? deviceToken;
  final List<BgImage>? bgImgs;
  final String? subscriptionPlan;
  final bool? showVideo;
  final bool? showImages;
  final String? bgType;
  final String? weatherIcon;
  final String? weatherDesc;

  DeviceData({
    this.id,
    this.userId,
    this.deviceVideo,
    this.deviceLogo,
    this.tvName,
    this.count,
    this.guestName,
    this.deviceCode,
    this.guestMessage,
    this.lat,
    this.longitude,
    this.temprature,
    this.deviceStatus,
    this.createdAt,
    this.updatedAt,
    this.deviceWifi,
    this.devicePassword,
    this.randomToken,
    this.deviceToken,
    this.bgImgs,
    this.subscriptionPlan,
    this.showVideo,
    this.showImages,
    this.bgType,
    this.weatherIcon,
    this.weatherDesc,
  });

  factory DeviceData.fromJson(Map<String, dynamic> json) {
    List<BgImage>? parsedBgImgs;
    dynamic bgImgsRaw = json['bg_imgs'] ?? json['bg_images'] ?? json['bgImgs'];
    if (bgImgsRaw is String) {
      try {
        bgImgsRaw = jsonDecode(bgImgsRaw);
      } catch (_) {}
    }
    if (bgImgsRaw is List) {
      parsedBgImgs = bgImgsRaw.map((e) {
        if (e is Map) {
          return BgImage.fromJson(Map<String, dynamic>.from(e));
        } else if (e is String) {
          return BgImage(bgImg: e);
        }
        return BgImage(bgImg: e?.toString());
      }).toList();
    }

    final bgTypeVal = json['bg_type']?.toString() ?? json['bgType']?.toString() ?? json['background_type']?.toString();

    debugPrint("=== [DEBUG] DeviceData.fromJson ===");
    debugPrint("-> RAW bg_type: ${json['bg_type']} (Parsed: $bgTypeVal)");
    debugPrint("-> RAW bg_imgs: ${json['bg_imgs']}");
    debugPrint("-> RAW show_video: ${json['show_video']}, show_images: ${json['show_images']}");
    debugPrint("-> RAW device_vedio: ${json['device_vedio']}");
    debugPrint("-> Parsed bgImgs count: ${parsedBgImgs?.length}");
    if (parsedBgImgs != null && parsedBgImgs.isNotEmpty) {
      for (int i = 0; i < parsedBgImgs.length; i++) {
        debugPrint("   Img[$i]: ${parsedBgImgs[i].bgImg}");
      }
    }
    debugPrint("===================================");

    return DeviceData(
      id: json['id'] is int ? json['id'] as int? : int.tryParse(json['id']?.toString() ?? ''),
      userId: json['user_id'] is int ? json['user_id'] as int? : int.tryParse(json['user_id']?.toString() ?? ''),
      deviceVideo: json['device_vedio']?.toString() ?? json['device_video']?.toString(),
      deviceLogo: _sanitizePath(json['device_logo']?.toString()),
      tvName: json['device_name']?.toString() ?? json['tv_name']?.toString(),
      count: json['count'] is int ? json['count'] as int? : int.tryParse(json['count']?.toString() ?? ''),
      guestName: json['device_heading']?.toString() ??
          json['guest_name']?.toString() ??
          json['device_name']?.toString(),
      deviceCode: json['device_code']?.toString(),
      guestMessage: json['device_description']?.toString() ??
          json['guest_message']?.toString(),
      lat: json['lat']?.toString(),
      longitude: json['longitude']?.toString(),
      temprature: json['temprature']?.toString(),
      deviceStatus: json['device_status']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      deviceWifi: json['device_wifi']?.toString(),
      devicePassword: json['device_password']?.toString(),
      randomToken: json['random_token']?.toString(),
      deviceToken: json['device_token']?.toString(),
      bgImgs: parsedBgImgs,
      subscriptionPlan: json['subscription_plan']?.toString(),
      showVideo: json['show_video'] is bool
          ? json['show_video'] as bool?
          : (json['show_video']?.toString() == 'true' || json['show_video']?.toString() == '1'),
      showImages: json['show_images'] is bool
          ? json['show_images'] as bool?
          : (json['show_images']?.toString() == 'true' || json['show_images']?.toString() == '1'),
      bgType: bgTypeVal,
      weatherIcon: _sanitizePath(json['weather_icon']?.toString()),
      weatherDesc: _sanitizePath(json['weather_desc']?.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'device_vedio': deviceVideo,
      'device_logo': deviceLogo,
      'tv_name': tvName,
      'count': count,
      'guest_name': guestName,
      'device_code': deviceCode,
      'guest_message': guestMessage,
      'lat': lat,
      'longitude': longitude,
      'temprature': temprature,
      'device_status': deviceStatus,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'device_wifi': deviceWifi,
      'device_password': devicePassword,
      'random_token': randomToken,
      'device_token': deviceToken,
      'bg_imgs': bgImgs?.map((e) => e.toJson()).toList(),
      'subscription_plan': subscriptionPlan,
      'show_video': showVideo,
      'show_images': showImages,
      'bg_type': bgType,
      'weather_icon': weatherIcon,
      'weather_desc': weatherDesc,
    };
  }

  /// Returns null if the path is empty, the literal string "null", or clearly
  /// a server-side placeholder/default (e.g. "images/hilton.png").
  /// This ensures removed assets are treated as absent on the TV display.
  static String? _sanitizePath(String? path) {
    if (path == null) return null;
    final trimmed = path.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.toLowerCase() == 'null') return null;
    return trimmed;
  }

  bool isVideoMedia() {
    if (deviceVideo == null || deviceVideo!.isEmpty) return false;
    final lower = deviceVideo!.toLowerCase();
    return !(lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp'));
  }
}
