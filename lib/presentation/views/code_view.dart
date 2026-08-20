import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../controllers/code_controller.dart';
import '../widgets/custom_dialog.dart';
import 'main_view.dart';

class CodeView extends StatefulWidget {
  const CodeView({super.key});

  @override
  State<CodeView> createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSession();
    });
  }

  Future<void> _checkSession() async {
    final controller = context.read<CodeController>();
    final savedData = await controller.checkSavedSession();
    if (savedData != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainView(initialDeviceData: savedData),
        ),
      );
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onCodeChanged(String value) async {
    if (value.length == 5) {
      final controller = context.read<CodeController>();
      final success = await controller.validateAndSubmitCode(value);
      _codeController.clear();

      if (success && mounted) {
        final deviceData = controller.deviceData;
        if (deviceData != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => MainView(initialDeviceData: deviceData),
            ),
          );
        }
      } else if (controller.errorMessage != null && mounted) {
        _showErrorDialog(controller.errorMessage!);
      }
    }
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CustomNoteDialog(
        message: msg,
        onClose: () {
          Navigator.of(context).pop();
          context.read<CodeController>().clearErrorMessage();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CodeController>();

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Center(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _codeController,
                focusNode: _focusNode,
                autofocus: true,
                maxLength: 5,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.left,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 2,
                ),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "Enter 5 digit code",
                  hintStyle: GoogleFonts.inter(
                    color: Colors.white.withAlpha(200),
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                  ),
                  contentPadding: const EdgeInsets.only(bottom: 8),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white, width: 3.5),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white, width: 3.5),
                  ),
                ),
                onChanged: (val) {
                  setState(() {});
                  _onCodeChanged(val);
                },
              ),
              if (controller.isLoading) ...[
                const SizedBox(height: 24),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
