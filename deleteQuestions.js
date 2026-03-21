const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function deleteQuestionsBySubject(subjectId) {
  console.log('════════════════════════════════════════');
  console.log('   PrepNG Question Deleter');
  console.log('════════════════════════════════════════\n');

  if (!subjectId) {
    console.error('❌ No subjectId provided.');
    console.error('Usage: node deleteQuestions.js <subjectId>');
    console.error('Example: node deleteQuestions.js 2J4XVFWR0VLf7Rn6X7zK');
    process.exit(1);
  }

  console.log(`🔍 Fetching questions for subjectId: ${subjectId}...`);

  const snapshot = await db.collection('questions')
    .where('subjectId', '==', subjectId)
    .get();

  const total = snapshot.size;

  if (total === 0) {
    console.log('✅ No questions found for this subject. Nothing to delete.');
    process.exit(0);
  }

  console.log(`📊 Found ${total} questions.`);
  console.log('⚠️  Press Ctrl+C within 5 seconds to cancel...\n');

  await new Promise(resolve => setTimeout(resolve, 5000));

  console.log('🗑️  Deleting in batches...\n');

  const BATCH_SIZE = 500;
  const docs = snapshot.docs;
  let deleted = 0;

  for (let i = 0; i < docs.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const batchDocs = docs.slice(i, i + BATCH_SIZE);

    batchDocs.forEach(doc => batch.delete(doc.ref));

    await batch.commit();
    deleted += batchDocs.length;

    const percentage = Math.round((deleted / total) * 100);
    console.log(`✅ Deleted: ${deleted}/${total} (${percentage}%)`);
  }

  console.log('\n🎉 Done! All questions for this subject have been deleted.');
  console.log('📍 Check Firebase Console to confirm.');
  process.exit(0);
}

const subjectId = process.argv[2];

deleteQuestionsBySubject(subjectId).catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});