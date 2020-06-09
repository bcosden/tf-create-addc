## Configure the Microsoft Azure Provider
# sp name: "azure-cli-2020-03-06-14-52-57"
provider "azurerm" {
    version         = "~> 2.2"
#    tenant_id       = var.tenant_id
#    subscription_id = var.subscription_id
#    client_id       = var.client_id
#    client_secret   = var.client_secret
    features {}
}

terraform {
  backend "azurerm" {
    resource_group_name   = "az-terraform-state"
    storage_account_name  = "tstate27394"
    container_name        = "tsstate"
    key                   = "terraform.tfstate"
  }
}

locals {
    vm_prefix           = "addcVM"
    vm_size             = "Standard_DS1_v2"
    vm_username         = "azureuser"
    vm_publisher        = "MicrosoftWindowsServer"
    vm_offer            = "WindowsServer"
    vm_sku              = "2016-Datacenter"
    vm_version          = "latest"
    vnet_name           = "addc_VNet"
    subnet_addcname     = "subnet_addc"
    subnet_storagename  = "subnet_storage"
    vnet_addrspace      = "10.10.0.0/16"
    subnet_addc         = "10.10.0.0/24"
    subnet_storage      = "10.10.1.0/24"
    subnet_bastion      = "10.10.254.0/27"
    addc_primarystatic  = "10.10.0.4"
    addc_secondstatic   = "10.10.0.5"
    addcsitename        = "Default-First-Site-Name"
    grp_tags            = "ADDC"
    primaryaddcscript   = "https://raw.githubusercontent.com/bcosden/tf-create-addc/master/addcpromotescript.ps1"
    scriptfilename      = "addcpromotescript.ps1"
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "myterraformgroup" {
    name     = var.resource_group
    location = var.location

    tags = {
        environment = local.grp_tags
    }
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = local.vnet_name
    address_space       = [local.vnet_addrspace]
    location            = var.location
    resource_group_name = azurerm_resource_group.myterraformgroup.name

    tags = {
        environment = local.grp_tags
    }
}

# Create subnet ADDC
resource "azurerm_subnet" "myterraformsubnet1" {
    name                 = local.subnet_addcname
    resource_group_name  = azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefixes     = [local.subnet_addc]
}

# Create subnet Strorage
resource "azurerm_subnet" "myterraformsubnet2" {
    name                 = local.subnet_storagename
    resource_group_name  = azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefixes     = [local.subnet_storage]
}

# Create subnet Bastion
resource "azurerm_subnet" "myterraformsubnet3" {
    name                 = "AzureBastionSubnet"
    resource_group_name  = azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefixes     = [local.subnet_bastion]
}

# Create public IP for Bastion
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "AzBastion_pip"
    location                     = var.location
    resource_group_name          = azurerm_resource_group.myterraformgroup.name
    allocation_method            = "Static"
    sku                          = "Standard"

    tags = {
        environment = local.grp_tags
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "ADDC_SecurityNSG"
    location            = var.location
    resource_group_name = azurerm_resource_group.myterraformgroup.name

    tags = {
        environment = local.grp_tags
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.myterraformgroup.name
    }
    
    byte_length = 8
}

# Create primary network interface
resource "azurerm_network_interface" "myterraformnic1" {
    name                      = format("%s01NIC_%s", local.vm_prefix, "${random_id.randomId.hex}")
    location                  = var.location
    resource_group_name       = azurerm_resource_group.myterraformgroup.name
    ip_configuration {
        name                          = "PrimaryNicConfig"
        private_ip_address            = local.addc_primarystatic
        subnet_id                     = azurerm_subnet.myterraformsubnet1.id
        private_ip_address_allocation = "Static"
    }

    tags = {
        environment = local.grp_tags
    }
}

# Create secondary network interface
resource "azurerm_network_interface" "myterraformnic2" {
    name                      = "${local.vm_prefix}NIC_${random_id.randomId.hex}"
    location                  = var.location
    resource_group_name       = azurerm_resource_group.myterraformgroup.name
    ip_configuration {
        name                          = "SecondaryNicConfig"
        private_ip_address            = local.addc_secondstatic
        subnet_id                     = azurerm_subnet.myterraformsubnet1.id
        private_ip_address_allocation = "Static"
    }

    tags = {
        environment = local.grp_tags
    }
}

# NSG association for subnet 1
resource "azurerm_subnet_network_security_group_association" "myterraformnsgassoc1" {
  subnet_id                 = azurerm_subnet.myterraformsubnet1.id
  network_security_group_id = azurerm_network_security_group.myterraformnsg.id
}

# NSG association for subnet 2
resource "azurerm_subnet_network_security_group_association" "myterraformnsgassoc2" {
  subnet_id                 = azurerm_subnet.myterraformsubnet2.id
  network_security_group_id = azurerm_network_security_group.myterraformnsg.id
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.myterraformgroup.name
    location                    = var.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = local.grp_tags
    }
}

