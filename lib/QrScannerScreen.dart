import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool isCameraPermissionGranted = false;
  bool isFlashOn = false;
  bool isScanning = true;
  bool isFrontCamera = false;
  bool hasPermission = false;
  List<String> scanHistory = [];
  String scanResult = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCameraPermission();
  }
  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      controller?.pauseCamera();
    } else if (state == AppLifecycleState.resumed) {
      controller?.resumeCamera();
    }
  }

 Future<void> _checkCameraPermission() async {
    try {
      final status = await Permission.camera.status;

      if (status.isGranted) {
        setState(() => hasPermission = true);
      } else if (status.isDenied) {
        final result = await Permission.camera.request();
        setState(() => hasPermission = result.isGranted);

        if (!hasPermission) {
          // Show explanation why permission is needed
          if (await Permission.camera.shouldShowRequestRationale) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Permission Required'),
                content: const Text('Camera access is needed to scan QR codes'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await openAppSettings();
                    },
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            );
          }
        }
      } else if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (!isScanning) return;
      setState(() {
        scanResult = scanData.code ?? 'No data found';
        scanHistory.add(scanResult);
      });
      _showResultDialog(scanResult);
    });
  }

  void _showResultDialog(String? data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan Result'),
        content: SingleChildScrollView(
          child: Text(data ?? 'No data'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _resumeScanning();
              },
              child: const Text('Scan Again')),
        ],
      ),
    );
  }

  void _resumeScanning() {
    setState(() => isScanning = true);
  }

  void _toggleFlash() async {
    await controller?.toggleFlash();
    setState(() => isFlashOn = !isFlashOn);
  }

  void _switchCamera() async {
    await controller?.flipCamera();
    setState(() => isFrontCamera = !isFrontCamera);
  }

  void _pauseCamera() async {
    await controller?.pauseCamera();
    setState(() => isScanning = false);
  }
  void _resumeCamera() async {
    await controller?.resumeCamera();
    setState(() => isScanning = true);
  }
  void _showHistory(){
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Scan History',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: scanHistory.length,
                itemBuilder: (ctx, index) => ListTile(
                  title: Text(scanHistory[index]),
                  onTap: () {
                    setState(() => scanResult = scanHistory[index]);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            'Qr code Scanner',
          ),
          actions: [
            IconButton(
              icon: Icon(isFlashOn ? Icons.flash_off : Icons.flash_on),
              onPressed: _toggleFlash,
            ),
            IconButton(
                onPressed: _switchCamera,
                icon: Icon(
                    isFrontCamera ? Icons.camera_rear : Icons.camera_front)),
            IconButton(
                onPressed: _showHistory, icon: const Icon(Icons.history)),
          ],
          backgroundColor: Colors.blue.shade300,
        ),
        body: Column(
          children: [
            Expanded(
              flex: 5,
              child: hasPermission
                  ? QRView(
                      key: qrKey,
                      onQRViewCreated: _onQRViewCreated,
                      overlay: QrScannerOverlayShape(
                        borderColor: Colors.red,
                        borderRadius: 10,
                        borderLength: 30,
                        borderWidth: 10,
                        cutOutSize: 250,
                      ),
                  )
                  : Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Camera permission is required to scan QR codes.'),
                      ElevatedButton(
                        onPressed: _checkCameraPermission,
                        child: const Text('Request Permission'),
                      ),
                    ],
                  )),
            ),
            Expanded(
              flex: 1,
              child: Center(
                  child: SingleChildScrollView(
                    padding : const EdgeInsets.all(16),
                    child: Text(scanResult,style:const TextStyle(fontSize:18),
                      textAlign: TextAlign.center,),
                  ),),
            ),
            Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: isScanning ? _pauseCamera : _resumeCamera,
                  child: Text(isScanning ? 'Pause' : 'Resume'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      scanResult = 'Scan a QR code';
                      isScanning = true;
                    });
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
            ),
          ],
        ));
  }

  
}
