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
import 'package:url_launcher/url_launcher_string.dart';

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
      _showSnackBar("Failed to load user data: ${e.toString()}");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _fetchUploadedReports(String userEmail) async {
    try {
      print("Fetching reports for email: $userEmail");
      
      // Get documents from Firestore
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('Records')
          .where('patientId', isEqualTo: userEmail)
          .orderBy('uploadDate', descending: true)
          .get();
          
      print("Found ${querySnapshot.docs.length} reports");
          
      setState(() {
        cloudFiles = querySnapshot.docs
            .map((doc) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              return {
                'id': doc.id,
                'fileName': data['fileName'] ?? 'Unknown file',
                'fileUrl': data['fileUrl'] ?? '',
                'uploadDate': data['uploadDate'] ?? Timestamp.now(),
                'fileType': data['fileType'] ?? '',
                'fileSize': data['fileSize'] ?? 0,
                'isCloud': true,
              };
            })
            .toList();
      });
    } catch (e) {
      print("Error fetching reports: $e");
      _showSnackBar("Failed to load reports: ${e.toString()}");
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
        
        // Show a message with the number of files selected
        if (result.files.isNotEmpty) {
          _showSnackBar("${result.files.length} file(s) selected");
        }
      }
    } catch (e) {
      print("Error picking file: $e");
      _showSnackBar("Failed to pick file: ${e.toString()}");
    }
  }

  Future<void> uploadFileToStorage(File file) async {
    if (!mounted) return;
    
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
      
      print("Starting upload for file: $fileName");
      
      // First check if file exists and has content
      if (!await file.exists()) {
        throw Exception("File does not exist");
      }
      
      int fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception("File is empty");
      }
      
      // Create reference to upload location
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('patient_reports')
          .child(user.email ?? 'unknown')
          .child(fileId);
      
      print("Storage reference created: ${storageRef.fullPath}");
      
      // Start upload with progress tracking
      UploadTask uploadTask = storageRef.putFile(file);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (mounted) {
          setState(() {
            uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        }
        print("Upload progress: ${(uploadProgress * 100).toStringAsFixed(0)}%");
      });
      
      // Wait for upload to complete
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      
      print("File uploaded successfully. Download URL: $downloadUrl");
      
      // Get file type
      String fileType = path.extension(file.path).replaceAll('.', '');
      
      // Create a document in Firestore
      await FirebaseFirestore.instance.collection('Records').add({
        'fileName': fileName,
        'fileUrl': downloadUrl,
        'uploadDate': FieldValue.serverTimestamp(),
        'patientId': user.email,
        'patientName': userName,
        'fileSize': fileSize,
        'fileType': fileType,
        'storagePath': storageRef.fullPath,
      }).then((docRef) {
        print("Document added with ID: ${docRef.id}");
        
        // Update local list immediately
        if (mounted) {
          setState(() {
            cloudFiles.insert(0, {
              'id': docRef.id,
              'fileName': fileName,
              'fileUrl': downloadUrl,
              'uploadDate': Timestamp.now(),
              'fileType': fileType,
              'fileSize': fileSize,
              'isCloud': true,
            });
            
            // Remove from local files list
            localFiles.remove(file);
          });
        }
        
        _showSnackBar("$fileName uploaded successfully");
      }).catchError((error) {
        print("Error adding document: $error");
        throw Exception("Failed to save file metadata: $error");
      });
      
    } catch (e) {
      print("Error uploading file: $e");
      if (mounted) {
        _showSnackBar("Upload failed: ${e.toString().split('\n')[0]}");
      }
    } finally {
      if (mounted) {
        setState(() {
          isUploading = false;
        });
      }
    }
  }

  Future<void> openFile(dynamic file) async {
    try {
      if (file is File) {
        await OpenFile.open(file.path);
      } else if (file is Map && file.containsKey('fileUrl')) {
        String url = file['fileUrl'];
        
        // Update last accessed timestamp in Firestore
        if (file['id'] != null) {
          try {
            await FirebaseFirestore.instance
                .collection('Records')
                .doc(file['id'])
                .update({
                  'lastAccessed': FieldValue.serverTimestamp(),
                });
          } catch (e) {
            print("Error updating last accessed: $e");
          }
        }
        
        // Launch URL
        if (await canLaunchUrlString(url)) {
          await launchUrlString(url, mode: LaunchMode.externalApplication);
        } else {
          _showSnackBar("Cannot open this file");
        }
      }
    } catch (e) {
      print("Error opening file: $e");
      _showSnackBar("Failed to open file: ${e.toString()}");
    }
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

  Future<void> deleteSelectedFiles() async {
    // Show confirmation dialog
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Files'),
        content: Text('Are you sure you want to delete ${selectedFiles.length} file(s)?'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmDelete) return;
    
    setState(() {
      isLoading = true;
    });
    
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Process files by selection index
        List<int> cloudIndexesToDelete = [];
        List<int> localIndexesToDelete = [];
        
        for (int index in selectedFiles) {
          if (index < cloudFiles.length) {
            // This is a cloud file
            Map<String, dynamic> fileData = cloudFiles[index];
            String docId = fileData['id'];
            String fileUrl = fileData['fileUrl'];
            
            print("Deleting cloud file: ${fileData['fileName']} (ID: $docId)");
            
            try {
              // Delete from Firestore
              await FirebaseFirestore.instance
                  .collection('Records')
                  .doc(docId)
                  .delete();
              
              print("Document deleted from Firestore");
              
              // Try to delete from Storage if URL available
              try {
                await FirebaseStorage.instance
                    .refFromURL(fileUrl)
                    .delete();
                print("File deleted from Storage");
              } catch (e) {
                print("Error deleting file from storage: $e");
                // Continue anyway - the Firestore record is gone
              }
              
              cloudIndexesToDelete.add(index);
            } catch (e) {
              print("Error deleting cloud file: $e");
              _showSnackBar("Error deleting ${fileData['fileName']}");
            }
          } else {
            // This is a local file
            int localIndex = index - cloudFiles.length;
            if (localIndex >= 0 && localIndex < localFiles.length) {
              localIndexesToDelete.add(localIndex);
            }
          }
        }
        
        // Remove files from our lists
        setState(() {
          // For cloud files, we need to be careful about indices
          List<Map<String, dynamic>> newCloudFiles = [];
          for (int i = 0; i < cloudFiles.length; i++) {
            if (!cloudIndexesToDelete.contains(i)) {
              newCloudFiles.add(cloudFiles[i]);
            }
          }
          cloudFiles = newCloudFiles;
          
          // For local files, we can use a different approach
          List<File> newLocalFiles = [];
          for (int i = 0; i < localFiles.length; i++) {
            if (!localIndexesToDelete.contains(i)) {
              newLocalFiles.add(localFiles[i]);
            }
          }
          localFiles = newLocalFiles;
          
          selectedFiles.clear();
          isSelecting = false;
        });
        
        _showSnackBar("Files deleted successfully");
      }
    } catch (e) {
      print("Error during deletion process: $e");
      _showSnackBar("Failed to delete some files: ${e.toString()}");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> deleteFile(int index) async {
    // Determine if this is a cloud or local file
    bool isCloud = index < cloudFiles.length;
    String fileName = isCloud 
        ? cloudFiles[index]['fileName'] 
        : path.basename(localFiles[index - cloudFiles.length].path);
    
    // Show confirmation dialog
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete File'),
        content: Text('Are you sure you want to delete "$fileName"?'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmDelete) return;
    
    setState(() {
      isLoading = true;
    });
    
    try {
      if (isCloud) {
        // Delete cloud file
        Map<String, dynamic> fileData = cloudFiles[index];
        String docId = fileData['id'];
        String fileUrl = fileData['fileUrl'];
        
        // Delete from Firestore
        await FirebaseFirestore.instance
            .collection('Records')
            .doc(docId)
            .delete();
        
        // Try to delete from Storage
        try {
          await FirebaseStorage.instance
              .refFromURL(fileUrl)
              .delete();
        } catch (e) {
          print("Error deleting file from storage: $e");
          // Continue anyway
        }
        
        setState(() {
          cloudFiles.removeAt(index);
        });
      } else {
        // Just remove local file from list
        int localIndex = index - cloudFiles.length;
        setState(() {
          localFiles.removeAt(localIndex);
        });
      }
      
      _showSnackBar("$fileName deleted successfully");
    } catch (e) {
      print("Error deleting file: $e");
      _showSnackBar("Failed to delete file: ${e.toString()}");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown date';
    DateTime date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isSelecting
            ? Text('${selectedFiles.length} Selected',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))
            : Text('Medical Reports',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.teal,
        elevation: 2,
        iconTheme: IconThemeData(color: Colors.white),
        actions: isSelecting
            ? [
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red.shade100),
                  onPressed: selectedFiles.isNotEmpty ? deleteSelectedFiles : null,
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
            : [
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.white),
                  onPressed: isLoading ? null : () {
                    _fetchUserData();
                    _showSnackBar("Refreshing reports...");
                  },
                )
              ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.teal))
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.teal.shade50, Colors.white],
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
                          radius: 24,
                          child: Icon(Icons.person, color: Colors.white, size: 28),
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
                              if (age > 0 && gender.isNotEmpty) 
                                Text(
                                  "$age years, $gender${bloodGroup.isNotEmpty ? ', $bloodGroup' : ''}",
                                  style: TextStyle(fontSize: 14, color: Colors.black54),
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
                  
                  // Reports header
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Medical Reports',
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
                  
                  // Debug info - Remove in production
                  // Padding(
                  //   padding: EdgeInsets.symmetric(horizontal: 16.0),
                  //   child: Text(
                  //     "Cloud files: ${cloudFiles.length}, Local files: ${localFiles.length}",
                  //     style: TextStyle(color: Colors.grey, fontSize: 12),
                  //   ),
                  // ),
                  
                  // Main content - file list or empty state
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
                              
                              // Get additional details for cloud files
                              String fileSize = isCloud && file['fileSize'] != null
                                  ? _formatFileSize(file['fileSize'])
                                  : isCloud ? 'Unknown size' : 'Local file';
                              String uploadDate = isCloud && file['uploadDate'] != null
                                  ? _formatDate(file['uploadDate'])
                                  : isCloud ? 'Unknown date' : 'Not uploaded yet';
                              
                              return Card(
                                elevation: 3,
                                margin: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                color: isSelected ? Colors.blue.shade100 : Colors.white,
                                child: ListTile(
                                  onLongPress: () => toggleSelection(index),
                                  onTap: () {
                                    if (isSelecting) {
                                      toggleSelection(index);
                                    } else {
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
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isCloud ? Icons.cloud_done : Icons.file_present,
                                            size: 14,
                                            color: isCloud ? Colors.teal : Colors.orange,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            isCloud ? "Uploaded • $uploadDate" : "Local file",
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        fileSize,
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
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
                                            if (!isCloud && !isUploading)
                                              IconButton(
                                                icon: Icon(Icons.cloud_upload,
                                                    color: Colors.teal),
                                                onPressed: () => uploadFileToStorage(file),
                                                tooltip: 'Upload',
                                              ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.visibility,
                                                color: Colors.blue.shade900),
                                              onPressed: () => openFile(file),
                                              tooltip: 'View',
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.delete_outline, 
                                                color: Colors.red.shade400),
                                              onPressed: () => deleteFile(index),
                                              tooltip: 'Delete',
                                            ),
                                          ],
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
                  
                  // Button to add files
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      onPressed: !isUploading ? pickFile : null,
                      icon: Icon(Icons.add),
                      label: Text('Add New Reports', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isUploading ? Colors.grey : Colors.blue.shade900,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: Size(double.infinity, 48), // Width takes full width
                        disabledBackgroundColor: Colors.grey.shade400,
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
            label: 'Reports',
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
                  builder: (context) => PatientProfileScreen(),
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