resource "azurerm_availability_set" "addcavailset" {
  name                = "ADDC_AvailibilitySet"
  location            = var.location
  resource_group_name = azurerm_resource_group.myterraformgroup.name

  tags = {
    environment = "Production"
  }
}

# Create virtual machine 1
resource "azurerm_windows_virtual_machine" "myterraformvm1" {
    name                  = "${local.vm_prefix}01"
    location              = var.location
    resource_group_name   = azurerm_resource_group.myterraformgroup.name
    network_interface_ids = [azurerm_network_interface.myterraformnic1.id]
    size                  = local.vm_size
    admin_username        = local.vm_username
    admin_password        = var.vmpassword
    availability_set_id   = azurerm_availability_set.addcavailset.id

    os_disk {
        caching              = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = local.vm_publisher
        offer     = local.vm_offer
        sku       = local.vm_sku
        version   = local.vm_version
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = local.grp_tags
    }
}

# Create managed disk for secondary data disk
resource "azurerm_managed_disk" "datavm1" {
  name                 = "${local.vm_prefix}01-disk1-${random_id.randomId.hex}"
  location             = var.location
  resource_group_name  = azurerm_resource_group.myterraformgroup.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 128
}

resource "azurerm_virtual_machine_data_disk_attachment" "attachdatavm1" {
  managed_disk_id    = azurerm_managed_disk.datavm1.id
  virtual_machine_id = azurerm_windows_virtual_machine.myterraformvm1.id
  lun                = "10"
  caching            = "ReadWrite"
}

# Create virtual machine 2
resource "azurerm_windows_virtual_machine" "myterraformvm2" {
    name                  = "${local.vm_prefix}02"
    location              = var.location
    resource_group_name   = azurerm_resource_group.myterraformgroup.name
    network_interface_ids = [azurerm_network_interface.myterraformnic2.id]
    size                  = local.vm_size
    admin_username        = local.vm_username
    admin_password        = var.vmpassword
    availability_set_id   = azurerm_availability_set.addcavailset.id

    os_disk {
        caching              = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = local.vm_publisher
        offer     = local.vm_offer
        sku       = local.vm_sku
        version   = local.vm_version
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = local.grp_tags
    }
}

# Create managed disk for secondary data disk
resource "azurerm_managed_disk" "datavm2" {
  name                 = "${local.vm_prefix}02-disk1-${random_id.randomId.hex}"
  location             = var.location
  resource_group_name  = azurerm_resource_group.myterraformgroup.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 128
}

resource "azurerm_virtual_machine_data_disk_attachment" "attachdatavm2" {
  managed_disk_id    = azurerm_managed_disk.datavm2.id
  virtual_machine_id = azurerm_windows_virtual_machine.myterraformvm2.id
  lun                = "10"
  caching            = "ReadWrite"
}

resource "azurerm_bastion_host" "addchost" {
  name                = "AzBastionSvc"
  location            = var.location
  resource_group_name = azurerm_resource_group.myterraformgroup.name

  ip_configuration {
    name                 = "BastionIPConfig"
    subnet_id            = azurerm_subnet.myterraformsubnet3.id
    public_ip_address_id = azurerm_public_ip.myterraformpublicip.id
  }
}

resource "azurerm_virtual_machine_extension" "promoteaddc" {
  name                  = "VMExtension-ADDC01"
  virtual_machine_id    = azurerm_windows_virtual_machine.myterraformvm1.id
  publisher             = "Microsoft.Compute"
  type                  = "CustomScriptExtension"
  type_handler_version  = "1.9"
  depends_on            = [azurerm_windows_virtual_machine.myterraformvm1, azurerm_virtual_machine_data_disk_attachment.attachdatavm1]
  tags                  = {
        environment = local.grp_tags
    }

  # CustomVMExtension Documetnation: https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-windows
  settings = <<SETTINGS
    {
        "fileUris": ["${local.primaryaddcscript}"]
    }
SETTINGS
  protected_settings = <<PROTECTED_SETTINGS
    {
        "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted -File ${local.scriptfilename} ${local.vm_username} ${var.vmpassword} ${var.domain} ${local.subnet_storage} ${local.addcsitename}"
    }
  PROTECTED_SETTINGS
}

output "user_name" {
    value       = azurerm_windows_virtual_machine.myterraformvm1.admin_username
    description = "Username"
}

