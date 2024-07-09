import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'add_student_page.dart';
import 'view_students_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const AddStudentPage(),
    const ViewStudentsPage(),
  ];
  File? _newProfilePicFile;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<File> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final path = tempDir.path;
    img.Image image = img.decodeImage(file.readAsBytesSync())!;
    img.Image smallerImage = img.copyResize(image, width: 150);

    final compressedFile = File('$path/img_${DateTime.now().millisecondsSinceEpoch}.jpg')
      ..writeAsBytesSync(img.encodeJpg(smallerImage, quality: 85));

    return compressedFile;
  }

  Future<String> _uploadImage(File image, String userEmail) async {
    try {
      final compressedImage = await _compressImage(image);
      final storageRef = firebase_storage.FirebaseStorage.instance
          .ref()
          .child('profile_pics/$userEmail.jpg');
      await storageRef.putFile(compressedImage);
      return await storageRef.getDownloadURL();
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }

  Future<void> _deleteOldProfilePic(String oldProfilePicUrl) async {
    try {
      final storageRef = firebase_storage.FirebaseStorage.instance
          .refFromURL(oldProfilePicUrl);
      await storageRef.delete();
    } catch (e) {
      throw Exception('Error deleting old profile picture: $e');
    }
  }

  void _showTeacherInfo(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final doc = await FirebaseFirestore.instance.collection('teachers').doc(user!.email).get();
    final data = doc.data();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Teacher Information'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                if (data!['profilePicUrl'] != null)
                  Image.network(data['profilePicUrl'], height: 100, width: 100, fit: BoxFit.cover),
                const SizedBox(height: 10),
                Text('Name: ${data['name']}'),
                Text('Email: ${data['email']}'),
                Text('Gender: ${data['gender']}'),
                Text('DOB: ${DateFormat('yyyy-MM-dd').format((data['dob'] as Timestamp).toDate())}'),
                Text('Phone: ${data['phone']}'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Update'),
              onPressed: () {
                Navigator.of(context).pop();
                _updateTeacherInfo(context, data);
              },
            ),
          ],
        );
      },
    );
  }

  void _updateTeacherInfo(BuildContext context, Map<String, dynamic> data) async {
    final TextEditingController nameController = TextEditingController(text: data['name']);
    final TextEditingController dobController = TextEditingController(text: DateFormat('yyyy-MM-dd').format((data['dob'] as Timestamp).toDate()));
    final TextEditingController phoneController = TextEditingController(text: data['phone']);
    String gender = data['gender'];
    String? profilePicUrl = data['profilePicUrl'];
    bool isUpdating = false; // Flag to track if updating is in progress

    Future<void> selectDate() async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.parse(dobController.text),
        firstDate: DateTime(1900),
        lastDate: DateTime(2101),
      );
      if (picked != null) {
        dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      }
    }

    Future<void> pickImage(BuildContext context) async {
      final picker = ImagePicker();
      final pickedFile = await showModalBottomSheet<File>(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () async {
                  final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                  Navigator.pop(context, pickedFile != null ? File(pickedFile.path) : null);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () async {
                  final pickedFile = await picker.pickImage(source: ImageSource.camera);
                  Navigator.pop(context, pickedFile != null ? File(pickedFile.path) : null);
                },
              ),
            ],
          ),
        ),
      );

      if (pickedFile != null) {
        setState(() {
          _newProfilePicFile = pickedFile;
        });
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Update Teacher Information'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                GestureDetector(
                  onTap: () async {
                    await pickImage(context);
                    setState(() {});
                  },
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _newProfilePicFile != null
                        ? FileImage(_newProfilePicFile!)
                        : (profilePicUrl != null ? NetworkImage(profilePicUrl!) : null) as ImageProvider?,
                    child: _newProfilePicFile == null && profilePicUrl == null
                        ? const Icon(Icons.camera_alt, size: 50, color: Colors.grey)
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: dobController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Date of Birth',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: selectDate,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: gender,
                  onChanged: (String? newValue) {
                    setState(() {
                      gender = newValue!;
                    });
                  },
                  items: <String>['Male', 'Female', 'Other']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  decoration: InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (isUpdating)
                  Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Update'),
              onPressed: () async {
                setState(() {
                  isUpdating = true;
                });
                try {
                  if (_newProfilePicFile != null) {
                    final user = FirebaseAuth.instance.currentUser;
                    final oldProfilePicUrl = profilePicUrl;
                    if (oldProfilePicUrl != null) {
                      await _deleteOldProfilePic(oldProfilePicUrl);
                    }
                    profilePicUrl = await _uploadImage(_newProfilePicFile!, user!.email!);
                  }

                  final user = FirebaseAuth.instance.currentUser;
                  await FirebaseFirestore.instance.collection('teachers').doc(user!.email).update({
                    'name': nameController.text,
                    'dob': Timestamp.fromDate(DateTime.parse(dobController.text)),
                    'phone': phoneController.text,
                    'gender': gender,
                    'profilePicUrl': profilePicUrl,
                  });

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Teacher information updated successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update teacher information: $e')),
                  );
                } finally {
                  setState(() {
                    isUpdating = false;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Management'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade900,
                Colors.orange.shade800,
                Colors.orange.shade400,
              ],
            ),
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('teachers').doc(user!.email).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.active) {
                  if (snapshot.hasData) {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final profilePicUrl = data['profilePicUrl'];

                    return UserAccountsDrawerHeader(
                      accountName: Text(data['name']),
                      accountEmail: Text(user.email!),
                      currentAccountPicture: GestureDetector(
                        onTap: () => _showTeacherInfo(context),
                        child: CircleAvatar(
                          backgroundImage: profilePicUrl != null ? NetworkImage(profilePicUrl) : null,
                          child: profilePicUrl == null
                              ? const Icon(Icons.account_circle, size: 50)
                              : null,
                        ),
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade900,
                            Colors.orange.shade800,
                            Colors.orange.shade400,
                          ],
                        ),
                      ),
                      onDetailsPressed: () => _showTeacherInfo(context),
                    );
                  } else {
                    return DrawerHeader(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade900,
                            Colors.orange.shade800,
                            Colors.orange.shade400,
                          ],
                        ),
                      ),
                      child: Center(child: Text('No data available')),
                    );
                  }
                } else {
                  return DrawerHeader(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade900,
                          Colors.orange.shade800,
                          Colors.orange.shade400,
                        ],
                      ),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () => _signOut(context),
            ),
          ],
        ),
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: 'Add Student',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'View Students',
          ),
        ],
      ),
    );
  }
}
