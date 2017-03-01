class profile::vault {
  include profile::base
  include openssl
  include ssh
  user { "$::training_username":
    home             => "/home/$::training_username",
    password         => "$::namespace",
    password_max_age => '99999',
    password_min_age => '0',
    shell            => '/bin/bash',
    gid              => 'vault',
    require          => Group['vault'],
  }

  user { 'vault':
    ensure           => 'present',
    home             => '/home/vault',
    password         => '!!',
    password_max_age => '99999',
    password_min_age => '0',
    shell            => '/bin/bash',
    gid              => 'vault',
    require          => Group['vault'],
  }

  group { 'vault':
    ensure => 'present',
  }

  file_line { 'sudo_rule':
    path => '/etc/sudoers',
    line => '%vault ALL=(ALL) NOPASSWD: ALL',
  }

  class { '::vault':
    install_method => 'archive',
    download_url   => $::vaulturl,
    backend      => {
      'consul' => {
        'address' => "$::consulserver:8500",
        'path'    => $::storepath,
      }
    },
    listener     => {
      'tcp' => {
        'address'       => '0.0.0.0:8200',
        'tls_disable'   => 0,
        'tls_cert_file' => '/etc/ssl/vault/vault.crt',
        'tls_key_file'  => '/etc/ssl/vault/vault.key',
      }
    },
    notify       => Exec['vault-init'],
    manage_user  => false,
    manage_group => false,
  }

  file { '/etc/ssl/vault':
    ensure => directory,
  }

  openssl::certificate::x509 { 'vault':
    ensure       => present,
    country      => 'GB',
    organization => 'example.com',
    commonname   => $fqdn,
    state        => 'Hertsforshire',
    locality     => 'Bishops Stortford',
    unit         => 'vault',
    altnames     => [$fqdn, 'localhost'],
    email        => 'nicolas@hashicorp.com',
    days         => 3456,
    base_dir     => '/etc/ssl/vault',
    owner        => 'vault',
    group        => 'root',
    force        => false,
    before       => Class['vault'],
    require      => User['vault'],
  }

  class { '::consul':
    config_hash => {
      'data_dir'   => '/opt/consul',
      'datacenter' => 'demo',
      'log_level'  => 'INFO',
      'bind_addr'  => $facts['networking']['interfaces']['eth0']['ip'],
      'node_name'  => $::fqdn,
      'retry_join' => [$::consulserver],
    }
  }

  consul::service { 'vault':
    checks  => [
      {
        script   => 'curl -k https://localhost:8200/v1/sys/seal-status &> /dev/null',
        interval => '10s'
      }
    ],
    port    => 8200,
    tags    => ['production'],
  }
}
