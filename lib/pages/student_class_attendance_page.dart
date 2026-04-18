import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentClassAttendancePage extends StatefulWidget {
  final String classTitle;
  final String joinCode;
  final String studentId;

  const StudentClassAttendancePage({
    super.key,
    required this.classTitle,
    required this.joinCode,
    required this.studentId,
  });

  @override
  State<StudentClassAttendancePage> createState() => _StudentClassAttendancePageState();
}

class _StudentClassAttendancePageState extends State<StudentClassAttendancePage> {
  bool isLoading = true;
  List<Map<String, dynamic>> sessionsList = [];
  int totalSessions = 0;
  int presentSessions = 0;

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
      int tempTotal = 0;
      int tempPresent = 0;

      for (var sessionDoc in sessionsQuery.docs) {
        tempTotal++;
        final sessionTime = (sessionDoc.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

        final attendances = await FirebaseFirestore.instance
            .collection('sessions')
            .doc(sessionDoc.id)
            .collection('attendances')
            .where('studentId', isEqualTo: widget.studentId)
            .limit(1)
            .get();

        bool isPresent = false;
        DateTime attTime = sessionTime;
        
        if (attendances.docs.isNotEmpty) {
          final data = attendances.docs.first.data();
          final String status = data['status'] ?? 'present';
          if (status == 'present') {
            isPresent = true;
            tempPresent++;
          }
           attTime = (data['timestamp'] as Timestamp?)?.toDate() ?? sessionTime;
        }

        tempRecords.add({
          'isPresent': isPresent,
          'date': "${sessionTime.year}-${sessionTime.month.toString().padLeft(2, '0')}-${sessionTime.day.toString().padLeft(2, '0')}",
          'time': "${sessionTime.hour.toString().padLeft(2, '0')}:${sessionTime.minute.toString().padLeft(2, '0')}",
          'rawDate': sessionTime,
          'attTimeStr': attendances.docs.isNotEmpty ? "${attTime.hour.toString().padLeft(2, '0')}:${attTime.minute.toString().padLeft(2, '0')}" : "-",
        });
      }

      tempRecords.sort((a, b) => (b['rawDate'] as DateTime).compareTo(a['rawDate'] as DateTime));

      if (mounted) {
        setState(() {
          sessionsList = tempRecords;
          totalSessions = tempTotal;
          presentSessions = tempPresent;
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

  @override
  Widget build(BuildContext context) {
    final double percentage = totalSessions == 0 ? 0 : (presentSessions / totalSessions) * 100;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text('${widget.classTitle} Attendance'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Total Attendance',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _statBox('Total Classes', totalSessions.toString()),
                          _statBox('Present', presentSessions.toString()),
                          _statBox('Absent', (totalSessions - presentSessions).toString()),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Row(
                    children: [
                      const Text(
                        'History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: sessionsList.isEmpty
                      ? const Center(child: Text('No attendance records found.'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: sessionsList.length,
                          itemBuilder: (context, index) {
                            final record = sessionsList[index];
                            final isPresent = record['isPresent'];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isPresent ? Colors.green.shade50 : Colors.red.shade50,
                                  child: Icon(
                                    isPresent ? Icons.check : Icons.close,
                                    color: isPresent ? Colors.green.shade600 : Colors.red.shade600,
                                  ),
                                ),
                                title: Text(
                                  isPresent ? 'Present' : 'Absent',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isPresent ? Colors.green.shade700 : Colors.red.shade700,
                                  ),
                                ),
                                subtitle: Text("Session: ${record['date']} ${record['time']}${isPresent ? '\nChecked in at: ${record['attTimeStr']}' : ''}"),
                                isThreeLine: isPresent,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _statBox(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
