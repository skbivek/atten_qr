import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminClassAttendancePage extends StatefulWidget {
  final String classId;
  final String classTitle;
  final String joinCode;

  const AdminClassAttendancePage({
    super.key,
    required this.classId,
    required this.classTitle,
    required this.joinCode,
  });

  @override
  State<AdminClassAttendancePage> createState() => _AdminClassAttendancePageState();
}

class _AdminClassAttendancePageState extends State<AdminClassAttendancePage> {
  bool isLoading = true;
  List<Map<String, dynamic>> flatRecords = [];
  Map<String, double> studentPercentages = {};

  @override
  void initState() {
    super.initState();
    _fetchAttendanceData();
  }

  Future<void> _fetchAttendanceData() async {
    try {
      final sessionsQuery = await FirebaseFirestore.instance
          .collection('sessions')
          .where('joinCode', isEqualTo: widget.joinCode)
          .get();

      List<Map<String, dynamic>> tempRecords = [];
      Map<String, int> totalSessionsPerStudent = {};
      Map<String, int> presentSessionsPerStudent = {};

      for (var sessionDoc in sessionsQuery.docs) {
        final sessionTime = (sessionDoc.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

        final attendances = await FirebaseFirestore.instance
            .collection('sessions')
            .doc(sessionDoc.id)
            .collection('attendances')
            .get();

        for (var attDoc in attendances.docs) {
          final data = attDoc.data();
          final String studentId = data['studentId'] ?? '';
          final String studentName = data['studentName'] ?? 'Unknown';
          final String status = data['status'] ?? 'present';
          final attTime = (data['timestamp'] as Timestamp?)?.toDate() ?? sessionTime;

          totalSessionsPerStudent[studentId] = (totalSessionsPerStudent[studentId] ?? 0) + 1;
          if (status == 'present') {
            presentSessionsPerStudent[studentId] = (presentSessionsPerStudent[studentId] ?? 0) + 1;
          }

          tempRecords.add({
            'studentId': studentId,
            'studentName': studentName,
            'status': status,
            'date': "${attTime.year}-${attTime.month.toString().padLeft(2, '0')}-${attTime.day.toString().padLeft(2, '0')}",
            'time': "${attTime.hour.toString().padLeft(2, '0')}:${attTime.minute.toString().padLeft(2, '0')}",
            'rawDate': attTime,
          });
        }
      }

      // Calculate percentages
      totalSessionsPerStudent.forEach((id, total) {
        final present = presentSessionsPerStudent[id] ?? 0;
        studentPercentages[id] = (present / total) * 100;
      });

      tempRecords.sort((a, b) => (b['rawDate'] as DateTime).compareTo(a['rawDate'] as DateTime));

      if (mounted) {
        setState(() {
          flatRecords = tempRecords;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void exportToClipboard() {
    if (flatRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export!')));
      return;
    }

    final StringBuffer csv = StringBuffer();
    csv.writeln("Student Name,Date,Time,Status,Percentage");

    for (var record in flatRecords) {
      final studentId = record['studentId'];
      final percentage = studentPercentages[studentId]?.toStringAsFixed(1) ?? '0.0';
      
      csv.writeln("${record['studentName']},${record['date']},${record['time']},${record['status']},$percentage%");
    }

    Clipboard.setData(ClipboardData(text: csv.toString())).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV copied to clipboard Successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text('${widget.classTitle} Attendance'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isLoading ? null : exportToClipboard,
        icon: const Icon(Icons.copy, color: Colors.white),
        label: const Text('Export CSV', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF4F46E5),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : flatRecords.isEmpty
              ? const Center(child: Text('No attendance history found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: flatRecords.length,
                  itemBuilder: (context, index) {
                    final record = flatRecords[index];
                    final isPresent = record['status'] == 'present';
                    final percentage = studentPercentages[record['studentId']]?.toStringAsFixed(1) ?? '0.0';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: isPresent ? Colors.green.shade50 : Colors.red.shade50,
                              child: Icon(
                                isPresent ? Icons.check : Icons.close,
                                color: isPresent ? Colors.green.shade600 : Colors.red.shade600,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    record['studentName'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                      "${record['date']} at ${record['time']} | Total: $percentage%"),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isPresent ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isPresent ? 'Present' : 'Absent',
                                style: TextStyle(
                                  color: isPresent ? Colors.green.shade700 : Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
