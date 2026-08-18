import { getApp, getApps, initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";

const projectId = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || "carmenkarlaapp";

// A custom auth domain must serve /__/auth/* ; karla.onrender.com returns 404, so only Firebase-hosted domains are trusted.
const configuredAuthDomain = process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN || "";
const authDomain = /\.(firebaseapp\.com|web\.app)$/.test(configuredAuthDomain)
  ? configuredAuthDomain
  : `${projectId}.firebaseapp.com`;

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY || "AIzaSyCYq3iiiDvpY2ofJ4pJEWMx1b72CAg8ImE",
  authDomain,
  projectId,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET || "carmenkarlaapp.firebasestorage.app",
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID || "523142072341",
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID || "1:523142072341:web:1081c80f2f66888049661c",
};

const app = getApps().length ? getApp() : initializeApp(firebaseConfig);
export const auth = getAuth(app);
