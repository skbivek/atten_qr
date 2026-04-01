import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRSessionPage extends StatefulWidget {
  final String classTitle;
  final String joinCode;

  const QRSessionPage({
    super.key,
    required this.classTitle,
    required this.joinCode,
  });

  @override
  State<QRSessionPage> createState() => _QRSessionPageState();
}

class _QRSessionPageState extends State<QRSessionPage> {
  String? sessionId;
  String currentToken = '';
  Timer? _tokenTimer;
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  Future<void> _startSession() async {
    _generateNewToken();

    try {
      final docRef = await FirebaseFirestore.instance.collection('sessions').add({
        'classTitle': widget.classTitle,
        'joinCode': widget.joinCode,
        'createdAt': FieldValue.serverTimestamp(),
        'activeToken': currentToken,
        'isActive': true,
      });

      setState(() {
        sessionId = docRef.id;
      });

      _tokenTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsLeft > 1) {
          if (mounted) {
            setState(() {
              _secondsLeft--;
            });
          }
        } else {
          _rotateToken();
        }
      });
    } catch (e) {
      debugPrint("Error creating session: $e");
    }
  }

  void _generateNewToken() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    currentToken = String.fromCharCodes(Iterable.generate(
        8, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  Future<void> _rotateToken() async {
    if (sessionId == null) return;
    
    _generateNewToken();
    if (mounted) {
      setState(() {
        _secondsLeft = 30;
      });
    }

    try {
      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(sessionId)
          .update({'activeToken': currentToken});
    } catch (e) {
      debugPrint("Error rotating token: $e");
    }
  }

  @override
  void dispose() {
    _tokenTimer?.cancel();
    if (sessionId != null) {
      FirebaseFirestore.instance
          .collection('sessions')
          .doc(sessionId)
          .update({'isActive': false}).catchError((e) => debugPrint(e.toString()));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qrData = sessionId != null 
      ? jsonEncode({'s': sessionId, 't': currentToken})
      : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('QR Attendance Session'),
        elevation: 0,
      ),
      body: sessionId == null 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                   QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.classTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join Code: ${widget.joinCode}',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Refreshes in $_secondsLeft seconds',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: const Text(
                'Live Attendance',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sessions')
                  .doc(sessionId)
                  .collection('attendances')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No students joined yet.'),
                    ),
                  );
                }

                var docs = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    String studentName = data['studentName'] ?? 'Unknown';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFFCCFBF1),
                            child: Text(
                              studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Color(0xFF0F766E),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              studentName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Present',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
