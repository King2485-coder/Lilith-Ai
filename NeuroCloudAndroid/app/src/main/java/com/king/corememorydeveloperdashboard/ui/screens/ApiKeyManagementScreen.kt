package com.king.corememorydeveloperdashboard.ui.screens
import com.king.corememorydeveloperdashboard.R

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.king.corememorydeveloperdashboard.data.PreferencesManager
import com.king.corememorydeveloperdashboard.model.ApiKey
import com.king.corememorydeveloperdashboard.ui.viewmodels.ApiKeyViewModel
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ApiKeyManagementScreen(
    appId: String,
    prefsManager: PreferencesManager,
    onNavigateBack: () -> Unit,
    viewModel: ApiKeyViewModel = viewModel()
) {
    val userId = prefsManager.getUserId() ?: ""
    val uiState by viewModel.uiState.collectAsState()
    var showCreateDialog by remember { mutableStateOf(false) }
    val clipboardManager = LocalClipboardManager.current

    LaunchedEffect(appId, userId) {
        if (appId.isNotEmpty() && userId.isNotEmpty()) {
            viewModel.loadApiKeys(appId, userId)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("API Keys") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    titleContentColor = MaterialTheme.colorScheme.onSurface
                ),
                actions = {
                    IconButton(onClick = { showCreateDialog = true }) {
                        Icon(Icons.Default.Add, contentDescription = "Create API Key")
                    }
                }
            )
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .background(MaterialTheme.colorScheme.background)
        ) {
            when (val state = uiState) {
                is ApiKeyViewModel.ApiKeyUiState.Loading -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator()
                    }
                }
                is ApiKeyViewModel.ApiKeyUiState.Success -> {
                    if (state.apiKeys.isEmpty()) {
                        EmptyApiKeysState(onCreateClick = { showCreateDialog = true })
                    } else {
                        LazyColumn(
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            items(state.apiKeys) { apiKey ->
                                ApiKeyCard(
                                    apiKey = apiKey,
                                    onCopyClick = { key ->
                                        clipboardManager.setText(AnnotatedString(key))
                                    },
                                    onDeleteClick = { keyId ->
                                        viewModel.deleteApiKey(keyId)
                                    },
                                    onToggleStatus = { keyId, isActive ->
                                        viewModel.toggleApiKeyStatus(keyId, isActive)
                                    }
                                )
                            }
                        }
                    }
                }
                is ApiKeyViewModel.ApiKeyUiState.Error -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = state.message,
                                color = MaterialTheme.colorScheme.error,
                                style = MaterialTheme.typography.bodyMedium
                            )
                            Spacer(modifier = Modifier.height(16.dp))
                            Button(onClick = { viewModel.loadApiKeys(appId, userId) }) {
                                Text("Retry")
                            }
                        }
                    }
                }
            }
        }
    }

    if (showCreateDialog) {
        CreateApiKeyDialog(
            appId = appId,
            userId = userId,
            onDismiss = { showCreateDialog = false },
            onApiKeyCreated = { newApiKey ->
                showCreateDialog = false
                viewModel.loadApiKeys(appId, userId)
                // Show the new API key in a dialog
                clipboardManager.setText(AnnotatedString(newApiKey))
            }
        )
    }
}

@Composable
fun EmptyApiKeysState(onCreateClick: () -> Unit) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                imageVector = Icons.Default.Key,
                contentDescription = null,
                modifier = Modifier.size(64.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = "No API Keys",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = "Create your first API key to start using the CoreMemory API",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(modifier = Modifier.height(24.dp))
            Button(onClick = onCreateClick) {
                Icon(Icons.Default.Add, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text("Create API Key")
            }
        }
    }
}

