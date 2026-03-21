const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');
const fs = require('fs');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function exportSubjects() {
  console.log('Fetching WAEC subjects...\n');

  const snap = await db.collection('subjects')
    .where('scopeId', '==', 'gJP9J1i3KQQTXyuEahCp')
    .orderBy('order')
    .get();

  const subjects = [];

  snap.forEach(doc => {
    subjects.push({
      id: doc.id,
      name: doc.data().name,
      order: doc.data().order,
    });
    console.log(`${doc.data().order}. ${doc.data().name} → ${doc.id}`);
  });

  fs.writeFileSync('waec_subjects.json', JSON.stringify(subjects, null, 2));
  console.log('\n✅ Saved to waec_subjects.json');
  process.exit(0);
}

exportSubjects().catch(err => {
  console.error(err);
  process.exit(1);
});