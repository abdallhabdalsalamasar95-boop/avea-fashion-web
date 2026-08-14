import { updateProfile, User } from "firebase/auth";
import { AmbassadorProfile } from "@/lib/types";

const PROFILE_TIMEOUT_MS = 8000;
export const AMBASSADOR_PROFILE_UPDATED_EVENT = "avea:ambassador-profile-updated";
const FIREBASE_PROJECT_ID = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || "carmenkarlaapp";
const FIRESTORE_DOCUMENTS_URL = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents`;
const API_BASE_URL = (process.env.NEXT_PUBLIC_API_BASE_URL || "https://carmenkarla-backend.onrender.com").replace(/\/$/, "");

function withTimeout<T>(promise: Promise<T>, message: string): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timer = window.setTimeout(() => reject(new Error(message)), PROFILE_TIMEOUT_MS);
    promise.then(
      (value) => {
        window.clearTimeout(timer);
        resolve(value);
      },
      (reason) => {
        window.clearTimeout(timer);
        reject(reason);
      },
    );
  });
}

export function normalizeLibyanPhone(value: string): string {
  const arabicDigits = "٠١٢٣٤٥٦٧٨٩";
  return value.replace(/[٠-٩]/g, (digit) => String(arabicDigits.indexOf(digit))).replace(/[^0-9+]/g, "");
}

export function validPhone(value: string): boolean {
  return /^\+?[0-9]{8,15}$/.test(normalizeLibyanPhone(value));
}

type FirestoreFields = Record<string, { stringValue?: string; integerValue?: string }>;

function decodeFields(fields: FirestoreFields | undefined): Record<string, string | number> {
  const data: Record<string, string | number> = {};
  for (const [key, value] of Object.entries(fields ?? {})) {
    if (value.integerValue !== undefined) data[key] = Number(value.integerValue);
    else data[key] = String(value.stringValue ?? "");
  }
  return data;
}

function encodeProfile(profile: AmbassadorProfile): FirestoreFields {
  return {
    uid: { stringValue: profile.uid },
    accountRole: { stringValue: profile.accountRole },
    ambassadorName: { stringValue: profile.ambassadorName },
    ambassadorPhone: { stringValue: profile.ambassadorPhone },
    ambassadorAddress: { stringValue: profile.ambassadorAddress },
    email: { stringValue: profile.email },
    status: { stringValue: profile.status },
    joinedAt: { integerValue: String(profile.joinedAt) },
    updatedAt: { integerValue: String(profile.updatedAt) },
  };
}

async function authenticatedRequest(user: User, method: "GET" | "PATCH", body?: object): Promise<Response> {
  const token = await user.getIdToken();
  return withTimeout(fetch(`${FIRESTORE_DOCUMENTS_URL}/users/${encodeURIComponent(user.uid)}`, {
    method,
    headers: {
      Accept: "application/json",
      Authorization: `Bearer ${token}`,
      ...(body ? { "Content-Type": "application/json" } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
    cache: "no-store",
  }), method === "GET" ? "استغرق تحميل الحساب وقتًا طويلًا. حاولي مجددًا." : "استغرق تفعيل الحساب وقتًا طويلًا. تحققي من الاتصال وحاولي مجددًا.");
}

export async function getAmbassadorProfile(user: User): Promise<AmbassadorProfile | null> {
  const response = await authenticatedRequest(user, "GET");
  if (response.status === 404) return null;
  if (!response.ok) throw new Error(`تعذر تحميل الحساب (${response.status})`);
  const payload = await response.json() as { fields?: FirestoreFields };
  const data = decodeFields(payload.fields);
  if (data.accountRole !== "ambassador" || (data.status && data.status !== "active")) return null;
  return {
    uid: user.uid,
    accountRole: "ambassador",
    ambassadorName: String(data.ambassadorName ?? ""),
    ambassadorPhone: String(data.ambassadorPhone ?? ""),
    ambassadorAddress: String(data.ambassadorAddress ?? ""),
    email: String(data.email ?? ""),
    status: "active",
    joinedAt: Number(data.joinedAt ?? Date.now()),
    updatedAt: Number(data.updatedAt ?? Date.now()),
  };
}

export async function saveAmbassadorProfile(
  user: User,
  values: Pick<AmbassadorProfile, "ambassadorName" | "ambassadorPhone" | "ambassadorAddress">,
  existing?: AmbassadorProfile | null,
): Promise<AmbassadorProfile> {
  const now = Date.now();
  const profile: AmbassadorProfile = {
    uid: user.uid,
    accountRole: "ambassador",
    ambassadorName: values.ambassadorName.trim(),
    ambassadorPhone: normalizeLibyanPhone(values.ambassadorPhone),
    ambassadorAddress: values.ambassadorAddress.trim(),
    email: user.email ?? existing?.email ?? "",
    status: "active",
    joinedAt: existing?.joinedAt ?? now,
    updatedAt: now,
  };
  const response = await authenticatedRequest(user, "PATCH", { fields: encodeProfile(profile) });
  if (!response.ok) {
    throw new Error(response.status === 403 ? "لا توجد صلاحية لحفظ الحساب." : `تعذر تفعيل الحساب (${response.status})`);
  }
  if (profile.ambassadorName && user.displayName !== profile.ambassadorName) {
    void updateProfile(user, { displayName: profile.ambassadorName }).catch(() => undefined);
  }
  void user.getIdToken().then((token) => withTimeout(fetch(`${API_BASE_URL}/ambassadors/me/profile`, {
    method: "PUT",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify(values),
  }), "")).catch(() => undefined);
  window.dispatchEvent(new CustomEvent(AMBASSADOR_PROFILE_UPDATED_EVENT, { detail: profile }));
  return profile;
}