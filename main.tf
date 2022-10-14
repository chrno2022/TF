terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
  required_version = "~>1.0"
}

provider "azurerm" {
  features {}
  alias           = "PROD"                                     #nickname
  subscription_id = "76107d80-e80f-4230-b61e-de7cf22bda47"     #sub id
  client_id       = "7596bcab-efb4-42c6-a143-96ff1ac0c832"     #app id
  client_secret   = "AVD8Q~fwsuzYgASd6KzNoOWZTp~9ki6yO-sIAdhZ" #password
  tenant_id       = "a4ecced2-809d-4974-a189-2b58258489cc"     #tenant id
}

resource "azurerm_resource_group" "example" { #reference name is unique for each resource type
  provider = azurerm.PROD
  name     = "test-rg"
  location = "westus"
}
resource "azurerm_virtual_network" "example" {
  provider            = azurerm.PROD
  name                = "test-network"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location #referencing arguments of another resource
  address_space       = ["10.0.0.0/8"]
}
resource "azurerm_subnet" "example" {
  provider             = azurerm.PROD
  name                 = "test-subnet"
  virtual_network_name = azurerm_virtual_network.example.name
  resource_group_name  = azurerm_resource_group.example.name
  address_prefixes     = ["10.0.1.0/24"]
}
resource "azurerm_network_interface" "example" {
  provider            = azurerm.PROD
  name                = "vm-nic"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  ip_configuration {
    name                          = "block1"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.example.id
    primary                       = true
  }
}
resource "azurerm_public_ip" "example" {
  provider            = azurerm.PROD
  name                = "vm-public-ip"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  allocation_method   = "Static"
}
resource "azurerm_linux_virtual_machine" "example" {
  provider                        = azurerm.PROD
  name                            = "linux-machine"
  resource_group_name             = azurerm_resource_group.example.name
  location                        = azurerm_resource_group.example.location
  size                            = "Standard_DS2_v2"
  admin_username                  = "adminuser"
  admin_password                  = "ubuntu@1234!"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.example.id,
  ]


  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  provisioner "local-exec" {
    when       = create
    on_failure = continue #avoids tainting of resource
    command    = "echo ${azurerm_linux_virtual_machine.example.name} > vmname.txt"
  }

  provisioner "remote-exec" {
    when       = create
    on_failure = continue
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install nginx -y",
      "sudo systemctl enable nginx --now",
    ]
  }
  provisioner "remote-exec" {
    when       = destroy
    on_failure = continue
    inline = [
      "sudo systemctl stop nginx",
      "sudo apt-get remove nginx -y",
    ]
  }

  provisioner "file" {
    source      = "C:/TFscripts/welcome.sh"
    destination = "/tmp/welcome.sh"
  }
  provisioner "remote-exec" {
    when       = create
    on_failure = continue
    inline = [
      "chmod +x /tmp/welcome.sh",
      "/tmp/welcome.sh",
      "rm /tmp/welcome.sh",
    ]
  }
  connection {
    type     = "ssh"
    user     = self.admin_username
    password = self.admin_password
    host     = self.public_ip_address
  }
}