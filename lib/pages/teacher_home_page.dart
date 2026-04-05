import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'login_page.dart';
import 'qr_session_page.dart';

class TeacherHomePage extends StatefulWidget {
  final String uid;
  const TeacherHomePage({super.key, required this.uid});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  final TextEditingController sectionController = TextEditingController();
  String? _name;
  bool isApproved = true; // Wait for fetch
  List<String> assignedModules = [];
  String? selectedModule;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _name = doc.data()?['name'];
          isApproved = doc.data()?['isApproved'] ?? false;
          assignedModules = List<String>.from(doc.data()?['assignedModules'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  Future<void> createClass() async {
    final title = selectedModule?.trim() ?? '';
    final section = sectionController.text.trim();

    if (title.isEmpty || section.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final code = String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );

    try {
      await FirebaseFirestore.instance.collection('classes').add({
        'title': title,
        'section': section,
        'joinCode': code,
        'teacherId': widget.uid,
        'teacherName': _name ?? 'Teacher',
        'studentIds': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      sectionController.clear();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class created successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create class: $e')),
      );
    }
  }

  void showCreateClassDialog() {
    selectedModule = assignedModules.isNotEmpty ? assignedModules.first : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('Create New Class'),
            content: assignedModules.isEmpty 
              ? const Text("You don't have any modules assigned. Contact the admin.")
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedModule,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Select Module',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: assignedModules.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (val) => setState(() => selectedModule = val),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: sectionController,
                      decoration: InputDecoration(
                        labelText: 'Section',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: assignedModules.isEmpty ? null : createClass,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Create'),
              ),
            ],
          );
        }
      ),
    );
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

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTopCard(List<QueryDocumentSnapshot> classDocs) {
    int totalStudents = 0;
    for (var doc in classDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final students = data['studentIds'] as List<dynamic>? ?? [];
      totalStudents += students.length;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome Teacher',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _name ?? 'Loading...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _summaryCard(
                title: 'Classes',
                value: classDocs.length.toString(),
                icon: Icons.class_,
              ),
              const SizedBox(width: 12),
              _summaryCard(
                title: 'Students',
                value: totalStudents.toString(),
                icon: Icons.groups,
              ),
              const SizedBox(width: 12),
              _summaryCard(
                title: 'QR Sessions',
                value: '12',
                icon: Icons.qr_code,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void showEnrolledStudents(List<dynamic>? studentIds) {
    showDialog(
      context: context,
      builder: (context) {
        if (studentIds == null || studentIds.isEmpty) {
          return const AlertDialog(
            title: Text('Enrolled Students'),
            content: Text('No students enrolled in this class yet.'),
          );
        }

        return AlertDialog(
          title: const Text('Enrolled Students'),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<List<DocumentSnapshot>>(
              future: Future.wait(studentIds.map((id) =>
                  FirebaseFirestore.instance.collection('users').doc(id.toString()).get())),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return const Text('Error loading students.');
                }
                final docs = snapshot.data ?? [];

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>?;
                    if (data == null) return const SizedBox.shrink();
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF0F766E).withOpacity(0.1),
                        child: const Icon(Icons.person, color: Color(0xFF0F766E)),
                      ),
                      title: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(data['email'] ?? ''),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget buildClassCard(String classId, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  height: 54,
                  width: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: Color(0xFF0F766E),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Section: ${data['section'] ?? ''}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Students: ${((data['studentIds'] as List<dynamic>?)?.length ?? 0)}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.people_alt, size: 20),
                    label: const Text('Students'),
                    onPressed: () => showEnrolledStudents(data['studentIds'] as List<dynamic>?),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.qr_code),
                    label: const Text('Start QR'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QRSessionPage(
                            classId: classId,
                            classTitle: data['title'] ?? 'Class',
                            joinCode: data['joinCode'] ?? '',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 90,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            const Text(
              'No classes created yet',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button below to create your first class.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    sectionController.dispose();
    super.dispose();
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
          'Teacher Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: !isApproved ? null : FloatingActionButton(
        backgroundColor: const Color(0xFF0F766E),
        onPressed: showCreateClassDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: !isApproved
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.pending_actions, size: 80, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text("Account Pending Approval", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Please wait for the admin to approve your account.", style: TextStyle(color: Colors.grey.shade600)),
                ]
              )
            )
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('classes')
            .where('teacherId', isEqualTo: widget.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final classDocs = snapshot.data?.docs ?? [];
          // Optional sorting by createdAt on the client to avoid missing index errors
          classDocs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final bTime = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            return bTime.compareTo(aTime);
          });

          if (classDocs.isEmpty) {
            return buildEmptyState();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                buildTopCard(classDocs),
                const SizedBox(height: 20),
                Row(
                  children: const [
                    Text(
                      'My Classes',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...classDocs.map((doc) => buildClassCard(doc.id, doc.data() as Map<String, dynamic>)),
              ],
            ),
          );
        },
      ),
    );
  }
}
