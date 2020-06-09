# Provider 
variable "location" {
  type        = string
  description = "Enter a region"
}
variable "resource_group" {
  type        = string
  description = "Enter the name of the Resource Group"
}
variable "vmpassword" {
  type		    = string
  description	= "Enter the password to login to the Virtual Machine"
}
variable "domain" {
  type		    = string
  description	= "Enter the Domain Name for the ADDC"
}