const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function run() {
  console.log("Checking Firestore 'feeds' collection...");
  const snapshot = await db.collection('feeds').get();
  
  const r2Thumb = "https://pub-142306085f2b48bda4045cd9efdd0d28.r2.dev/intro-logo.jpg";
  let count = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const currentThumb = data.thumb || '';
    
    if (currentThumb !== r2Thumb) {
      await db.collection('feeds').doc(doc.id).update({
        'thumb': r2Thumb
      });
      console.log(`Updated document ID: ${doc.id} -> set thumb to R2`);
      count++;
    }
  }
  
  console.log(`Finished! Updated ${count} documents with the correct thumbnail link.`);
}

run().catch(console.error);
