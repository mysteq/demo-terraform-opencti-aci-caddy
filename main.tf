locals {
  name           = "opencti"
  environment    = "dev"
  location       = "westeurope"
  location_short = "westeu"
  rotation_days  = 30
}

resource "random_id" "pad" {
  byte_length = 2
}

resource "azurerm_resource_group" "opencti" {
  name     = "rg-${local.name}-${local.environment}-${local.location_short}"
  location = local.location
}

data "azurerm_client_config" "current" {}

data "azuread_client_config" "current" {}

resource "azuread_application" "opencti" {
  display_name = "Landing Zone - Microsoft Sentinel Managed Service - OpenCTI"
  feature_tags {
    enterprise = true
    gallery    = false
    hide       = true
  }

  web {
    redirect_uris = [
      "https://${local.name}-${local.environment}-${random_id.pad.hex}.westeurope.azurecontainer.io/auth/oic/callback",
      "https://opencti-dev.4t2.no/auth/oic/callback",
    ]
    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = false
    }
  }

  sign_in_audience = "AzureADMyOrg"
  owners = [
    data.azuread_client_config.current.object_id
  ]

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }

  }
}

resource "azurerm_key_vault" "opencti" {
  name                        = "kv-${local.name}-${local.environment}-${local.location_short}"
  location                    = azurerm_resource_group.opencti.location
  resource_group_name         = azurerm_resource_group.opencti.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Create",
      "Delete",
      "Get",
      "Purge",
      "Recover",
      "Update",
      "GetRotationPolicy",
      "SetRotationPolicy",
      "Encrypt",
      "Decrypt",
      "List"
    ]

    secret_permissions = [
      "Set",
      "Get",
      "Delete",
      "Purge",
      "Recover",
      "List"
    ]

    storage_permissions = [
      "Get",
    ]
  }
}

resource "time_rotating" "schedule" {
  rotation_days = local.rotation_days
}

resource "azuread_application_password" "key" {
  display_name          = "Key Vault '${azurerm_key_vault.opencti.name}' in subscriptionid '${data.azurerm_client_config.current.subscription_id}'"
  application_object_id = azuread_application.opencti.object_id
  end_date_relative     = "${local.rotation_days * 24}h"
  rotate_when_changed = {
    rotation = time_rotating.schedule.id
  }
}

resource "azurerm_key_vault_secret" "clientid" {
  name         = "OpenCTI-client-id"
  value        = azuread_application.opencti.application_id
  key_vault_id = azurerm_key_vault.opencti.id
}

resource "azurerm_key_vault_secret" "clientsecret" {
  name         = "OpenCTI-client-secret"
  value        = azuread_application_password.key.value
  key_vault_id = azurerm_key_vault.opencti.id
}

resource "azurerm_storage_account" "opencti" {
  name                             = "st${local.name}${local.environment}${local.location_short}${random_id.pad.hex}"
  resource_group_name              = azurerm_resource_group.opencti.name
  location                         = azurerm_resource_group.opencti.location
  account_tier                     = "Standard"
  account_replication_type         = "LRS"
  enable_https_traffic_only        = true
  allow_nested_items_to_be_public  = false
  min_tls_version                  = "TLS1_2"
  cross_tenant_replication_enabled = false
}

resource "azurerm_storage_share" "opencti_caddy" {
  name                 = "aci-caddy-data"
  storage_account_name = azurerm_storage_account.opencti.name
  quota                = 50
}

resource "azurerm_storage_share" "opencti_redis" {
  name                 = "aci-redis-data"
  storage_account_name = azurerm_storage_account.opencti.name
  quota                = 50
}

resource "azurerm_storage_share" "opencti_es" {
  name                 = "aci-es-data"
  storage_account_name = azurerm_storage_account.opencti.name
  quota                = 50
}

resource "azurerm_storage_share" "opencti_minio" {
  name                 = "aci-minio-data"
  storage_account_name = azurerm_storage_account.opencti.name
  quota                = 50
}

resource "azurerm_storage_share" "opencti_rabbitmq" {
  name                 = "aci-rabbitmq-data"
  storage_account_name = azurerm_storage_account.opencti.name
  quota                = 50
}

resource "random_uuid" "opencti_token" {
}

resource "random_password" "erlang_cookie" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_uuid" "minio_root_user" {
}

resource "random_password" "minio_root_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_key_vault_secret" "minio_root_user" {
  name         = "minio-root-user"
  value        = random_uuid.minio_root_user.result
  key_vault_id = azurerm_key_vault.opencti.id
}

resource "azurerm_key_vault_secret" "minio_root_password" {
  name         = "minio-root-password"
  value        = random_password.minio_root_password.result
  key_vault_id = azurerm_key_vault.opencti.id
}

