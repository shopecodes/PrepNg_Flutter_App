const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');
const fs = require('fs');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function uploadQuestions(filename) {
  try {
    // Read and parse JSON file
    console.log(`📖 Reading ${filename}...`);
    const questions = JSON.parse(fs.readFileSync(filename, 'utf8'));
    console.log(`✅ Found ${questions.length} questions\n`);
    
    // Validate questions structure
    console.log('🔍 Validating questions...');
    const requiredFields = ['text', 'options', 'correctIndex', 'subjectId', 'scopeId'];
    
    for (let i = 0; i < questions.length; i++) {
      const q = questions[i];
      
      // FIXED LOGIC: Specifically check if the field is undefined or null 
      // This prevents '0' from being flagged as missing
      const missing = requiredFields.filter(field => q[field] === undefined || q[field] === null || q[field] === '');
      
      if (missing.length > 0) {
        throw new Error(`Question ${i + 1} is missing: ${missing.join(', ')}`);
      }
      
      if (!Array.isArray(q.options) || q.options.length !== 4) {
        throw new Error(`Question ${i + 1} must have exactly 4 options`);
      }
      
      if (q.correctIndex < 0 || q.correctIndex > 3) {
        throw new Error(`Question ${i + 1} has invalid correctIndex (must be 0-3)`);
      }
    }
    
    console.log('✅ All questions validated\n');
    
    // Show preview of first question
    console.log('📋 First Question Preview:');
    console.log('  Subject ID:', questions[0].subjectId);
    console.log('  Scope ID:', questions[0].scopeId);
    console.log('  Question:', questions[0].text.substring(0, 60) + '...');
    console.log('  Correct Answer:', questions[0].options[questions[0].correctIndex]);
    console.log('\n⚠️  Press Ctrl+C within 5 seconds to cancel...\n');
    
    // Wait 5 seconds before upload
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    // Upload in batches (Firestore limit is 500 per batch)
    console.log('📤 Starting upload...\n');
    const BATCH_SIZE = 500;
    let totalUploaded = 0;
    
    for (let i = 0; i < questions.length; i += BATCH_SIZE) {
      const batch = db.batch();
      const batchQuestions = questions.slice(i, Math.min(i + BATCH_SIZE, questions.length));
      
      batchQuestions.forEach((question) => {
        const docRef = db.collection('questions').doc();
        batch.set(docRef, {
          ...question,
          uploadedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      });
      
      await batch.commit();
      totalUploaded += batchQuestions.length;
      
      const percentage = Math.round((totalUploaded / questions.length) * 100);
      console.log(`✅ Progress: ${totalUploaded}/${questions.length} (${percentage}%)`);
    }
    
    console.log('\n🎉 SUCCESS! All questions uploaded to Firebase!');
    console.log('📍 Check: Firebase Console → Firestore Database → questions collection');
    console.log(`📊 Total uploaded: ${totalUploaded} questions`);
    
  } catch (error) {
    console.error('\n❌ UPLOAD FAILED!');
    console.error('Error:', error.message);
    
    if (error.code === 'ENOENT') {
      console.error(`\n💡 File not found: ${filename}`);
      console.error('Make sure the file exists in the current directory.');
    } else if (error instanceof SyntaxError) {
      console.error('\n💡 Invalid JSON format!');
      console.error('Validate your JSON at: https://jsonlint.com/');
    }
    
    process.exit(1);
  }
}

// Get filename from command line argument or use default
const filename = process.argv[2] || 'questions_upload.json';

console.log('════════════════════════════════════════');
console.log('   PrepNG Question Uploader');
console.log('════════════════════════════════════════\n');

uploadQuestions(filename)
  .then(() => {
    console.log('\n✨ Upload complete! Exiting...\n');
    process.exit(0);
  })
  .catch(error => {
    console.error('💥 Fatal error:', error);
    process.exit(1);
  });