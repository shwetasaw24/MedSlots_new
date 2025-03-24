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
  Set<int> selectedFiles = {};
  bool isSelecting = false;

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

  void toggleSelection(int index) {
    setState(() {
      if (selectedFiles.contains(index)) {
        selectedFiles.remove(index);
      } else {
        selectedFiles.add(index);
      }
      isSelecting = selectedFiles.isNotEmpty;
    });
  }

  void deleteSelectedFiles() {
    setState(() {
      uploadedFiles.removeWhere((file) => selectedFiles.contains(uploadedFiles.indexOf(file)));
      selectedFiles.clear();
      isSelecting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isSelecting
            ? Text('${selectedFiles.length} Selected',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
            : Text('Reports',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: isSelecting
            ? [
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: deleteSelectedFiles,
                ),
                IconButton(
                  icon: Icon(Icons.cancel, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      selectedFiles.clear();
                      isSelecting = false;
                    });
                  },
                )
              ]
            : [],
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
                child: Text('Uploaded Reports',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ),
            ),
            Expanded(
              child: uploadedFiles.isEmpty
                  ? Center(
                      child: Text('No reports uploaded yet',
                          style: TextStyle(fontSize: 18, color: Colors.black54)))
                  : ListView.builder(
                      padding: EdgeInsets.all(10),
                      itemCount: uploadedFiles.length,
                      itemBuilder: (context, index) {
                        bool isSelected = selectedFiles.contains(index);
                        return GestureDetector(
                          onLongPress: () => toggleSelection(index),
                          onTap: () {
                            if (isSelecting) {
                              toggleSelection(index);
                            } else {
                              openFile(uploadedFiles[index]);
                            }
                          },
                          child: Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            color: isSelected ? Colors.blue.shade100 : Colors.white,
                            child: ListTile(
                              leading: Icon(Icons.folder,
                                  size: 40, color: Colors.blue.shade900),
                              title: Text(
                                uploadedFiles[index].path.split('/').last,
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: isSelecting
                                  ? Icon(isSelected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                      color: isSelected ? Colors.green : Colors.grey)
                                  : IconButton(
                                      icon: Icon(Icons.visibility,
                                          color: Colors.blue.shade900),
                                      onPressed: () => openFile(uploadedFiles[index]),
                                    ),
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
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PatientProfileScreen(
                  name: "John Doe",
                  address: "123 Street, City",
                  contactNumber: "+91 9876543210",
                  age: 25,
                  gender: "Male",
                  email: "johndoe@example.com",
                  bloodGroup: "O+",
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
