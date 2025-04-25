/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });


const functions = require('firebase-functions');
const twilio = require('twilio');

const accountSid = 'ACcf96fb342f2477099577e1f7ab9c48c2';
const authToken = 'eba9b18cafdab20aefa96ab12d511b3e';
const twilioNumber = '+19786253464';

const client = twilio(accountSid, authToken);

exports.sendSms = functions.https.onCall(async (data, context) => {
  const phoneNumber = data.phone;
  const message = data.message;

  try {
    const res = await client.messages.create({
      body: message,
      from: twilioNumber,
      to: phoneNumber,
    });

    return { success: true, sid: res.sid };
  } catch (error) {
    return { success: false, error: error.message };
  }
});
