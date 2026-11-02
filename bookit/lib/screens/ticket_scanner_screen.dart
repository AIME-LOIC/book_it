import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// Full-screen QR scanner drivers use to redeem passengers' tickets.
///
/// Pops `true` after a successful redemption so the caller (driver dashboard)
/// knows the passenger manifest may have changed and can refresh it.
class TicketScannerScreen extends StatefulWidget {
  const TicketScannerScreen({super.key});

  @override
  State<TicketScannerScreen> createState() => _TicketScannerScreenState();
}

class _TicketScannerScreenState extends State<TicketScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(autoStart: true);
  bool _busy = false;

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _validateQr(Barcode barcode) async {
    final token = barcode.rawValue;
    if (_busy || token == null || token.trim().isEmpty) return;
    await _validate(() => ApiClient.post('tickets/validate/qr', body: {'token': token.trim()}, auth: true));
  }

  Future<void> _validateNumber(String ticketNumber) =>
      _validate(() => ApiClient.post('tickets/validate/number', body: {'ticket_number': ticketNumber.trim()}, auth: true));

  Future<void> _validate(Future<dynamic> Function() call) async {
    _busy = true;
    // Pause while the request runs so one ticket can't be scanned twice.
    try { await _controller.stop(); } catch (_) {}
    try {
      final result = await call();
      if (!mounted) return;
      final redeemed = await _showResult(result);
      if (!mounted) return;
      if (redeemed) Navigator.of(context).pop(true); // manifest changed upstream
    } on ApiException catch (e) {
      if (mounted) _showResult({'valid': false, 'reason': e.message});
    } catch (_) {
      if (mounted) _showResult({'valid': false, 'reason': 'Could not validate the ticket. Check your connection and try again.'});
    }
    _busy = false;
  }

  /// Shows the green VALID / red INVALID sheet. Returns true when a ticket
  /// was actually redeemed (scanning must not resume — we pop instead).
  Future<bool> _showResult(dynamic result) async {
    final valid = result is Map && result['valid'] == true;
    final ticket = valid && result['ticket'] is Map ? Map<String, dynamic>.from(result['ticket'] as Map) : <String, dynamic>{};
    final reason = result is Map ? (result['reason'] ?? result['message'])?.toString() ?? '' : '';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(padding: const EdgeInsets.fromLTRB(22, 22, 22, 26), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: (valid ? AppColors.success : AppColors.danger).withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
            child: Icon(valid ? Icons.check_circle_rounded : Icons.cancel_rounded, color: valid ? AppColors.success : AppColors.danger, size: 26)),
          const SizedBox(width: 12),
          Expanded(child: Text(valid ? 'VALID' : 'INVALID', style: TextStyle(color: valid ? AppColors.success : AppColors.danger, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.2))),
        ]),
        const SizedBox(height: 16),
        if (valid) ...[
          Text(ticket['passenger'] is Map && ticket['passenger']['name'] != null ? ticket['passenger']['name'].toString() : (ticket['passenger']?.toString() ?? 'Passenger'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textDark)),
          const SizedBox(height: 4),
          Text('Seat ${ticket['seat_number'] ?? '—'} • ${ticket['ticket_number'] ?? ''}', style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text('${ticket['boarding'] ?? '—'}  →  ${ticket['dropoff'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
          Text('Bus ${ticket['plate_number'] ?? '—'} • ${ticket['departure_time'] ?? ''}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ] else
          Text(reason.isNotEmpty ? reason : 'Ticket could not be validated.', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: valid ? AppColors.success : AppColors.danger, foregroundColor: Colors.white),
          onPressed: () { Navigator.of(context).pop(); _resume(); },
          icon: const Icon(Icons.center_focus_strong_rounded),
          label: const Text('Scan next'))),
      ])),
    );
    return valid;
  }

  Future<void> _resume() async {
    if (_busy) return;
    try { await _controller.start(); } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _enterNumberManually() async {
    final number = await showDialog<String>(
      context: context,
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        final fieldController = TextEditingController();
        return AlertDialog(
          title: const Text('Enter ticket number', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Form(key: formKey, child: TextFormField(
            controller: fieldController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Ticket number', hintText: 'e.g. BK-2026-000123'),
            validator: (value) => value == null || value.trim().isEmpty ? 'Ticket number is required' : null,
            onFieldSubmitted: (value) {
              if (formKey.currentState?.validate() ?? false) Navigator.of(context).pop(value.trim());
            },
          )),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(onPressed: () {
              if (formKey.currentState?.validate() ?? false) Navigator.of(context).pop(fieldController.text.trim());
            }, child: const Text('Validate')),
          ],
        );
      },
    );
    if (number == null || number.isEmpty) { _resume(); return; }
    await _validateNumber(number);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(children: [
      MobileScanner(
        controller: _controller,
        errorBuilder: (context, error) => _buildCameraError(context, error),
        onDetect: (capture) {
          for (final barcode in capture.barcodes) { _validateQr(barcode); }
        },
      ),
      // Scanning frame overlay.
      Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _FramePainter()))),
      // Top controls: close + torch.
      SafeArea(child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(tooltip: 'Close scanner', style: IconButton.styleFrom(backgroundColor: Colors.black45, foregroundColor: Colors.white),
          onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
        IconButton(tooltip: 'Toggle torch', style: IconButton.styleFrom(backgroundColor: Colors.black45, foregroundColor: Colors.white),
          onPressed: () async { try { await _controller.toggleTorch(); } catch (_) {} }, icon: const Icon(Icons.flashlight_on_rounded)),
      ])),
      // Manual entry fallback.
      Positioned(left: 0, right: 0, bottom: 34, child: Center(child: Column(children: [
        const Text('Align the passenger’s QR code inside the frame', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.black45,
            side: const BorderSide(color: Colors.white38), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.buttonRadius))),
          onPressed: _enterNumberManually,
          icon: const Icon(Icons.keyboard_rounded),
          label: const Text('Enter ticket number')),
      ]))),
    ]),
  );

  Widget _buildCameraError(BuildContext context, MobileScannerException error) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(denied ? Icons.no_photography_rounded : Icons.camera_alt_rounded, color: Colors.white54, size: 46),
      const SizedBox(height: 14),
      Text(denied ? 'Camera permission denied' : 'Camera could not start', textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(
        denied
          ? 'BookIt uses the camera to scan passenger tickets. Allow camera access in your device settings and reopen the scanner.'
          : '${error.errorDetails?.message ?? ''} Restart the scanner or try again.',
        textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      const SizedBox(height: 18),
      if (denied) FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
        onPressed: () => Geolocator.openAppSettings(),
        icon: const Icon(Icons.settings_rounded),
        label: const Text('Open settings')),
      if (!denied) ...[
        const SizedBox(height: 4),
        OutlinedButton(onPressed: _resume, style: OutlinedButton.styleFrom(foregroundColor: Colors.white), child: const Text('Try again')),
      ],
      const SizedBox(height: 10),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
        onPressed: _enterNumberManually,
        icon: const Icon(Icons.keyboard_rounded),
        label: const Text('Enter ticket number')),
    ])));
  }
}

/// Darkened viewfinder with a clear centre frame for the QR code.
class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final boxWidth = size.width * 0.74;
    final boxHeight = boxWidth;
    final topLeft = Offset((size.width - boxWidth) / 2, (size.height - boxHeight) / 2 - size.height * 0.04);
    final box = Rect.fromLTWH(topLeft.dx, topLeft.dy, boxWidth, boxHeight);

    // Dim everything outside the frame plus a peripheral gradient.
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(0))),
        Path()..addRRect(RRect.fromRectAndRadius(box, const Radius.circular(20)))),
      Paint()..color = const Color(0x66000000),
    );

    // Corner brackets.
    final stroke = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round;
    const cornerLength = 32.0;
    for (final corner in [box.topLeft, Offset(box.right, box.top), box.bottomLeft, Offset(box.right, box.bottom)]) {
      final dx = corner.dx == box.right ? -1 : 1;
      final dy = corner.dy == box.bottom ? -1 : 1;
      canvas.drawLine(corner, Offset(corner.dx + dx * cornerLength, corner.dy), stroke);
      canvas.drawLine(corner, Offset(corner.dx, corner.dy + dy * cornerLength), stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _FramePainter oldDelegate) => false;
}
