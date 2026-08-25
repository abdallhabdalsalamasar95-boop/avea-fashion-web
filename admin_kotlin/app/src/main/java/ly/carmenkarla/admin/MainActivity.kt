package ly.carmenkarla.admin

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.Logout
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.QueryStats
import androidx.compose.material.icons.filled.ReceiptLong
import androidx.compose.material.icons.filled.Savings
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.runtime.CompositionLocalProvider
import kotlinx.coroutines.launch
import ly.carmenkarla.admin.ui.accounting.AccountingScreen
import ly.carmenkarla.admin.ui.ambassadors.AmbassadorsScreen
import ly.carmenkarla.admin.ui.customers.CustomersScreen
import ly.carmenkarla.admin.ui.dashboard.DashboardScreen
import ly.carmenkarla.admin.ui.inventory.InventoryAlertsScreen
import ly.carmenkarla.admin.ui.presence.LiveVisitorsScreen
import ly.carmenkarla.admin.ui.login.LoginScreen
import ly.carmenkarla.admin.ui.orders.OrdersScreen
import ly.carmenkarla.admin.ui.products.ProductEditorScreen
import ly.carmenkarla.admin.ui.products.ProductsScreen
import ly.carmenkarla.admin.ui.site.SiteScreen
import ly.carmenkarla.admin.ui.theme.AdminTheme

private enum class Tab(val label: String, val icon: ImageVector) {
    Dashboard("الإحصائيات", Icons.Default.QueryStats),
    Orders("الطلبات", Icons.Default.ReceiptLong),
    Products("المنتجات", Icons.Default.Inventory2),
    Ambassadors("المندوبين", Icons.Default.Groups),
    Accounting("المحاسبة", Icons.Default.Savings),
    Site("الموقع", Icons.Default.Palette),
}

class MainActivity : ComponentActivity() {

    private val notificationPermission = registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        askForNotifications()
        setContent {
            AdminTheme {
                CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                    Surface { AdminRoot() }
                }
            }
        }
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
private fun AdminRoot() {
    val repository = AdminApp.instance.repository
    val scope = rememberCoroutineScope()

    var signedIn by remember { mutableStateOf<Boolean?>(null) }
    var tab by remember { mutableStateOf(Tab.Dashboard) }
    var editorProductId by remember { mutableStateOf<String?>(null) }
    var editorOpen by remember { mutableStateOf(false) }
    var productsRefresh by remember { mutableStateOf(0) }
    var customersOpen by remember { mutableStateOf(false) }
    var liveVisitorsOpen by remember { mutableStateOf(false) }
    var inventoryOpen by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        signedIn = repository.settings.currentToken().isNotEmpty()
    }

    when (signedIn) {
        null -> Box(Modifier) {}
        false -> LoginScreen { signedIn = true }
        true -> {
            if (editorOpen) {
                ProductEditorScreen(
                    productId = editorProductId,
                    onDone = {
                        editorOpen = false
                        productsRefresh++
                    },
                    onBack = { editorOpen = false },
                )
                return
            }

            if (customersOpen) {
                CustomersScreen(onBack = { customersOpen = false })
                return
            }

            if (liveVisitorsOpen) {
                LiveVisitorsScreen(onBack = { liveVisitorsOpen = false })
                return
            }

            if (inventoryOpen) {
                InventoryAlertsScreen(
                    onBack = { inventoryOpen = false },
                    onOpenProduct = {
                        inventoryOpen = false
                        editorProductId = it
                        editorOpen = true
                    },
                )
                return
            }

            Scaffold(
                topBar = {
                    TopAppBar(
                        title = { Text(tab.label) },
                        actions = {
                            IconButton(onClick = {
                                scope.launch {
                                    repository.settings.clearToken()
                                    repository.invalidate()
                                    signedIn = false
                                }
                            }) { Icon(Icons.Default.Logout, "خروج") }
                        },
                    )
                },
                bottomBar = {
                    NavigationBar {
                        Tab.entries.forEach { entry ->
                            NavigationBarItem(
                                selected = tab == entry,
                                onClick = { tab = entry },
                                icon = { Icon(entry.icon, entry.label) },
                                label = { Text(entry.label) },
                            )
                        }
                    }
                },
            ) { padding ->
                Box(Modifier.padding(padding)) {
                    when (tab) {
                        Tab.Dashboard -> DashboardScreen(
                            onOpenCustomers = { customersOpen = true },
                            onOpenInventory = { inventoryOpen = true },
                            onOpenLiveVisitors = { liveVisitorsOpen = true },
                        )
                        Tab.Orders -> OrdersScreen()
                        Tab.Products -> ProductsScreen(
                            onOpenEditor = {
                                editorProductId = it
                                editorOpen = true
                            },
                            refreshKey = productsRefresh,
                        )
                        Tab.Ambassadors -> AmbassadorsScreen()
                        Tab.Accounting -> AccountingScreen()
                        Tab.Site -> SiteScreen()
                    }
                }
            }
        }
    }
}
