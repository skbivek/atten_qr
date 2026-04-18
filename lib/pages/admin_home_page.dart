import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'admin_class_attendance_page.dart';
import 'admin_student_attendance_summary_page.dart';

class AdminHomePage extends StatefulWidget {
  final String uid;
  const AdminHomePage({super.key, required this.uid});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4F46E5),
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: const Color(0xFF4F46E5),
          tabs: const [
            Tab(text: 'Modules', icon: Icon(Icons.library_books)),
            Tab(text: 'Teachers', icon: Icon(Icons.badge)),
            Tab(text: 'Classes', icon: Icon(Icons.class_)),
            Tab(text: 'Students', icon: Icon(Icons.people)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ModulesTab(),
          TeachersTab(),
          ClassesTab(),
          StudentsTab(),
        ],
      ),
    );
  }
}

class ModulesTab extends StatefulWidget {
  const ModulesTab({super.key});

  @override
  State<ModulesTab> createState() => _ModulesTabState();
}

class _ModulesTabState extends State<ModulesTab> {
  final titleController = TextEditingController();
  final codeController = TextEditingController();

  void createModule() async {
    final title = titleController.text.trim();
    final code = codeController.text.trim().toUpperCase();

    if (title.isEmpty || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('modules').add({
        'title': title,
        'code': code,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      titleController.clear();
      codeController.clear();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Module created!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void showCreateModuleDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Module'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Module Title', hintText: 'e.g. Physics'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Module Code', hintText: 'e.g. PHY101'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: createModule, child: const Text('Save')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: showCreateModuleDialog,
        backgroundColor: const Color(0xFF4F46E5),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('modules').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No modules created yet.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1),
                    child: const Icon(Icons.book, color: Color(0xFF4F46E5)),
                  ),
                  title: Text(data['title'] ?? ''),
                  subtitle: Text('Code: ${data['code'] ?? ''}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class TeachersTab extends StatefulWidget {
  const TeachersTab({super.key});

  @override
  State<TeachersTab> createState() => _TeachersTabState();
}

class _TeachersTabState extends State<TeachersTab> {
  void toggleApproval(String docId, bool currentStatus) async {
    await FirebaseFirestore.instance.collection('users').doc(docId).update({
      'isApproved': !currentStatus,
    });
  }

  void assignModules(String teacherId, List<dynamic> currentlyAssigned) async {
    final snapshot = await FirebaseFirestore.instance.collection('modules').get();
    final allModules = snapshot.docs;

    if (!mounted) return;

    List<String> selectedModules = List<String>.from(currentlyAssigned);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Assign Modules'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allModules.length,
                  itemBuilder: (context, index) {
                    final data = allModules[index].data();
                    final moduleString = '${data['code']} - ${data['title']}';
                    final isSelected = selectedModules.contains(moduleString);

                    return CheckboxListTile(
                      title: Text(moduleString),
                      value: isSelected,
                      onChanged: (bool? val) {
                        setState(() {
                          if (val == true) {
                            selectedModules.add(moduleString);
                          } else {
                            selectedModules.remove(moduleString);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('users').doc(teacherId).update({
                      'assignedModules': selectedModules,
                    });
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Modules updated')));
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'teacher').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No teachers registered yet.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final isApproved = data['isApproved'] ?? false;
            final assignedModules = data['assignedModules'] as List<dynamic>? ?? [];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: isApproved ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  child: Icon(
                    isApproved ? Icons.check_circle : Icons.pending,
                    color: isApproved ? Colors.green : Colors.orange,
                  ),
                ),
                title: Text(data['name'] ?? 'Unknown'),
                subtitle: Text(data['email'] ?? ''),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Status: ${isApproved ? "Approved" : "Pending Approval"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Assigned Modules: ${assignedModules.isEmpty ? "None" : assignedModules.join(", ")}'),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => toggleApproval(doc.id, isApproved),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isApproved ? Colors.red : Colors.green,
                                ),
                                child: Text(isApproved ? 'Revoke Approval' : 'Approve'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => assignModules(doc.id, assignedModules),
                                child: const Text('Assign Modules'),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class ClassesTab extends StatelessWidget {
  const ClassesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('classes').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No classes found in the system.'));
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final classId = docs[index].id;
            final String title = data['title'] ?? 'Unknown Class';
            final String teacherName = data['teacherName'] ?? 'Unknown Teacher';
            final String section = data['section'] ?? '';
            final String joinCode = data['joinCode'] ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1),
                  child: const Icon(Icons.class_, color: Color(0xFF4F46E5)),
                ),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('Teacher: $teacherName\nSection: $section | Code: $joinCode'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminClassAttendancePage(
                        classId: classId,
                        classTitle: title,
                        joinCode: joinCode,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class StudentsTab extends StatelessWidget {
  const StudentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'student').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No students found.'));
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final studentId = docs[index].id;
            final studentName = data['name'] ?? 'Unknown Student';
            final studentEmail = data['email'] ?? 'No Email';
            final hasWarning = data['hasWarning'] == true;

            return StudentListItem(
              studentId: studentId,
              studentName: studentName,
              studentEmail: studentEmail,
              hasWarning: hasWarning,
            );
          },
        );
      },
    );
  }
}

class StudentListItem extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String studentEmail;
  final bool hasWarning;

  const StudentListItem({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.hasWarning,
  });

  @override
  State<StudentListItem> createState() => _StudentListItemState();
}

class _StudentListItemState extends State<StudentListItem> {
  bool? _hasLowAttendance;

  @override
  void initState() {
    super.initState();
    _checkLowAttendance();
  }

  Future<void> _checkLowAttendance() async {
    try {
      final classesQuery = await FirebaseFirestore.instance
          .collection('classes')
          .where('studentIds', arrayContains: widget.studentId)
          .get();

      bool foundLow = false;

      for (var classDoc in classesQuery.docs) {
        final classData = classDoc.data();
        final joinCode = classData['joinCode'];

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

          if (attendances.docs.isNotEmpty) {
            final data = attendances.docs.first.data();
            final status = data['status'] ?? 'present';
            if (status == 'present') {
              presentSessions++;
            }
          }
        }

        if (totalSessions > 0) {
          final percentage = (presentSessions / totalSessions) * 100;
          if (percentage < 40.0) {
            foundLow = true;
            break;
          }
        }
      }

      if (mounted) {
        setState(() {
          _hasLowAttendance = foundLow;
        });
      }
    } catch (e) {
      debugPrint("Error checking low attendance: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isRedIcon = _hasLowAttendance == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: widget.hasWarning ? Colors.red.withValues(alpha: 0.1) : const Color(0xFF4F46E5).withValues(alpha: 0.1),
          child: Icon(
            widget.hasWarning ? Icons.warning_amber_rounded : Icons.person,
            color: widget.hasWarning ? Colors.red : const Color(0xFF4F46E5),
          ),
        ),
        title: Text(widget.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(widget.studentEmail),
        trailing: _hasLowAttendance == null
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(
                Icons.analytics,
                size: 20,
                color: isRedIcon ? Colors.red : Colors.grey.shade600,
              ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminStudentAttendanceSummaryPage(
                studentId: widget.studentId,
                studentName: widget.studentName,
              ),
            ),
          );
        },
      ),
    );
  }
}
