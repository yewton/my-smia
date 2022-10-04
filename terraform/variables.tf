variable "encrypt_key" {
  description = "Spring Cloud Config 暗号化用の暗号鍵"
  type        = string
  sensitive   = true
}
variable "db_password" {
  description = "RDS root user password"
  type        = string
  sensitive   = true
}
variable "jwt_signing_key" {
  description = "Spring Security で利用する認証鍵"
  type        = string
  sensitive   = true
}
