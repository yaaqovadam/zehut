const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.generateTokenOnVerify = functions.firestore
  .document('citizens/{phone}')
  .onWrite(async (change, context) => {
    const afterData = change.after ? change.after.data() : null;
    const beforeData = change.before ? change.before.data() : null;
    const phone = context.params.phone;

    // 1. Exit if document deleted or unverified
    if (!afterData || afterData.verified !== true || !afterData.auth_code) {
      return null;
    }

    // 2. Trigger ONLY when a new auth_code arrives (prevents infinite loop on step 5)
    const isNewCode = !beforeData || afterData.auth_code !== beforeData.auth_code;
    if (!isNewCode) {
      return null;
    }

    try {
      const formattedPhone = phone.startsWith('0')
        ? '+972' + phone.substring(1)
        : (phone.startsWith('+') ? phone : '+' + phone);

      // 3. Create Auth user if doesn't exist
      try {
        await admin.auth().createUser({
          uid: formattedPhone,
          phoneNumber: formattedPhone
        });
        console.log("✅ Created Auth user:", formattedPhone);
      } catch (userError) {
        if (userError.code === 'auth/uid-already-exists' || userError.code === 'auth/phone-number-already-exists') {
          console.log("ℹ️ Auth user already exists:", formattedPhone);
        } else {
          console.error("❌ Error creating Auth user:", userError.message);
        }
      }

      // 4. Generate public_id (keep existing if already set)
      const publicId = afterData.public_id || admin.firestore().collection('_').doc().id;

      // 5. Mint custom token
      const customToken = await admin.auth().createCustomToken(formattedPhone);
      const authCode = afterData.auth_code;

      // 6. Write token for Flutter to consume
      await admin.firestore().collection('auth_tokens').doc(authCode).set({
        token: customToken,
        phone: formattedPhone,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // 7. Sync identity fields back to citizen doc
      await admin.firestore().collection('citizens').doc(phone).set({
        uid: formattedPhone,
        international_phone: formattedPhone,
        shaliach_number: formattedPhone.replace('+', ''),
        public_id: publicId
      }, { merge: true });

      console.log(`✅ Token dropped for ${formattedPhone} under code ${authCode}`);
      return null;
    } catch (error) {
      console.error("❌ Critical Error generating token:", error);
      return null;
    }
  });