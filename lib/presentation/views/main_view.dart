import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_constants.dart';
import '../../data/models/device_model.dart';
import '../controllers/main_controller.dart';
import '../widgets/custom_dialog.dart';
import '../widgets/media_background_widget.dart';
import '../widgets/weather_widget.dart';
import 'code_view.dart';

class MainView extends StatefulWidget {
  final DeviceData? initialDeviceData;

  const MainView({super.key, this.initialDeviceData});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  // Focus node to receive remote control key events
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MainController>().init(widget.initialDeviceData);
      // Request focus so key events are delivered to this widget
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _checkDialogMessage(MainController controller) {
    if (controller.dialogMessage != null) {
      final msg = controller.dialogMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => CustomNoteDialog(
            message: msg,
            onClose: () {
              Navigator.of(context).pop();
              controller.clearDialogMessage();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const CodeView()),
              );
            },
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MainController>();
    _checkDialogMessage(controller);

    final deviceData = controller.deviceData;
    final mediaPath = deviceData?.deviceVideo;
    final logoPath = deviceData?.deviceLogo;
    final guestName = deviceData?.guestName ?? "";
    final guestMessage = deviceData?.guestMessage ?? "";

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      // Any remote key press closes the app
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          SystemNavigator.pop();
        }
      },
      child: GestureDetector(
        // Touch/click anywhere also closes the app
        onTap: () => SystemNavigator.pop(),
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
        backgroundColor: const Color(0xFF1B1B1B),
      body: Row(
        children: [
          // Left Side Panel
          Container(
            width: 220,
            height: double.infinity,
            color: const Color(0xFF181818),
            child: SingleChildScrollView(
              child: Column(
                children: [
                // Logo container at top — only shown when a valid logo exists.
                // Uses a StatefulBuilder so the white box collapses if the
                // image fails to load (e.g. backend returns a stale default).
                if (logoPath != null && logoPath.isNotEmpty)
                  _LogoWidget(logoUrl: ApiConstants.getFullStorageUrl(logoPath)),
                const SizedBox(height: 36),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Go to tv",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 65,
                      height: 2,
                      color: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

          // Right Main Content Area
          Expanded(
            child: Stack(
              children: [
                // Background Video or Image Media
                Positioned.fill(
                  child: MediaBackgroundWidget(
                    key: ValueKey<String>(
                      "${deviceData?.bgType}_${deviceData?.deviceVideo}_${deviceData?.bgImgs?.map((e) => e.bgImg).join('_')}",
                    ),
                    mediaPath: mediaPath,
                    bgImgs: deviceData?.bgImgs,
                    showVideo: deviceData?.showVideo,
                    showImages: deviceData?.showImages,
                    bgType: deviceData?.bgType,
                  ),
                ),

                // Overlay gradient tint for optimal readability
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withAlpha(80),
                          Colors.black.withAlpha(60),
                          Colors.black.withAlpha(180),
                        ],
                      ),
                    ),
                  ),
                ),

                // Top Right Weather Display
                Positioned(
                  top: 24,
                  right: 32,
                  child: WeatherWidget(weatherData: controller.weatherData),
                ),

                // Bottom Left Overlay: Guest Name & Message
                Positioned(
                  left: 40,
                  right: 40,
                  bottom: 40,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (guestName.isNotEmpty)
                          Text(
                            guestName,
                            style: GoogleFonts.inter(
                              color: const Color(0xFFFFE389),
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withAlpha(200),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        if (guestName.isNotEmpty && guestMessage.isNotEmpty)
                          const SizedBox(height: 12),
                        if (guestMessage.isNotEmpty)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 180),
                            child: SingleChildScrollView(
                              child: Text(
                                guestMessage,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 18,
                                  height: 1.45,
                                  fontWeight: FontWeight.w400,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withAlpha(200),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ), // Scaffold
      ), // GestureDetector
    ); // KeyboardListener
  }
}

/// A self-contained logo widget that collapses entirely (zero height) when
/// the image URL is unavailable or returns an error. This prevents the white
/// container from showing when no custom logo has been set.
class _LogoWidget extends StatefulWidget {
  final String logoUrl;
  const _LogoWidget({required this.logoUrl});

  @override
  State<_LogoWidget> createState() => _LogoWidgetState();
}

class _LogoWidgetState extends State<_LogoWidget> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (_hasError) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      height: 140,
      color: Colors.white,
      alignment: Alignment.center,
      child: CachedNetworkImage(
        imageUrl: widget.logoUrl,
        fit: BoxFit.contain,
        width: 180,
        height: 100,
        placeholder: (context, url) => const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.black54,
          ),
        ),
        errorWidget: (context, url, err) {
          // Collapse the container on next frame when image fails
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _hasError = true);
          });
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