@Composable
fun ApiKeyCard(
    apiKey: ApiKey,
    onCopyClick: (String) -> Unit,
    onDeleteClick: (String) -> Unit,
    onToggleStatus: (String, Boolean) -> Unit
) {
    var showDeleteDialog by remember { mutableStateOf(false) }
    val dateFormat = SimpleDateFormat("MMM dd, yyyy", Locale.getDefault())

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = apiKey.keyType.uppercase(),
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = "Created: ${apiKey.lastUsedAt ?: "Never used"}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(
                            if (apiKey.isActive) MaterialTheme.colorScheme.primaryContainer
                            else MaterialTheme.colorScheme.errorContainer
                        )
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                ) {
                    Text(
                        text = if (apiKey.isActive) "Active" else "Inactive",
                        style = MaterialTheme.typography.labelSmall,
                        color = if (apiKey.isActive) MaterialTheme.colorScheme.onPrimaryContainer
                        else MaterialTheme.colorScheme.onErrorContainer
                    )
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // API Key Display
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .padding(12.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "${apiKey.keyPrefix}${"*".repeat(32)}",
                    style = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.weight(1f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                IconButton(
                    onClick = { onCopyClick("${apiKey.keyPrefix}${apiKey.keyHash}") }
                ) {
                    Icon(
                        Icons.Default.ContentCopy,
                        contentDescription = "Copy API Key",
                        tint = MaterialTheme.colorScheme.primary
                    )
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Permissions
            if (!apiKey.permissions.isNullOrEmpty()) {
                Text(
                    text = "Permissions:",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(4.dp))
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(apiKey.permissions) { permission ->
                        PermissionChip(permission = permission)
                    }
                }
                Spacer(modifier = Modifier.height(12.dp))
            }

            // Actions
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedButton(
                    onClick = { onToggleStatus(apiKey.id, !apiKey.isActive) },
                    modifier = Modifier.weight(1f)
                ) {
                    Icon(
                        if (apiKey.isActive) Icons.Default.Pause else Icons.Default.PlayArrow,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(if (apiKey.isActive) "Disable" else "Enable")
                }
                
                OutlinedButton(
                    onClick = { showDeleteDialog = true },
                    colors = ButtonDefaults.outlinedButtonColors(
                        contentColor = MaterialTheme.colorScheme.error
                    )
                ) {
                    Icon(
                        Icons.Default.Delete,
                        contentDescription = "Delete",
                        modifier = Modifier.size(16.dp)
                    )
                }
            }
        }
    }

    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = { Text("Delete API Key") },
            text = { Text("Are you sure you want to delete this API key? This action cannot be undone.") },
            confirmButton = {
                Button(
                    onClick = {
                        onDeleteClick(apiKey.id)
                        showDeleteDialog = false
                    },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.error
                    )
                ) {
                    Text("Delete")
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
fun PermissionChip(permission: String) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.secondaryContainer)
            .padding(horizontal = 8.dp, vertical = 4.dp)
    ) {
        Text(
            text = permission,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSecondaryContainer
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateApiKeyDialog(
    appId: String,
    userId: String,
    onDismiss: () -> Unit,
    onApiKeyCreated: (String) -> Unit,
    viewModel: ApiKeyViewModel = viewModel()
) {
    var keyName by remember { mutableStateOf("") }
    var selectedKeyType by remember { mutableStateOf("production") }
    var selectedPermissions by remember { mutableStateOf(setOf<String>()) }
    var expirationDays by remember { mutableStateOf(365) }
    
    val keyTypes = listOf("production", "development", "testing")
    val availablePermissions = listOf(
        "memory:read", "memory:write", "memory:delete",
        "analytics:read", "webhooks:manage"
    )

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Create API Key") },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                OutlinedTextField(
                    value = keyName,
                    onValueChange = { keyName = it },
                    label = { Text("Key Name") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )

                // Key Type Selection
                Text(
                    text = "Key Type",
                    style = MaterialTheme.typography.labelMedium
                )
                keyTypes.forEach { type ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.clickable {
                            selectedKeyType = type
                        }
                    ) {
                        RadioButton(
                            selected = selectedKeyType == type,
                            onClick = { selectedKeyType = type }
                        )
                        Text(
                            text = type.replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.getDefault()) else it.toString() },
                            modifier = Modifier.padding(start = 8.dp)
                        )
                    }
                }

                // Permissions
                Text(
                    text = "Permissions",
                    style = MaterialTheme.typography.labelMedium
                )
                availablePermissions.forEach { permission ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.clickable {
                            selectedPermissions = if (selectedPermissions.contains(permission)) {
                                selectedPermissions - permission
                            } else {
                                selectedPermissions + permission
                            }
                        }
                    ) {
                        Checkbox(
                            checked = selectedPermissions.contains(permission),
                            onCheckedChange = { checked ->
                                selectedPermissions = if (checked) {
                                    selectedPermissions + permission
                                } else {
                                    selectedPermissions - permission
                                }
                            }
                        )
                        Text(
                            text = permission,
                            modifier = Modifier.padding(start = 8.dp)
                        )
                    }
                }

                // Expiration
                OutlinedTextField(
                    value = expirationDays.toString(),
                    onValueChange = { 
                        expirationDays = it.toIntOrNull() ?: 365
                    },
                    label = { Text("Expiration (days)") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    viewModel.createApiKey(
                        appId = appId,
                        userId = userId,
                        keyType = selectedKeyType,
                        permissions = selectedPermissions.toList(),
                        expirationDays = expirationDays
                    ) { newApiKey ->
                        onApiKeyCreated(newApiKey)
                    }
                },
                enabled = keyName.isNotBlank() && selectedPermissions.isNotEmpty()
            ) {
                Text("Create")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}