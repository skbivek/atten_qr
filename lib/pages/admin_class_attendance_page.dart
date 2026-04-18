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
  List<Map<String, dynamic>> sessionsWithRecords = [];
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

      List<Map<String, dynamic>> tempSessions = [];
      Map<String, int> totalSessionsPerStudent = {};
      Map<String, int> presentSessionsPerStudent = {};

      for (var sessionDoc in sessionsQuery.docs) {
        final sessionTime = (sessionDoc.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

        final attendances = await FirebaseFirestore.instance
            .collection('sessions')
            .doc(sessionDoc.id)
            .collection('attendances')
            .get();

        List<Map<String, dynamic>> sessionRecords = [];

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

          sessionRecords.add({
            'studentId': studentId,
            'studentName': studentName,
            'status': status,
            'date': "${attTime.year}-${attTime.month.toString().padLeft(2, '0')}-${attTime.day.toString().padLeft(2, '0')}",
            'time': "${attTime.hour.toString().padLeft(2, '0')}:${attTime.minute.toString().padLeft(2, '0')}",
            'rawDate': attTime,
          });
        }
        
        final dateStr = "${sessionTime.year}-${sessionTime.month.toString().padLeft(2, '0')}-${sessionTime.day.toString().padLeft(2, '0')}";
        final timeStr = "${sessionTime.hour.toString().padLeft(2, '0')}:${sessionTime.minute.toString().padLeft(2, '0')}";

        tempSessions.add({
          'sessionId': sessionDoc.id,
          'date': dateStr,
          'time': timeStr,
          'rawDate': sessionTime,
          'records': sessionRecords,
        });
      }

      // Calculate percentages
      totalSessionsPerStudent.forEach((id, total) {
        final present = presentSessionsPerStudent[id] ?? 0;
        studentPercentages[id] = (present / total) * 100;
      });

      tempSessions.sort((a, b) => (b['rawDate'] as DateTime).compareTo(a['rawDate'] as DateTime));

      if (mounted) {
        setState(() {
          sessionsWithRecords = tempSessions;
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
    if (sessionsWithRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export!')));
      return;
    }

    final StringBuffer csv = StringBuffer();
    csv.writeln("Session Date,Session Time,Student Name,Status,Percentage");

    for (var session in sessionsWithRecords) {
      final records = session['records'] as List<Map<String, dynamic>>;
      for (var record in records) {
        final studentId = record['studentId'];
        final percentage = studentPercentages[studentId]?.toStringAsFixed(1) ?? '0.0';
        csv.writeln("${session['date']},${session['time']},${record['studentName']},${record['status']},$percentage%");
      }
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
          : sessionsWithRecords.isEmpty
              ? const Center(child: Text('No attendance history found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sessionsWithRecords.length,
                  itemBuilder: (context, index) {
                    final session = sessionsWithRecords[index];
                    final records = session['records'] as List<Map<String, dynamic>>;
                    final presentCount = records.where((r) => r['status'] == 'present').length;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          collapsedIconColor: const Color(0xFF4F46E5),
                          iconColor: const Color(0xFF4F46E5),
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            "${session['date']} at ${session['time']}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Text(
                            'Total Attendees: $presentCount/${records.length}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          children: records.map((record) {
                            final isPresent = record['status'] == 'present';
                            final percentage = studentPercentages[record['studentId']]?.toStringAsFixed(1) ?? '0.0';

                            return Container(
                              decoration: BoxDecoration(
                                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isPresent ? Colors.green.shade50 : Colors.red.shade50,
                                  child: Icon(
                                    isPresent ? Icons.check : Icons.close,
                                    color: isPresent ? Colors.green.shade600 : Colors.red.shade600,
                                  ),
                                ),
                                title: Text(
                                  record['studentName'],
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text("Performance: $percentage%"),
                                trailing: Container(
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
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
