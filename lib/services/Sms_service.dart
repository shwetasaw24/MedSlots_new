import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TwilioService {
  // Twilio credentials - should be stored in environment variables or secure storage
  final String accountSid = dotenv.env['TWILIO_ACCOUNT_SID'] ?? '';
  final String authToken = dotenv.env['TWILIO_AUTH_TOKEN'] ?? '';
  final String twilioNumber = dotenv.env['TWILIO_PHONE_NUMBER'] ?? '';

  // Method to send SMS
  Future<bool> sendSMS({required String to, required String message}) async {
    // Validate credentials
    if (accountSid.isEmpty || authToken.isEmpty || twilioNumber.isEmpty) {
      print("ERROR: Twilio credentials are not configured properly");
      return false;
    }

    // Format phone number
    if (!to.startsWith('+')) {
      to = '+$to'; // Add + if missing
    }
    
    // Remove any non-numeric characters except the leading '+'
    to = '+' + to.replaceAll(RegExp(r'[^\d]'), '').substring(to.startsWith('+') ? 1 : 0);

    try {
      // Twilio API endpoint
      final url = Uri.parse('https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json');
      
      // Request body
      final body = {
        'From': twilioNumber,
        'To': to,
        'Body': message,
      };
      
      // Basic authentication header
      final authString = base64.encode(utf8.encode('$accountSid:$authToken'));
      
      // Send request
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic $authString',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );
      
      // Check response
      if (response.statusCode == 201 || response.statusCode == 200) {
        print("SMS sent successfully");
        final responseData = json.decode(response.body);
        print("Twilio response: $responseData");
        return true;
      } else {
        print("Failed to send SMS. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Exception while sending SMS: $e");
      return false;
    }
  }
}