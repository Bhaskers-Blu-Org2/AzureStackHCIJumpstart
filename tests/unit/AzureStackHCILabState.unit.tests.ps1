Describe 'Host Validation' -Tags Host {
    Context HostOS {
        $NodeOS = Get-CimInstance -ClassName 'Win32_OperatingSystem'

        ### Verify the Host is sufficient version
        #TODO: Can this run on windows 10? - Not without WindowsFeature checking
        It "${env:ComputerName} must be Windows Server 2016, or Server 2019" {
            $NodeOS.Caption | Should be ($NodeOS.Caption -like '*Windows Server 2016*' -or $NodeOS.Caption -like '*Windows Server 2019*')
        }

        It "${env:ComputerName} should have enough memory to cover what's specified in LabConfig" {
            (($LabConfig.VMs.MemoryStartupBytes | Measure-Object -Sum).Sum / 1GB + 2) | Should BeLessThan ((Get-CimInstance -ClassName Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB)
        }

        # Not Implemented until everything gets to the PowerShell Gallery
        $RequiredModules = (Get-Module -Name AzureStackHCIJumpstart).RequiredModules
        $RequiredModules.GetEnumerator() | ForEach-Object {
            $thisModule = $_

            Remove-Variable module -ErrorAction SilentlyContinue
            $module = Get-Module $thisModule.Name -ListAvailable -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1

            It "[TestHost: ${env:ComputerName}] Must have the module [$($thisModule.Name)] available" {
                $module.Name | Should Not BeNullOrEmpty
            }

            It "[TestHost: ${env:ComputerName}] Must be at least version [$($thisModule.Version)]" {
                $module.version -ge $_.ModuleVersion | Should be $true
            }
        }

        $HyperVInstallationState = (Get-WindowsFeature | Where-Object Name -like *Hyper-V* -ErrorAction SilentlyContinue)

        $HyperVInstallationState | ForEach-Object {
            It "${env:ComputerName} must have $($_.Name) installed" {
                $_.InstallState | Should be 'Installed'
            }
        }

        It "${env:ComputerName} must have the specified ISO from LabConfig.ServerISOFolder" {
            Test-Path $LabConfig.ServerISOFolder | Should be $true
        }
    }
}

Describe 'Lab Validation' -Tags Lab {
    Context VMs {
        $LabConfig.VMs.Where{$_.Role -eq 'AzureStackHCI'} | ForEach-Object {
            $VMName = "$($LabConfig.Prefix)$($_.VMName)"

            It "Should have the VM: $VMName" {
                Get-VM -VMName $VMName -ErrorAction SilentlyContinue | Should BeOfType 'Microsoft.HyperV.PowerShell.VirtualMachine'
            }
        }
    }
}