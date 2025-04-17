import 'package:flutter/material.dart';
import 'package:flutter_medslots/screens/patient/patient_dashboard.dart';
import 'package:flutter_medslots/services/firestorestore_services.dart';
import 'patient_profile_screen.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;

class UploadReportsScreen extends StatefulWidget {
  @override
  _UploadReportsScreenState createState() => _UploadReportsScreenState();
}

class _UploadReportsScreenState extends State<UploadReportsScreen> {
  List<File> localFiles = [];
  List<Map<String, dynamic>> cloudFiles = [];
  Set<int> selectedFiles = {};
  bool isSelecting = false;
  bool isLoading = false;
  double uploadProgress = 0.0;
  bool isUploading = false;
  
  // User data
  String userName = "";
  String userEmail = "";
  String contactNumber = "";
  int age = 0;
  String gender = "";
  String bloodGroup = "";
  String address = "";

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get current user
      User? user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        // Fetch user profile data from Firestore
        DocumentSnapshot userData = await FirebaseFirestore.instance
            .collection('Patient')
            .doc(user.email)
            .get();
        
        if (userData.exists) {
          Map<String, dynamic> data = userData.data() as Map<String, dynamic>;
          
          setState(() {
            userName = data['name'] ?? "";
            userEmail = data['email'] ?? user.email ?? "";
            contactNumber = data['contactNumber'] ?? "";
            age = data['age'] ?? 0;
            gender = data['gender'] ?? "";
            bloodGroup = data['bloodGroup'] ?? "";
            address = data['address'] ?? "";
          });
        }
        
