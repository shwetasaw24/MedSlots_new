// class PatientLoginScreen extends StatefulWidget {
//   @override
//   _PatientLoginScreenState createState() => _PatientLoginScreenState();
// }

// class _PatientLoginScreenState extends State<PatientLoginScreen> {
//   final _auth = FirebaseAuth.instance;
//   final _formKey = GlobalKey<FormState>();

//   String email = '';
//   String password = '';
//   bool isLoading = false;

//   Future<void> _login() async {
//     if (!_formKey.currentState!.validate()) return;

//     setState(() => isLoading = true);

//     try {
//       await _auth.signInWithEmailAndPassword(email: email, password: password);
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Patient Login Successful!')));

//       // Navigate to Patient Dashboard
//       Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => PatientDashboard()));

//     } on FirebaseAuthException catch (e) {
//       String message = 'An error occurred. Please try again.';
//       if (e.code == 'user-not-found') {
//         message = 'No patient account found with this email.';
//       } else if (e.code == 'wrong-password') {
//         message = 'Incorrect password.';
//       }
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Patient Login'),
//         backgroundColor: Colors.teal,
//         foregroundColor: Colors.white,
//         leading: IconButton(
//           icon: Icon(Icons.arrow_back),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: SafeArea(
//         child: SingleChildScrollView(
//           child: Padding(
//             padding: const EdgeInsets.all(20.0),
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
//                   // Patient Icon and Title
//                   Icon(Icons.personal_injury, size: 70, color: Colors.teal),
//                   Text(
//                     'PATIENT LOGIN',
//                     style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.teal),
//                   ),
//                   Text(
//                     'Access your patient account',
//                     style: TextStyle(
//                       fontSize: 16,
//                       color: Colors.grey[600],
//                     ),
//                   ),
//                   SizedBox(height: 30),

//                   // Patient role indicator
//                   Container(
//                     padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
//                     decoration: BoxDecoration(
//                       color: Colors.teal.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(8),
//                       border: Border.all(color: Colors.teal, width: 1),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Icon(Icons.health_and_safety, color: Colors.teal),
//                         SizedBox(width: 8),
//                         Text(
//                           'Logging in as Patient',
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             color: Colors.teal
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   SizedBox(height: 30),

//                   // Email Input
//                   TextFormField(
//                     decoration: InputDecoration(
//                       labelText: 'Patient Email',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.email, color: Colors.teal),
//                     ),
//                     keyboardType: TextInputType.emailAddress,
//                     onChanged: (value) => email = value,
//                     validator: (value) => value!.isEmpty || !value.contains('@') ? 'Enter a valid email' : null,
//                   ),
//                   SizedBox(height: 15),

//                   // Password Input
//                   TextFormField(
//                     decoration: InputDecoration(
//                       labelText: 'Password',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.lock, color: Colors.teal),
//                     ),
//                     obscureText: true,
//                     onChanged: (value) => password = value,
//                     validator: (value) => value!.length < 6 ? 'Password must be at least 6 characters' : null,
//                   ),
//                   SizedBox(height: 30),

//                   // Login Button
//                   SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton(
//                       onPressed: isLoading ? null : _login,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.teal,
//                         padding: EdgeInsets.symmetric(vertical: 15),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                       ),
//                       child: isLoading
//                           ? CircularProgressIndicator(color: Colors.white)
//                           : Text('LOGIN AS PATIENT', style: TextStyle(fontSize: 18, color: Colors.white)),
//                     ),
//                   ),

//                   SizedBox(height: 20),

//                   // Sign Up Redirect
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text('Don\'t have a patient account?'),
//                       TextButton(
//                         onPressed: () {
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(builder: (context) => PatientSignUpScreen()),
//                           );
//                         },
//                         child: Text('Sign Up', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }