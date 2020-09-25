variable "token_expiration" {
  type        = number
  description = "token expiration in minutes"
  default     = 180
}

variable "docs_bucket_name"{
    type=string
    default="af-upload-docs"
}