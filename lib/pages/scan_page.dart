import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide GeoPoint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScanPage extends StatefulWidget {
  final String classTitle;

  const ScanPage({super.key, required this.classTitle});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  // Primary function that handles the check-in logic when a QR code is detected
  Future<void> _processCheckIn(String qrRawData) async {
    // Prevent multiple check-ins if one is already processing
    if (_isProcessing) return;
    
    // Update UI to show loading indicator
    setState(() {
      _isProcessing = true;
    });

    // Pause the camera so it doesn't keep scanning while we talk to Firebase
    _scannerController.stop();

    try {
      final data = jsonDecode(qrRawData);
      // Extract session ID and the current rotating token
      final sessionId = data['s'];
      final token = data['t'];

      if (sessionId == null || token == null) {
        throw Exception("Invalid QR Code format.");
      }

      // 1. Validate token and record attendance safely
      final db = FirebaseFirestore.instance;
      
      // Run transaction to ensure token validation and attendance save are atomic
      // This prevents race conditions if a student scans multiple times quickly
      await db.runTransaction((transaction) async {
        final sessionRef = db.collection('sessions').doc(sessionId);
        final sessionSnap = await transaction.get(sessionRef);

        if (!sessionSnap.exists) {
          throw Exception("Session not found.");
        }

        final sessionData = sessionSnap.data()!;
        
        // Ensure the teacher hasn't ended the session yet
        if (sessionData['isActive'] != true) {
          throw Exception("This session is no longer active.");
        }

        // CRITICAL SECURITY CHECK: Ensure scanned token matches the currently active 30s token
        if (sessionData['activeToken'] != token) {
          throw Exception("Fake or Expired Attendance QR Code. Please scan the current one.");
        }

        // Get student info from Firestore to be certain we have the name
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) throw Exception("User not authenticated.");

        final userDocRef = db.collection('users').doc(uid);
        final userSnap = await transaction.get(userDocRef);
        
        if (!userSnap.exists) throw Exception("User profile not found.");
        
        String studentName = userSnap.data()?['name'] ?? 'Unknown Student';

        final attendanceRef = sessionRef.collection('attendances').doc(uid);
        final attendanceSnap = await transaction.get(attendanceRef);

        // Prevent duplicate check-ins for the same session
        if (attendanceSnap.exists) {
          throw Exception("You have already checked in.");
        }

        // Finally, save the attendance record with a server-side timestamp
        transaction.set(attendanceRef, {
          'studentId': uid,
          'studentName': studentName,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance recorded successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: Colors.red),
        );
        setState(() {
          _isProcessing = false;
        });
        _scannerController.start();
      }
    }
  }

  @override
  void dispose() {
    // Clean up camera resources when closing the page to prevent memory leaks
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Attendance'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // The camera view that continuously looks for QR codes
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              // Iterate through detected barcodes (usually just one)
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  // Trigger the check-in process with the raw text from the QR
                  _processCheckIn(barcode.rawValue!);
                  break; // Stop after finding the first valid code
                }
              }
            },
          ),
          // Loading overlay shown when checking in
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Verifying Attendance...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                 padding: const EdgeInsets.only(bottom: 40),
                 child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                   decoration: BoxDecoration(
                     color: Colors.black87,
                     borderRadius: BorderRadius.circular(20),
                   ),
                   child: const Text(
                     'Point camera at the Teacher\'s QR code',
                     style: TextStyle(color: Colors.white),
                   ),
                 ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
