import 'package:flutter/material.dart';
import 'package:flutter_medslots/patient_dashboard.dart';
import 'patient_profile_screen.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';

class UploadReportsScreen extends StatefulWidget {
  @override
  _UploadReportsScreenState createState() => _UploadReportsScreenState();
}

class _UploadReportsScreenState extends State<UploadReportsScreen> {
  List<File> uploadedFiles = [];

  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        uploadedFiles.add(File(result.files.single.path!));
      });
    }
  }

  void openFile(File file) {
    OpenFile.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
        backgroundColor: Colors.teal,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blue.shade900),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade100, Colors.white],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Uploaded Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
            ),
            Expanded(
              child: uploadedFiles.isEmpty
                  ? Center(child: Text('No reports uploaded yet', style: TextStyle(fontSize: 18, color: Colors.black54)))
                  : ListView.builder(
                      padding: EdgeInsets.all(10),
                      itemCount: uploadedFiles.length,
                      itemBuilder: (context, index) {
                        return Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: Icon(Icons.folder, size: 40, color: Colors.blue.shade900),
                            title: Text(
                              uploadedFiles[index].path.split('/').last,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.visibility, color: Colors.blue.shade900),
                              onPressed: () => openFile(uploadedFiles[index]),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: pickFile,
                icon: Icon(Icons.upload),
                label: Text('Upload Files', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade900,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard, color: Colors.teal),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload_file, color: Colors.teal),
            label: 'Upload Records',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person, color: Colors.teal),
            label: 'Profile',
          ),
        ],
        selectedItemColor: Colors.teal.shade700,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        onTap: (index) {
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PatientDashboard()),
            );
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => UploadReportsScreen()),
            );
            // Navigate to profile page (to be implemented)
          }else{
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PatientProfileScreen(name: "",address: "",contactNumber: "",age: index,gender: '',email: '',bloodGroup: ''))
            );

          }
        },
      ),
    );
  }
}
