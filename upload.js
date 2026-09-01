const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const fs = require('fs');

const R2 = new S3Client({
  region: "auto",
  endpoint: "https://<YOUR_ACCOUNT_ID>.r2.cloudflarestorage.com",
  credentials: {
    accessKeyId: "YOUR_ACCESS_KEY_ID",
    secretAccessKey: "YOUR_SECRET_ACCESS_KEY",
  },
});

async function uploadCleanFile(filePath, cleanFileName) {
  const fileStream = fs.createReadStream(filePath);
  const uploadParams = {
    Bucket: "your-bucket-name",
    Key: cleanFileName,
    Body: fileStream,
    ContentType: "video/mp4",
  };

  try {
    await R2.send(new PutObjectCommand(uploadParams));
    console.log(`🚀 Successfully uploaded as: ${cleanFileName}`);
  } catch (err) {
    console.error("Upload failed:", err);
  }
}

const args = process.argv.slice(2);
if (args.length >= 2) {
  uploadCleanFile(args[0], args[1]);
} else {
  console.log("Usage: node upload.js <local_file> <clean_name.mp4>");
}