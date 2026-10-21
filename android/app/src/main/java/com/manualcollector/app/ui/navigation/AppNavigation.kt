package com.manualcollector.app.ui.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.QuestionAnswer
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.manualcollector.app.R
import com.manualcollector.app.ui.screens.AskScreen
import com.manualcollector.app.ui.screens.LibraryDetailScreen
import com.manualcollector.app.ui.screens.LibraryScreen
import com.manualcollector.app.ui.screens.ProfileScreen
import com.manualcollector.app.ui.screens.ScanConfirmScreen
import com.manualcollector.app.ui.screens.ScanScreen

sealed class Dest(val route: String, val labelRes: Int) {
    object Library : Dest("library", R.string.tab_library)
    object Scan : Dest("scan", R.string.tab_scan)
    object Ask : Dest("ask", R.string.tab_ask)
    object Profile : Dest("profile", R.string.tab_profile)

    object LibraryDetail : Dest("library_detail/{manualId}", 0) {
        fun createRoute(manualId: Long) = "library_detail/$manualId"
    }
    object ScanConfirm : Dest("scan_confirm/{pageCount}", 0) {
        fun createRoute(count: Int) = "scan_confirm/$count"
    }
}

private data class TabItem(
    val dest: Dest,
    val icon: androidx.compose.ui.graphics.vector.ImageVector,
)

@Composable
fun AppNavigation() {
    val navController = rememberNavController()
    val tabs = listOf(
        TabItem(Dest.Library, Icons.Filled.MenuBook),
        TabItem(Dest.Scan, Icons.Filled.CameraAlt),
        TabItem(Dest.Ask, Icons.Filled.QuestionAnswer),
        TabItem(Dest.Profile, Icons.Filled.Person),
    )

    val navBackStack by navController.currentBackStackEntryAsState()
    val current = navBackStack?.destination

    Scaffold(
        bottomBar = {
            NavigationBar {
                tabs.forEach { tab ->
                    val selected = current?.hierarchy?.any { it.route == tab.dest.route } == true
                    NavigationBarItem(
                        selected = selected,
                        onClick = {
                            navController.navigate(tab.dest.route) {
                                popUpTo(navController.graph.startDestinationId) { saveState = true }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = { Icon(tab.icon, contentDescription = null) },
                        label = { Text(stringResource(tab.dest.labelRes)) },
                    )
                }
            }
        },
        floatingActionButton = {
            FloatingActionButton(onClick = { navController.navigate(Dest.Scan.route) }) {
                Icon(Icons.Filled.CameraAlt, contentDescription = "扫描")
            }
        },
    ) { paddingValues ->
        NavHost(
            navController = navController,
            startDestination = Dest.Library.route,
            modifier = Modifier.padding(paddingValues),
        ) {
            composable(Dest.Library.route) {
                LibraryScreen { manualId ->
                    navController.navigate(Dest.LibraryDetail.createRoute(manualId))
                }
            }
            composable(Dest.Scan.route) {
                ScanScreen { pageCount ->
                    navController.navigate(Dest.ScanConfirm.createRoute(pageCount))
                }
            }
            composable(Dest.Ask.route) {
                AskScreen()
            }
            composable(Dest.Profile.route) {
                ProfileScreen()
            }
            composable(
                route = Dest.ScanConfirm.route,
                arguments = listOf(navArgument("pageCount") { type = NavType.IntType }),
            ) { entry ->
                val pageCount = entry.arguments?.getInt("pageCount") ?: 1
                ScanConfirmScreen(
                    pageCount = pageCount,
                    onRetake = { navController.popBackStack() },
                    onSave = {
                        navController.popBackStack(Dest.Library.route, inclusive = false)
                    },
                )
            }
            composable(
                route = Dest.LibraryDetail.route,
                arguments = listOf(navArgument("manualId") { type = NavType.LongType }),
            ) { entry ->
                val id = entry.arguments?.getLong("manualId") ?: 0L
                LibraryDetailScreen(manualId = id)
            }
        }
    }
}
