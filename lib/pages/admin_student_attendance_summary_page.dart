import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminStudentAttendanceSummaryPage extends StatefulWidget {
  final String studentId;
  final String studentName;

  const AdminStudentAttendanceSummaryPage({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<AdminStudentAttendanceSummaryPage> createState() => _AdminStudentAttendanceSummaryPageState();
}

class _AdminStudentAttendanceSummaryPageState extends State<AdminStudentAttendanceSummaryPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> classAttendanceData = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // Aggregates attendance statistics across all classes for a single student
  Future<void> _fetchData() async {
    try {
      final classesQuery = await FirebaseFirestore.instance
          .collection('classes')
          .where('studentIds', arrayContains: widget.studentId)
          .get();

      List<Map<String, dynamic>> temp = [];

      for (var classDoc in classesQuery.docs) {
        final classData = classDoc.data();
        final joinCode = classData['joinCode'];
        final title = classData['title'];

        final sessionsQuery = await FirebaseFirestore.instance
            .collection('sessions')
            .where('joinCode', isEqualTo: joinCode)
            .get();

        int totalSessions = 0;
        int presentSessions = 0;

        for (var sessionDoc in sessionsQuery.docs) {
          totalSessions++;
          final attendances = await FirebaseFirestore.instance
              .collection('sessions')
              .doc(sessionDoc.id)
              .collection('attendances')
              .where('studentId', isEqualTo: widget.studentId)
              .limit(1)
              .get();

          // If the query found a document, the student was either present or marked explicitly absent
          if (attendances.docs.isNotEmpty) {
            final data = attendances.docs.first.data();
            final status = data['status'] ?? 'present';
            if (status == 'present') {
              presentSessions++;
            }
          }
        }

        final percentage = totalSessions == 0 ? 0.0 : (presentSessions / totalSessions) * 100;
        temp.add({
          'classId': classDoc.id,
          'title': title,
          'total': totalSessions,
          'present': presentSessions,
          'percentage': percentage,
          'joinCode': joinCode,
        });
      }

      if (mounted) {
        setState(() {
          classAttendanceData = temp;
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

  void _warnStudent(String classTitle, double percentage) async {
    try {
      // Manual Warning Trigger: Admin can click "Warn Student" on low attendance
      // This pushes a warning directly to the student's dashboard using arrayUnion
      await FirebaseFirestore.instance.collection('users').doc(widget.studentId).update({
        'warnings': FieldValue.arrayUnion([
          'WARNING: Your attendance in $classTitle is below 40% (${percentage.toStringAsFixed(1)}%). Please contact your instructor immediately.'
        ]),
        'hasWarning': true,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Warning sent to student successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to warn student: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text("${widget.studentName}'s Attendance"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : classAttendanceData.isEmpty
              ? const Center(child: Text("This student is not enrolled in any classes."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: classAttendanceData.length,
                  itemBuilder: (context, index) {
                    final data = classAttendanceData[index];
                    final double percentage = data['percentage'];
                    final bool isLow = percentage < 40.0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isLow ? const BorderSide(color: Colors.red, width: 2) : BorderSide.none,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isLow ? Colors.red.withValues(alpha: 0.1) : const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                  child: Icon(
                                    isLow ? Icons.warning : Icons.class_,
                                    color: isLow ? Colors.red : const Color(0xFF4F46E5),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['title'],
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                      ),
                                      Text(
                                        'Code: ${data['joinCode']}',
                                        style: TextStyle(color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${percentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                    color: isLow ? Colors.red : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Text('Present: ${data['present']} / ${data['total']} sessions'),
                                ),
                                if (isLow)
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => _warnStudent(data['title'], percentage),
                                    icon: const Icon(Icons.warning, size: 16),
                                    label: const Text('Warn Student'),
                                  )
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