        // Fetch already uploaded reports
        await _fetchUploadedReports(user.email!);
      }
    } catch (e) {
      print("Error fetching user data: $e");
      _showSnackBar("Failed to load user data");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _fetchUploadedReports(String userEmail) async {
    try {
      // Get documents from Firestore instead of just Storage references
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('Records')
          .where('patientId', isEqualTo: userEmail)
          .orderBy('uploadDate', descending: true)
          .get();
          
      setState(() {
        cloudFiles = querySnapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'fileName': doc['fileName'],
                  'fileUrl': doc['fileUrl'],
                  'uploadDate': doc['uploadDate'],
                  'isCloud': true,
                })
            .toList();
      });
    } catch (e) {
      print("Error fetching reports: $e");
      _showSnackBar("Failed to load reports");
    }
  }

  Future<void> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      );
      
      if (result != null) {
        setState(() {
          for (var file in result.files) {
            if (file.path != null) {
              localFiles.add(File(file.path!));
            }
          }
        });
      }
    } catch (e) {
      print("Error picking file: $e");
      _showSnackBar("Failed to pick file");
    }
  }

  Future<void> uploadFileToStorage(File file) async {
    setState(() {
      isUploading = true;
      uploadProgress = 0.0;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not authenticated");
      }

      String fileName = path.basename(file.path);
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String fileId = '$timestamp-$fileName';
      
      // Create reference to upload location
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('reports/${user.email}/$fileId');
      
      // Start upload with progress tracking
      UploadTask uploadTask = storageRef.putFile(file);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });
      
      // Wait for upload to complete
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      
      // Save file metadata to Firestore
      DocumentReference docRef = await FirebaseFirestore.instance
          .collection('Records')
          .add({
            'fileName': fileName,
            'fileUrl': downloadUrl,
            'uploadDate': FieldValue.serverTimestamp(),
            'patientId': user.email,
            'patientName': userName,
            'fileSize': await file.length(),
            'fileType': path.extension(file.path).replaceAll('.', ''),
          });
      
      // Update local list immediately
      setState(() {
        cloudFiles.insert(0, {
          'id': docRef.id,
          'fileName': fileName,
          'fileUrl': downloadUrl,
          'uploadDate': Timestamp.now(),
          'isCloud': true,
        });
        
        // Remove from local files list
        localFiles.remove(file);
      });
      
      _showSnackBar("File uploaded successfully");
    } catch (e) {
      print("Error uploading file: $e");
      _showSnackBar("Failed to upload file: ${e.toString()}");
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  void openFile(dynamic file) {
    if (file is File) {
      OpenFile.open(file.path);
    } else if (file is Map && file.containsKey('fileUrl')) {
      // For cloud files, you would typically launch a URL
      // But this depends on your app's capabilities
      _showSnackBar("Opening cloud file in browser");
      // You might want to use url_launcher package here
    }
  }

  void toggleSelection(int index, bool isCloud) {
    setState(() {
      String id = isCloud ? '$index:cloud' : '$index:local';
      if (selectedFiles.contains(index)) {
        selectedFiles.remove(index);
      } else {
        selectedFiles.add(index);
      }
      isSelecting = selectedFiles.isNotEmpty;
    });
  }

  Future<void> deleteSelectedFiles() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Process cloud files
        List<int> cloudIndexesToDelete = [];
        for (int index in selectedFiles) {
          if (index < cloudFiles.length) {
            String docId = cloudFiles[index]['id'];
            String fileUrl = cloudFiles[index]['fileUrl'];
            
            // Delete from Firestore
            await FirebaseFirestore.instance
                .collection('Records')
                .doc(docId)
                .delete();
                
            // Delete from Storage
            // Extract the path from the download URL
            try {
              await FirebaseStorage.instance.refFromURL(fileUrl).delete();
            } catch (e) {
              print("Error deleting file from storage: $e");
            }
            
            cloudIndexesToDelete.add(index);
          }
        }
        
        // Process local files
        List<int> localIndexesToDelete = [];
        for (int index in selectedFiles) {
          if (index >= cloudFiles.length && index < cloudFiles.length + localFiles.length) {
            int localIndex = index - cloudFiles.length;
            if (localIndex >= 0 && localIndex < localFiles.length) {
              localIndexesToDelete.add(localIndex);
            }
          }
        }
        
        setState(() {
          // Remove deleted cloud files
          cloudFiles = cloudFiles.asMap().entries
              .where((entry) => !cloudIndexesToDelete.contains(entry.key))
              .map((entry) => entry.value)
              .toList();
              
          // Remove deleted local files
          localFiles = localFiles.asMap().entries
              .where((entry) => !localIndexesToDelete.contains(entry.key))
              .map((entry) => entry.value)
              .toList();
              
          selectedFiles.clear();
          isSelecting = false;
        });
      }
      
      _showSnackBar("Files deleted successfully");
    } catch (e) {
      print("Error deleting files: $e");
      _showSnackBar("Failed to delete some files");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
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
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.teal))
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.teal.shade100, Colors.white],
                ),
              ),
              child: Column(
                children: [
                  // Patient info header
                  Container(
                    padding: EdgeInsets.all(16.0),
                    color: Colors.teal.withOpacity(0.1),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.teal.shade700,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                userEmail,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Upload progress indicator
                  if (isUploading)
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Uploading... ${(uploadProgress * 100).toStringAsFixed(0)}%',
                              style: TextStyle(fontSize: 14)),
                          SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: uploadProgress,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                          ),
                        ],
                      ),
                    ),
                  
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Reports',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                        Text('${cloudFiles.length + localFiles.length} files',
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54))
                      ],
                    ),
                  ),
                  
                  Expanded(
                    child: cloudFiles.isEmpty && localFiles.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_open, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('No reports uploaded yet',
                                    style: TextStyle(fontSize: 18, color: Colors.black54)),
                                SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: pickFile,
                                  icon: Icon(Icons.add),
                                  label: Text('Add Reports'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(10),
                            itemCount: cloudFiles.length + localFiles.length,
                            itemBuilder: (context, index) {
                              bool isCloud = index < cloudFiles.length;
                              dynamic file = isCloud 
                                  ? cloudFiles[index]
                                  : localFiles[index - cloudFiles.length];
                              String fileName = isCloud 
                                  ? file['fileName'] 
                                  : path.basename(file.path);
                              bool isSelected = selectedFiles.contains(index);
                              
                              return Card(
                                elevation: 3,
                                margin: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                color: isSelected ? Colors.blue.shade100 : Colors.white,
                                child: ListTile(
                                  onLongPress: () => toggleSelection(index, isCloud),
                                  onTap: () {
                                    if (isSelecting) {
                                      toggleSelection(index, isCloud);
                                    } else if (!isCloud) {
                                      openFile(file);
                                    }
                                  },
                                  leading: _getFileIcon(fileName),
                                  title: Text(
                                    fileName,
                                    style: TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Icon(
                                        isCloud ? Icons.cloud_done : Icons.file_present,
                                        size: 14,
                                        color: isCloud ? Colors.teal : Colors.orange,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        isCloud ? "Uploaded" : "Local file",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  trailing: isSelecting
                                      ? Icon(
                                          isSelected
                                              ? Icons.check_circle
                                              : Icons.radio_button_unchecked,
                                          color: isSelected ? Colors.green : Colors.grey)
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (!isCloud)
                                              IconButton(
                                                icon: Icon(Icons.cloud_upload,
                                                    color: Colors.teal),
                                                onPressed: !isUploading
                                                    ? () => uploadFileToStorage(file)
                                                    : null,
                                              ),
                                            IconButton(
                                              icon: Icon(
                                                isCloud ? Icons.open_in_new : Icons.visibility,
                                                color: Colors.blue.shade900),
                                              onPressed: () => openFile(file),
                                            ),
                                          ],
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
                  
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      onPressed: !isUploading ? pickFile : null,
                      icon: Icon(Icons.add),
                      label: Text('Add Files', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade900,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: Size(double.infinity, 48), // Width takes full width
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
        currentIndex: 1, // Set current tab as selected
        onTap: (index) {
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PatientDashboard()),
            );
          } else if (index == 2) {
            // Navigate to profile screen with the current user's email
            User? currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null && currentUser.email != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PatientProfileScreen(
                    // email: currentUser.email!,
                  ),
                ),
              );
            } else {
              // Handle case when user email is not available
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Unable to access profile. Please re-login.')),
              );
            }
          }
        },
      ),
    );
  }
  
  Widget _getFileIcon(String fileName) {
    String extension = fileName.split('.').last.toLowerCase();
    IconData iconData;
    Color iconColor;
    
    switch (extension) {
      case 'pdf':
        iconData = Icons.picture_as_pdf;
        iconColor = Colors.red;
        break;
      case 'doc':
      case 'docx':
        iconData = Icons.description;
        iconColor = Colors.blue;
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
        iconData = Icons.image;
        iconColor = Colors.green;
        break;
      default:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.orange;
    }
    
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: iconColor),
    );
  }
}