resource "random_uuid" "rabbitmq_default_user" {
}

resource "random_password" "rabbitmq_default_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "opencti_admin_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_key_vault_secret" "rabbitmq_default_user" {
  name         = "rabbitmq-default-user"
  value        = random_uuid.rabbitmq_default_user.result
  key_vault_id = azurerm_key_vault.opencti.id
}

resource "azurerm_key_vault_secret" "rabbitmq_default_password" {
  name         = "rabbitmq-default-password"
  value        = random_password.rabbitmq_default_password.result
  key_vault_id = azurerm_key_vault.opencti.id
}

resource "azurerm_key_vault_secret" "erlang_cookie" {
  name         = "erlang-cookie"
  value        = random_password.erlang_cookie.result
  key_vault_id = azurerm_key_vault.opencti.id
}

resource "azurerm_key_vault_secret" "opencti_token" {
  name         = "opencti-token"
  value        = random_uuid.opencti_token.result
  key_vault_id = azurerm_key_vault.opencti.id
}

resource "azurerm_key_vault_secret" "opencti_admin_password" {
  name         = "opencti-admin-password"
  value        = random_password.opencti_admin_password.result
  key_vault_id = azurerm_key_vault.opencti.id
}

resource "random_uuid" "connector_id_alienvault" {
}

resource "random_uuid" "connector_id_opencti" {
}

resource "time_offset" "opencti" {
  offset_days = -30
}

