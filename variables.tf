########################################
# Global variables for the platform
########################################

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

########################################
# Supabase configuration (for Lambda env)
########################################

variable "supabase_url" {
  description = "Supabase project URL (e.g. https://xxxxx.supabase.co)"
  type        = string
}

variable "supabase_service_role_key" {
  description = "Supabase service role key (backend only, full access)"
  type        = string
  sensitive   = true
}

########################################
# Stripe configuration (for Lambda env)
########################################

variable "stripe_secret_key" {
  description = "Stripe Secret API key (test or live, depending on env)"
  type        = string
  sensitive   = true
}

variable "stripe_webhook_secret" {
  description = "Stripe webhook signing secret used to verify incoming webhook signatures"
  type        = string
  sensitive   = true
}
