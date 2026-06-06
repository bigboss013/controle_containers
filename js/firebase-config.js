const firebaseConfig = {
  apiKey: "AIzaSyCje8V9yQcgJ6LJL1AhyViKq8ArtjARsRA",
  authDomain: "santos-transportes.firebaseapp.com",
  projectId: "santos-transportes",
  storageBucket: "santos-transportes.firebasestorage.app"
};

firebase.initializeApp(firebaseConfig);
const db = firebase.firestore();
db.settings({
  experimentalForceLongPolling: true,
  merge: true
});