resource "azurerm_container_group" "opencti" {
  name                = "cg-${local.name}-${local.environment}-${local.location}"
  resource_group_name = azurerm_resource_group.opencti.name
  location            = azurerm_resource_group.opencti.location
  ip_address_type     = "Public"
  dns_name_label      = "${local.name}-${local.environment}-${random_id.pad.hex}"
  os_type             = "Linux"
  restart_policy      = "Always"

  exposed_port {
    port     = 443
    protocol = "TCP"
  }

  exposed_port {
    port     = 80
    protocol = "TCP"
  }

  container {
    name         = "caddy"
    image        = "caddy"
    cpu          = "0.1"
    memory       = "0.2"
    cpu_limit    = "0.2"
    memory_limit = "0.2"

    ports {
      port     = 443
      protocol = "TCP"
    }

    ports {
      port     = 80
      protocol = "TCP"
    }

    volume {
      name                 = "aci-caddy-data"
      mount_path           = "/data"
      storage_account_name = azurerm_storage_account.opencti.name
      storage_account_key  = azurerm_storage_account.opencti.primary_access_key
      share_name           = azurerm_storage_share.opencti_caddy.name
    }

    commands = ["caddy", "reverse-proxy", "--from", "${local.name}-${local.environment}-${random_id.pad.hex}.westeurope.azurecontainer.io", "--to", "localhost:8080"]
  }

  container {
    name         = "redis"
    image        = "redis:7.0.11"
    cpu          = "0.1"
    cpu_limit    = "0.1"
    memory       = "0.4"
    memory_limit = "0.4"

    volume {
      name                 = "aci-redis-data"
      mount_path           = "/data"
      storage_account_name = azurerm_storage_account.opencti.name
      storage_account_key  = azurerm_storage_account.opencti.primary_access_key
      share_name           = azurerm_storage_share.opencti_redis.name
    }
  }

  container {
    name         = "elasticsearch"
    image        = "docker.elastic.co/elasticsearch/elasticsearch:8.8.0"
    cpu          = "1"
    cpu_limit    = "1"
    memory       = "4"
    memory_limit = "4"

    environment_variables = {
      "ES_SETTING_DISCOVERY_TYPE"         = "single-node",
      "ES_SETTING_xpack_security_enabled" = "false",
      "ES_SETTING_xpack_ml_enabled"       = "false",
      "ES_JAVA_OPTS"                      = "-Xms3g -Xmx3g",
    }

    volume {
      name                 = "aci-es-data"
      mount_path           = "/usr/share/elasticsearch/data"
      storage_account_name = azurerm_storage_account.opencti.name
      storage_account_key  = azurerm_storage_account.opencti.primary_access_key
      share_name           = azurerm_storage_share.opencti_es.name
    }
  }

  container {
    name         = "minio"
    image        = "minio/minio:RELEASE.2023-06-02T23-17-26Z"
    cpu          = "0.1"
    cpu_limit    = "0.1"
    memory       = "0.5"
    memory_limit = "0.5"

    commands = [
      "minio",
      "server",
      "/data",
    ]

    secure_environment_variables = {
      "MINIO_ROOT_USER"     = "${random_uuid.minio_root_user.result}",
      "MINIO_ROOT_PASSWORD" = "${random_password.minio_root_password.result}"
    }

    liveness_probe {
      http_get {
        path   = "/minio/health/live"
        port   = 9000
        scheme = "Http"
      }
      initial_delay_seconds = 10
      period_seconds        = 30
      timeout_seconds       = 20
      success_threshold     = 1
      failure_threshold     = 3
    }

    volume {
      name                 = "aci-minio-data"
      mount_path           = "/data"
      storage_account_name = azurerm_storage_account.opencti.name
      storage_account_key  = azurerm_storage_account.opencti.primary_access_key
      share_name           = azurerm_storage_share.opencti_minio.name
    }
  }

  container {
    name         = "rabbitmq"
    image        = "rabbitmq:3.12-management"
    cpu          = "0.5"
    cpu_limit    = "0.5"
    memory       = "1"
    memory_limit = "1"

    secure_environment_variables = {
      "RABBITMQ_DEFAULT_USER" = "${random_uuid.rabbitmq_default_user.result}",
      "RABBITMQ_DEFAULT_PASS" = "${random_password.rabbitmq_default_password.result}",
    }

    environment_variables = {
      "RABBITMQ_SERVER_ADDITIONAL_ERL_ARGS" = "-setcookie ${random_password.erlang_cookie.result}",
    }

    volume {
      name                 = "aci-rabbitmq-data"
      mount_path           = "/var/lib/rabbitmq"
      storage_account_name = azurerm_storage_account.opencti.name
      storage_account_key  = azurerm_storage_account.opencti.primary_access_key
      share_name           = azurerm_storage_share.opencti_rabbitmq.name
    }
  }

  container {
    name         = "opencti"
    image        = "opencti/platform:5.7.6"
    cpu          = "0.5"
    cpu_limit    = "1"
    memory       = "1.5"
    memory_limit = "2"

    secure_environment_variables = {
      "MINIO__ACCESS_KEY"                        = "${random_uuid.minio_root_user.result}",
      "MINIO__SECRET_KEY"                        = "${random_password.minio_root_password.result}",
      "RABBITMQ__USERNAME"                       = "${random_uuid.rabbitmq_default_user.result}",
      "RABBITMQ__PASSWORD"                       = "${random_password.rabbitmq_default_password.result}",
      "APP__ADMIN__TOKEN"                        = "${random_uuid.opencti_token.result}",
      "APP__ADMIN__PASSWORD"                     = "${random_password.opencti_admin_password.result}",
      "PROVIDERS__OPENID__CONFIG__ISSUER"        = "https://login.microsoftonline.com/${data.azuread_client_config.current.tenant_id}/v2.0",
      "PROVIDERS__OPENID__CONFIG__CLIENT_ID"     = "${azuread_application.opencti.application_id}",
      "PROVIDERS__OPENID__CONFIG__CLIENT_SECRET" = "${azuread_application_password.key.value}",
      "PROVIDERS__OPENID__CONFIG__REDIRECT_URIS" = "[\"https://${local.name}-${local.environment}-${random_id.pad.hex}.westeurope.azurecontainer.io/auth/oic/callback\"]",
    }

    environment_variables = {
      "NODE_OPTIONS"                     = "--max-old-space-size=8096",
      "APP__PORT"                        = "8080",
      "APP__BASE_URL"                    = "https://${local.name}-${local.environment}-${random_id.pad.hex}.westeurope.azurecontainer.io",
      "APP__ADMIN__EMAIL"                = "admin@opencti.io",
      "APP__APP_LOGS__LOGS_LEVEL"        = "info",
      "REDIS__HOSTNAME"                  = "localhost",
      "REDIS__PORT"                      = "6379",
      "ELASTICSEARCH__URL"               = "http://localhost:9200",
      "MINIO__ENDPOINT"                  = "localhost",
      "MINIO__PORT"                      = "9000",
      "MINIO__USE_SSL"                   = "false",
      "RABBITMQ__HOSTNAME"               = "localhost",
      "RABBITMQ__PORT"                   = "5672",
      "RABBITMQ__PORT_MANAGEMENT"        = "15672",
      "RABBITMQ__MANAGEMENT_SSL"         = "false",
      "SMTP__HOSTNAME"                   = "",
      "SMTP__PORT"                       = "25",
      "PROVIDERS__LOCAL__STRATEGY"       = "LocalStrategy",
      "PROVIDERS__OPENID__STRATEGY"      = "OpenIDConnectStrategy",
      "PROVIDERS__OPENID__CONFIG__LABEL" = "Login with OpenID",
    }
  }

  container {
    name         = "worker1"
    image        = "opencti/worker:5.7.6"
    cpu          = "0.2"
    cpu_limit    = "0.2"
    memory       = "0.2"
    memory_limit = "0.2"

    secure_environment_variables = {
      "OPENCTI_TOKEN" = "${random_uuid.opencti_token.result}",
    }

    environment_variables = {
      "OPENCTI_URL"      = "http://localhost:8080",
      "WORKER_LOG_LEVEL" = "info",
    }
  }

  container {
    name         = "worker2"
    image        = "opencti/worker:5.7.6"
    cpu          = "0.2"
    cpu_limit    = "0.2"
    memory       = "0.2"
    memory_limit = "0.2"

    secure_environment_variables = {
      "OPENCTI_TOKEN" = "${random_uuid.opencti_token.result}",
    }

    environment_variables = {
      "OPENCTI_URL"      = "http://localhost:8080",
      "WORKER_LOG_LEVEL" = "info",
    }
  }

  container {
    name         = "worker3"
    image        = "opencti/worker:5.7.6"
    cpu          = "0.2"
    cpu_limit    = "0.2"
    memory       = "0.2"
    memory_limit = "0.2"

    secure_environment_variables = {
      "OPENCTI_TOKEN" = "${random_uuid.opencti_token.result}",
    }

    environment_variables = {
      "OPENCTI_URL"      = "http://localhost:8080",
      "WORKER_LOG_LEVEL" = "info",
    }
  }

  container {
    name         = "connector-alientvault"
    image        = "opencti/connector-alienvault:5.7.6"
    cpu          = "0.1"
    cpu_limit    = "0.2"
    memory       = "0.2"
    memory_limit = "0.5"

    secure_environment_variables = {
      "OPENCTI_TOKEN"      = "${random_uuid.opencti_token.result}",
      "ALIENVAULT_API_KEY" = "${var.alienvault_api_key}"
    }

    environment_variables = {
      "OPENCTI_URL"                                 = "http://localhost:8080",
      "CONNECTOR_ID"                                = "${random_uuid.connector_id_alienvault.result}",
      "CONNECTOR_TYPE"                              = "EXTERNAL_IMPORT",
      "CONNECTOR_NAME"                              = "AlienVault",
      "CONNECTOR_SCOPE"                             = "alienvault",
      "CONNECTOR_CONFIDENCE_LEVEL"                  = "15",
      "CONNECTOR_UPDATE_EXISTING_DATA"              = "false",
      "CONNECTOR_LOG_LEVEL"                         = "info",
      "ALIENVAULT_BASE_URL"                         = "https://otx.alienvault.com",
      "ALIENVAULT_TLP"                              = "White",
      "ALIENVAULT_CREATE_OBSERVABLES"               = "true",
      "ALIENVAULT_CREATE_INDICATORS"                = "true",
      "ALIENVAULT_PULSE_START_TIMESTAMP"            = "${replace(time_offset.opencti.rfc3339, "Z", "")}",
      "ALIENVAULT_REPORT_TYPE"                      = "threat-report",
      "ALIENVAULT_REPORT_STATUS"                    = "New",
      "ALIENVAULT_GUESS_MALWARE"                    = "false",
      "ALIENVAULT_GUESS_CVE"                        = "false",
      "ALIENVAULT_EXCLUDED_PULSE_INDICATOR_TYPES"   = "FileHash-MD5,FileHash-SHA1",
      "ALIENVAULT_ENABLE_RELATIONSHIPS"             = "true",
      "ALIENVAULT_ENABLE_ATTACK_PATTERNS_INDICATES" = "true",
      "ALIENVAULT_INTERVAL_SEC"                     = "1800",
    }
  }

  container {
    name         = "connector-opencti"
    image        = "opencti/connector-opencti:5.7.6"
    cpu          = "0.1"
    cpu_limit    = "0.2"
    memory       = "0.2"
    memory_limit = "0.5"

    secure_environment_variables = {
      "OPENCTI_TOKEN" = "${random_uuid.opencti_token.result}",
    }

    environment_variables = {
      "OPENCTI_URL"                    = "http://localhost:8080",
      "CONNECTOR_ID"                   = "${random_uuid.connector_id_opencti.result}",
      "CONNECTOR_TYPE"                 = "EXTERNAL_IMPORT",
      "CONNECTOR_NAME"                 = "OpenCTI Datasets",
      "CONNECTOR_SCOPE"                = "marking-definition,identity,location",
      "CONNECTOR_CONFIDENCE_LEVEL"     = "90",
      "CONNECTOR_UPDATE_EXISTING_DATA" = "true",
      "CONNECTOR_LOG_LEVEL"            = "info",
      "CONFIG_INTERVAL"                = "7",
      "CONFIG_REMOVE_CREATOR"          = "false",
    }
  }

  tags = {
    environment = local.environment
  }
}

output "opencti_url" {
  value = "https://${azurerm_container_group.opencti.fqdn}"
}
