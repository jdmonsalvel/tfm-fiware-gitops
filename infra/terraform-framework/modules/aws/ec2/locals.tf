locals {
  ami_ids = {
    linux          = data.aws_ami.latest_ubuntu_22.id
    windows        = data.aws_ami.latest_windows_server_2022.id
    linux_graviton = data.aws_ami.latest_ubuntu_22_graviton.id
    windows_sql    = data.aws_ami.latest_windows_server_2022_sql_standard.id
  }
}

locals {
  user_data = {
    linux_db = <<EOF
      #!/bin/bash
      # Formatear /dev/sdb como ext4 y montarlo en /opt
      mkfs.ext4 /dev/sdb
      mkdir /opt
      mount /dev/sdb /opt
      echo "/dev/sdb /opt ext4 defaults 0 0" >> /etc/fstab

      # Configurar /dev/sdc como swap
      mkswap /dev/sdc
      swapon /dev/sdc
      echo "/dev/sdc none swap sw 0 0" >> /etc/fstab

      # Formatear /dev/sdd como ext4 y montarlo en /logs
      mkfs.ext4 /dev/sdd
      mkdir /logs
      mount /dev/sdd /logs
      echo "/dev/sdd /logs ext4 defaults 0 0" >> /etc/fstab

      # Formatear /dev/sde como ext4 y montarlo en /data
      mkfs.ext4 /dev/sde
      mkdir /data
      mount /dev/sde /data
      echo "/dev/sde /data ext4 defaults 0 0" >> /etc/fstab
    EOF

    linux = <<EOF
      #!/bin/bash
      # Formatear /dev/sdb como ext4 y montarlo en /opt
      mkfs.ext4 /dev/sdb
      mkdir /opt
      mount /dev/sdb /opt
      echo "/dev/sdb /opt ext4 defaults 0 0" >> /etc/fstab

      # Configurar /dev/sdc como swap
      mkswap /dev/sdc
      swapon /dev/sdc
      echo "/dev/sdc none swap sw 0 0" >> /etc/fstab
    EOF

    windows = <<EOF
    <powershell>
      $disk2 = Get-Disk | Where-Object {$_.IsSystem -eq $False -and $_.IsBoot -eq $False -and $_.PartitionStyle -eq 'RAW'}
      $disk2 | Initialize-Disk -PartitionStyle GPT
      $disk2 | New-Partition -AssignDriveLetter -UseMaximumSize
      $disk2 | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false
      $disk3 = Get-Disk | Where-Object {$_.IsSystem -eq $False -and $_.IsBoot -eq $False -and $_.PartitionStyle -eq 'RAW'}
      $disk3 | Initialize-Disk -PartitionStyle GPT
      $disk3 | New-Partition -AssignDriveLetter -UseMaximumSize
      $disk3 | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Pagefile" -Confirm:$false
      Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'PagingFiles' -Value 'E:\pagefile.sys 1024 2048'
    </powershell>
  EOF

  }
}
locals {
  gaviton_instance_types = data.aws_ec2_instance_types.arm64.instance_types
}
