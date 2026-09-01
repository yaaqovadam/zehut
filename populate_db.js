const admin = require("firebase-admin");

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: "zehut-engine"
});

const db = admin.firestore();
const BASE_URL = "https://pub-142306085f2b48bda4045cd9efdd0d28.r2.dev/";

const fileNames = [
  "moshe-feiglin-intro-zehut",
  "moshe-feiglin-bbc-blitz-hypocrisy",
  "moshe-feiglin-bbc-interview-exposed",
  "idf-combat-veterans-october-7-betrayals",
  "israel-dont-get-fooled-again",
  "moshe-feiglin-exposes-gadi-eisenkot",
  "moshe-feiglin-gadi-eisenkot-who-is-the-real-enemy",
  "moshe-feiglin-netanyahu-trump",
  "moshe-feiglin-the-burden-of-proof-is-on-you",
  "moshe-feiglin-trump-arab-states-strategy",
  "-FOnLUVKIJ8",
  "-wltFbb-J50",
  "1AXlcQx6mr0",
  "5KMTBoW3m6U",
  "9X2Pi7j4VSo",
  "DqONcL23FMY",
  "FwPwyqj6cag",
  "O4iiilHJD88",
  "Q4L5Q5uLQZU",
  "SjHYrPfsnEY",
  "anpEWKVFrm4",
  "dkZ_dWKv1mw",
  "fdhl0qj3NWk",
  "n8d7xteeQiE",
  "pzd38DK69Is",
  "qS37uX1M5nY"
];

async function populateFeeds() {
  console.log("🚀 Injecting all videos into 'feeds'...");
  const batch = db.batch();
  const collectionRef = db.collection("feeds");

  for (let i = 0; i < fileNames.length; i++) {
    const name = fileNames[i];
    const docRef = collectionRef.doc(`clip_${i + 1}`);
    
    batch.set(docRef, {
      index: i,
      title: name.replace(/-/g, " ").toUpperCase(),
      subtitle: "צפו עד הסוף",
      url: `${BASE_URL}${name}.mp4`,
      thumb: `${BASE_URL}${name}.jpg`,
      isLocked: false,
      like_count: 100 + i
    });
  }

  await batch.commit();
  console.log(`✅ Done! ${fileNames.length} videos written to Firestore 'feeds'.`);
  process.exit(0);
}

populateFeeds().catch(err => {
  console.error("❌ Failed:", err);
  process.exit(1);
});
