package ly.carmenkarla.shop

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Diamond
import androidx.compose.material.icons.outlined.Favorite
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.GridView
import androidx.compose.material.icons.outlined.PersonOutline
import androidx.compose.material.icons.outlined.ReceiptLong
import androidx.compose.material.icons.outlined.ShoppingCart
import androidx.compose.material.icons.outlined.Storefront
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.delay
import ly.carmenkarla.shop.ui.account.AccountScreen
import ly.carmenkarla.shop.ui.account.LegalContent
import ly.carmenkarla.shop.ui.account.LegalScreen
import ly.carmenkarla.shop.ui.account.SettingsScreen
import ly.carmenkarla.shop.ui.ambassador.AmbassadorScreen
import ly.carmenkarla.shop.ui.cart.CartScreen
import ly.carmenkarla.shop.ui.checkout.CheckoutScreen
import ly.carmenkarla.shop.ui.favorites.FavoritesScreen
import ly.carmenkarla.shop.ui.home.HomeScreen
import ly.carmenkarla.shop.ui.orders.OrdersScreen
import ly.carmenkarla.shop.ui.product.ProductScreen
import ly.carmenkarla.shop.ui.WelcomeScreen
import ly.carmenkarla.shop.ui.theme.ShopTheme
import ly.carmenkarla.shop.ui.wholesale.WholesaleScreen
import ly.carmenkarla.shop.ui.theme.WordmarkStyle

private enum class Tab(val label: String, val icon: ImageVector) {
    Home("الرئيسية", Icons.Outlined.Storefront),
    Ambassador("المندوبات", Icons.Outlined.Diamond),
    Cart("السلة", Icons.Outlined.ShoppingCart),
    Orders("الطلبات", Icons.Outlined.ReceiptLong),
    Account("الحساب", Icons.Outlined.PersonOutline),
}

class MainActivity : ComponentActivity() {

    private val incomingLink = mutableStateOf<Uri?>(null)

