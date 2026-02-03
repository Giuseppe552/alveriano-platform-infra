########################################
# variables.tf
########################################

########################################
# Global variables for the platform
########################################

variable "environment" {
  description = "Deployment environment (dev, staging, prod). Must match API APP_ENV expectations."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

########################################
# Supabase configuration (for Lambda env)
########################################

variable "supabase_url" {
  description = "Supabase project URL (e.g. https://xxxxx.supabase.co)"
  type        = string

  validation {
    condition     = can(regex("^https://", var.supabase_url))
    error_message = "supabase_url must start with https://"
  }
}

variable "supabase_service_role_key" {
  description = "Supabase service role key (backend only, full access)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.supabase_service_role_key)) > 0
    error_message = "supabase_service_role_key must not be empty."
  }
}

########################################
# Stripe configuration (for Lambda env)
########################################

variable "stripe_secret_key" {
  description = "Stripe Secret API key (test or live, depending on env)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.stripe_secret_key)) > 0
    error_message = "stripe_secret_key must not be empty."
  }
}

variable "stripe_webhook_secret" {
  description = "Stripe webhook signing secret used to verify incoming webhook signatures"
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.stripe_webhook_secret)) > 0
    error_message = "stripe_webhook_secret must not be empty."
  }
}

########################################
# Resinaro CRM sync (platform -> resinaro.com)
########################################

variable "resinaro_crm_webhook_url" {
  description = "Resinaro CRM webhook URL (e.g. https://www.resinaro.com/api/platform/payment-succeeded)"
  type        = string
  default     = ""
}

variable "resinaro_crm_webhook_secret" {
  description = "Shared secret for platform->Resinaro CRM webhook (Bearer token)"
  type        = string
  sensitive   = true
  default     = ""
}
