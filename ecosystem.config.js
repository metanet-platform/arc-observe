module.exports = {
  apps: [
    {
      name: 'nats-server',
      script: '/usr/local/bin/nats-server',
      args: '-js -p 4222 -m 8222',
      cwd: '/root/arc-observe',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '500M',
      error_file: './logs/nats-error.log',
      out_file: './logs/nats-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true
    },
    {
      name: 'arc-blocktx',
      script: './arc',
      args: '-config=config_production.yaml -k8s-watcher=false -blocktx',
      cwd: '/root/arc-observe',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '2G',
      env: {
        NODE_ENV: 'production'
      },
      error_file: './logs/blocktx-error.log',
      out_file: './logs/blocktx-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true
    },
    {
      name: 'arc-metamorph',
      script: './arc',
      args: '-config=config_production.yaml -k8s-watcher=false -metamorph',
      cwd: '/root/arc-observe',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '2G',
      env: {
        NODE_ENV: 'production'
      },
      error_file: './logs/metamorph-error.log',
      out_file: './logs/metamorph-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true
    },
    {
      name: 'arc-callbacker',
      script: './arc',
      args: '-config=config_production.yaml -k8s-watcher=false -callbacker',
      cwd: '/root/arc-observe',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
      env: {
        NODE_ENV: 'production'
      },
      error_file: './logs/callbacker-error.log',
      out_file: './logs/callbacker-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true
    },
    {
      name: 'arc-api',
      script: './arc',
      args: '-config=config_production.yaml -k8s-watcher=false -api',
      cwd: '/root/arc-observe',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
      env: {
        NODE_ENV: 'production'
      },
      error_file: './logs/api-error.log',
      out_file: './logs/api-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true
    }
  ]
};