    private val notificationPermission = registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        incomingLink.value = intent?.data
        askForNotifications()
        setContent {
            ShopTheme {
                CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                    var showWelcome by rememberSaveable { mutableStateOf(true) }
                    Surface(color = MaterialTheme.colorScheme.background) {
                        ShopRoot(incomingLink)
                    }
                    AnimatedVisibility(
                        visible = showWelcome,
                        enter = EnterTransition.None,
                        exit = fadeOut(tween(420)),
                    ) {
                        WelcomeScreen(onDone = { showWelcome = false })
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        incomingLink.value = intent.data
    }

    private fun askForNotifications() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ShopRoot(incomingLink: MutableState<Uri?>) {
    var tab by remember { mutableStateOf(Tab.Home) }
    var openProductId by remember { mutableStateOf<String?>(null) }
    var checkoutOpen by remember { mutableStateOf(false) }
    var settingsOpen by remember { mutableStateOf(false) }
    var legalOpen by remember { mutableStateOf("") }
    var favoritesOpen by remember { mutableStateOf(false) }
    var wholesaleOpen by remember { mutableStateOf(false) }

    val lifecycleOwner = LocalLifecycleOwner.current
    LaunchedEffect(Unit) {
        lifecycleOwner.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            while (ShopApp.instance.presenceEnabled) {
                ShopApp.instance.pingPresence(tab.label)
                delay(30_000)
            }
        }
    }

    LaunchedEffect(incomingLink.value) {
        val uri = incomingLink.value ?: return@LaunchedEffect
        incomingLink.value = null
        when {
            uri.scheme == "carmenkarla" && uri.host == "auth" -> {
                val token = uri.getQueryParameter("idToken").orEmpty()
                if (token.isNotBlank()) {
                    val app = ShopApp.instance
                    runCatching { app.account.signInWithGoogleToken(token) }
                        .onSuccess {
                            app.refreshAmbassador()
                            app.accountRevision++
                            tab = Tab.Account
                        }
                }
            }
            uri.path.orEmpty().startsWith("/product") -> {
                uri.getQueryParameter("ref")?.takeIf { it.isNotBlank() }?.let {
                    ShopApp.instance.rememberSharedAmbassadorToken(it)
                }
                uri.getQueryParameter("id")?.takeIf { it.isNotBlank() }?.let { openProductId = it }
            }
            uri.path.orEmpty().startsWith("/shared-order") -> {
                uri.getQueryParameter("ref")?.takeIf { it.isNotBlank() }?.let {
                    ShopApp.instance.rememberSharedAmbassadorToken(it)
                }
                val added = ShopApp.instance.applySharedCart(uri.getQueryParameter("cart").orEmpty())
                if (added) tab = Tab.Cart
            }
            uri.path.isNullOrBlank() || uri.path == "/" -> {
                uri.getQueryParameter("ref")?.takeIf { it.isNotBlank() }?.let {
                    ShopApp.instance.rememberSharedAmbassadorToken(it)
                }
            }
        }
    }

    // Back should unwind the app's own stack; only the store tab exits.
    BackHandler(enabled = legalOpen.isNotEmpty()) { legalOpen = "" }
    BackHandler(enabled = legalOpen.isEmpty() && settingsOpen) { settingsOpen = false }
    BackHandler(enabled = legalOpen.isEmpty() && !settingsOpen && favoritesOpen) { favoritesOpen = false }
    BackHandler(
        enabled = legalOpen.isEmpty() && !settingsOpen && !favoritesOpen && wholesaleOpen &&
            openProductId == null,
    ) { wholesaleOpen = false }
    BackHandler(
        enabled = legalOpen.isEmpty() && !settingsOpen && !favoritesOpen && openProductId != null,
    ) { openProductId = null }
    BackHandler(
        enabled = legalOpen.isEmpty() && !settingsOpen && !favoritesOpen &&
            openProductId == null && checkoutOpen,
    ) { checkoutOpen = false }
    BackHandler(
        enabled = legalOpen.isEmpty() && !settingsOpen && !favoritesOpen &&
            openProductId == null && !checkoutOpen && tab != Tab.Home,
    ) { tab = Tab.Home }

    if (legalOpen.isNotEmpty()) {
        val privacy = legalOpen == "privacy"
        LegalScreen(
            title = if (privacy) "سياسة الخصوصية" else "الشروط والأحكام",
            sections = if (privacy) LegalContent.privacy else LegalContent.terms,
            onBack = { legalOpen = "" },
        )
        return
    }

    if (settingsOpen) {
        SettingsScreen(
            onBack = { settingsOpen = false },
            onOpenPrivacy = { legalOpen = "privacy" },
            onOpenTerms = { legalOpen = "terms" },
        )
        return
    }

    if (favoritesOpen) {
        FavoritesScreen(
            onBack = { favoritesOpen = false },
            onOpenProduct = {
                favoritesOpen = false
                openProductId = it
            },
        )
        return
    }

    openProductId?.let { id ->
        ProductScreen(
            productId = id,
            onBack = { openProductId = null },
            onOpenCart = {
                openProductId = null
                tab = Tab.Cart
            },
            onBuyNow = {
                openProductId = null
                checkoutOpen = true
            },
            onOpenRelated = { openProductId = it },
        )
        return
    }

    if (wholesaleOpen) {
        WholesaleScreen(
            onBack = { wholesaleOpen = false },
            onOpenProduct = { openProductId = it },
        )
        return
    }

    if (checkoutOpen) {
        CheckoutScreen(
            onBack = { checkoutOpen = false },
            onDone = {
                checkoutOpen = false
                tab = Tab.Orders
            },
        )
        return
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            Column {
                CenterAlignedTopAppBar(
                    title = { Wordmark() },
                    expandedHeight = 50.dp,
                    actions = {
                        val saved = ShopApp.instance.favorites.size
                        BadgedBox(
                            badge = {
                                if (saved > 0) {
                                    Badge(containerColor = Color(0xFFB25078)) { Text("$saved") }
                                }
                            },
                        ) {
                            IconButton(onClick = { favoritesOpen = true }) {
                                Icon(
                                    if (saved > 0) Icons.Outlined.Favorite else Icons.Outlined.FavoriteBorder,
                                    "المفضلة",
                                )
                            }
                        }
                    },
                    colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                        containerColor = MaterialTheme.colorScheme.surface,
                    ),
                )
                HorizontalDivider(color = MaterialTheme.colorScheme.outline)
            }
        },
        bottomBar = { SlimBottomBar(tab) { tab = it } },
    ) { padding ->
        Box(Modifier.padding(padding)) {
            when (tab) {
                Tab.Home -> HomeScreen(
                    onOpenProduct = { openProductId = it },
                    onOpenAmbassador = { tab = Tab.Ambassador },
                    onOpenWholesale = { wholesaleOpen = true },
                )
                Tab.Ambassador -> AmbassadorScreen(
                    onBack = null,
                    onStartOrder = { tab = Tab.Home },
                )
                Tab.Cart -> CartScreen(
                    onCheckout = { checkoutOpen = true },
                    onContinueShopping = { tab = Tab.Home },
                )
                Tab.Orders -> OrdersScreen()
                Tab.Account -> AccountScreen(
                    onOpenAmbassador = { tab = Tab.Ambassador },
                    onOpenSettings = { settingsOpen = true },
                )
            }
        }
    }
}

@Composable
private fun Wordmark() {
    Image(
        painter = painterResource(R.drawable.brand_wordmark),
        contentDescription = "Carmen Karla",
        modifier = Modifier.height(34.dp),
        contentScale = ContentScale.Fit,
    )
}

/** Hand-rolled so the bar stays 56dp instead of Material's default 80dp. */
@Composable
private fun SlimBottomBar(current: Tab, onSelect: (Tab) -> Unit) {
    val app = ShopApp.instance
    Column(Modifier.background(MaterialTheme.colorScheme.surface)) {
        HorizontalDivider(color = MaterialTheme.colorScheme.outline)
        Row(
            Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .height(48.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Tab.entries.forEach { entry ->
                val active = entry == current
                val tint by animateColorAsState(
                    if (active) MaterialTheme.colorScheme.onSurface
                    else MaterialTheme.colorScheme.onSurfaceVariant,
                    label = "tabTint",
                )
                Column(
                    Modifier
                        .weight(1f)
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null,
                        ) { onSelect(entry) },
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    if (entry == Tab.Cart && app.cartCount > 0) {
                        BadgedBox(
                            badge = {
                                Badge(containerColor = Color(0xFFB25078)) {
                                    Text(app.cartCount.toString(), style = MaterialTheme.typography.labelSmall)
                                }
                            },
                        ) { Icon(entry.icon, entry.label, Modifier.size(19.dp), tint = tint) }
                    } else {
                        Icon(entry.icon, entry.label, Modifier.size(19.dp), tint = tint)
                    }
                    Spacer(Modifier.height(1.dp))
                    Text(
                        entry.label,
                        style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.5.sp),
                        color = tint,
                    )
                }
            }
        }
    }
}
