package ly.carmenkarla.shop.data

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.auth.EmailAuthProvider
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseUser
import com.google.firebase.auth.GoogleAuthProvider
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Firebase is configured in code rather than through google-services.json, so the app
 * needs no per-package console registration for email/password sign-in.
 */
private const val API_KEY = "AIzaSyCYq3iiiDvpY2ofJ4pJEWMx1b72CAg8ImE"
private const val APP_ID = "1:523142072341:web:1081c80f2f66888049661c"
private const val PROJECT_ID = "carmenkarlaapp"

class AccountService(context: Context) {

    private val auth: FirebaseAuth

    init {
        val existing = FirebaseApp.getApps(context).firstOrNull()
        val app = existing ?: FirebaseApp.initializeApp(
            context,
            FirebaseOptions.Builder()
                .setApiKey(API_KEY)
                .setApplicationId(APP_ID)
                .setProjectId(PROJECT_ID)
                .build(),
        )
        auth = FirebaseAuth.getInstance(app)
    }

    val user: FirebaseUser? get() = auth.currentUser

    val displayName: String
        get() = user?.displayName?.takeIf { it.isNotBlank() } ?: user?.email.orEmpty()

    suspend fun signIn(email: String, password: String) {
        await { auth.signInWithEmailAndPassword(email.trim(), password) }
    }

    /**
     * Signs in with a Google ID token obtained by the storefront's bridge page,
     * so the app needs no native OAuth client registration.
     */
    suspend fun signInWithGoogleToken(idToken: String) {
        await { auth.signInWithCredential(GoogleAuthProvider.getCredential(idToken, null)) }
    }

    suspend fun register(email: String, password: String) {
        await { auth.createUserWithEmailAndPassword(email.trim(), password) }
    }

    suspend fun resetPassword(email: String) {
        await { auth.sendPasswordResetEmail(email.trim()) }
    }

    fun signOut() = auth.signOut()

    val hasPasswordProvider: Boolean
        get() = auth.currentUser?.providerData?.any { it.providerId == "password" } == true

    /** Firebase requires a recent login before deletion, so re-authenticate first. */
    suspend fun deleteAccount(password: String) {
        val current = auth.currentUser ?: error("لا يوجد حساب مسجّل")
        val email = current.email.orEmpty()
        if (hasPasswordProvider) {
            if (password.isBlank()) error("أدخلي كلمة المرور للتأكيد")
            await { current.reauthenticate(EmailAuthProvider.getCredential(email, password)) }
        }
        await { current.delete() }
    }

    /** Fresh ID token for backend calls, or empty when signed out. */
    suspend fun idToken(): String {
        val current = auth.currentUser ?: return ""
        return suspendCancellableCoroutine { continuation ->
            current.getIdToken(false)
                .addOnSuccessListener { continuation.resume(it.token.orEmpty()) }
                .addOnFailureListener { continuation.resume("") }
        }
    }

    private suspend fun <T> await(block: () -> com.google.android.gms.tasks.Task<T>): T =
        suspendCancellableCoroutine { continuation ->
            block()
                .addOnSuccessListener { continuation.resume(it) }
                .addOnFailureListener { continuation.resumeWithException(translate(it)) }
        }

    private fun translate(error: Exception): Exception {
        val message = when {
            error.message?.contains("password is invalid", true) == true ||
                error.message?.contains("INVALID_LOGIN", true) == true -> "البريد أو كلمة المرور غير صحيحة"
            error.message?.contains("email address is already", true) == true -> "يوجد حساب بهذا البريد بالفعل"
            error.message?.contains("badly formatted", true) == true -> "صيغة البريد غير صحيحة"
            error.message?.contains("at least 6 characters", true) == true -> "كلمة المرور 6 أحرف على الأقل"
            error.message?.contains("canceled", true) == true -> "تم إلغاء تسجيل الدخول"
            error.message?.contains("web-context", true) == true -> "تعذر فتح نافذة جوجل، حاولي مجددًا"
            error.message?.contains("network", true) == true -> "تحققي من الاتصال بالإنترنت"
            else -> error.message ?: "تعذر إتمام العملية"
        }
        return IllegalStateException(message)
    }
}
