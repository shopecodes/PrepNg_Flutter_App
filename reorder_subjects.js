const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function reorderSubjects() {
  console.log('🔍 Fetching all subjects...');

  const snapshot = await db.collection('subjects').get();

  if (snapshot.empty) {
    console.log('No subjects found!');
    return;
  }

  console.log(`📚 Found ${snapshot.docs.length} subjects total`);

  // Separate free subjects from paid subjects
  const freeSubjects = [];
  const paidSubjects = [];

  snapshot.docs.forEach((doc) => {
    const data = doc.data();
    if (data.isFree === true) {
      freeSubjects.push({ id: doc.id, data });
    } else {
      paidSubjects.push({ id: doc.id, data });
    }
  });

  console.log(`🆓 Free subjects: ${freeSubjects.length}`);
  console.log(`💰 Paid subjects: ${paidSubjects.length}`);

  // Free subjects get order 1, 2, 3...
  // Paid subjects follow after, sorted alphabetically by name
  paidSubjects.sort((a, b) =>
    (a.data.name || '').localeCompare(b.data.name || '')
  );

  const orderedSubjects = [...freeSubjects, ...paidSubjects];

  // Update all subjects in batches (Firestore batch limit is 500)
  const batch = db.batch();

  orderedSubjects.forEach((subject, index) => {
    const order = index + 1;
    const ref = db.collection('subjects').doc(subject.id);
    batch.update(ref, { order });
    console.log(
      `✅ ${subject.data.isFree ? '🆓' : '  '} [${order}] ${subject.data.name} (${subject.data.scopeId || 'no scope'})`
    );
  });

  console.log('\n💾 Saving to Firestore...');
  await batch.commit();
  console.log('🎉 Done! All subjects have been reordered successfully.');
  console.log('👉 Free subjects are now at the top, paid subjects are alphabetical below.');

  process.exit(0);
}

reorderSubjects().catch((error) => {
  console.error('❌ Error:', error);
  process.exit(1);
});