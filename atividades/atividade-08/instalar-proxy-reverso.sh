#!/bin/bash

# Script de Instalação Automática - Proxy Reverso NGINX
# Execute este script na VM Fedora para configurar tudo automaticamente

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  INSTALAÇÃO PROXY REVERSO NGINX${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Verificar se está rodando como root ou com sudo
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}Este script precisa ser executado com sudo${NC}"
    echo "Execute: sudo ./instalar-proxy-reverso.sh"
    exit 1
fi

# Diretório atual
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${YELLOW}[1/8]${NC} Criando estrutura de diretórios..."
mkdir -p nginx app1 app2 app3
echo -e "${GREEN}✓${NC} Diretórios criados"

echo ""
echo -e "${YELLOW}[2/8]${NC} Criando arquivo de configuração principal do NGINX..."
cat > nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    keepalive_timeout 65;
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    include /etc/nginx/conf.d/*.conf;
}
EOF
echo -e "${GREEN}✓${NC} nginx.conf criado"

echo ""
echo -e "${YELLOW}[3/8]${NC} Criando arquivo de configuração do proxy reverso..."
cat > nginx/default.conf << 'EOF'
# Configuração de Upstream para Balanceamento de Carga
upstream backend_app1 {
    server app1:80;
}

upstream backend_app2 {
    server app2:80;
}

upstream backend_app3 {
    server app3:80;
}

# Servidor Principal - Proxy Reverso
server {
    listen 80;
    server_name localhost;
    
    # Logs específicos
    access_log /var/log/nginx/proxy_access.log main;
    error_log /var/log/nginx/proxy_error.log warn;
    
    # Rota para App1 - Aplicação Web Principal
    location /app1 {
        proxy_pass http://backend_app1/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Rota para App2 - Segunda Aplicação
    location /app2 {
        proxy_pass http://backend_app2/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
    }
    
    # Rota para App3 - Terceira Aplicação (Apache)
    location /app3 {
        proxy_pass http://backend_app3/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Rota padrão - Redireciona para app1
    location / {
        proxy_pass http://backend_app1/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
echo -e "${GREEN}✓${NC} default.conf criado"

echo ""
echo -e "${YELLOW}[4/8]${NC} Criando aplicações de exemplo..."

# App1
cat > app1/index.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>App1 - Aplicação Backend 1</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }
        .container {
            text-align: center;
            background: rgba(255, 255, 255, 0.1);
            padding: 40px;
            border-radius: 15px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
        }
        h1 {
            font-size: 3em;
            margin-bottom: 20px;
        }
        .info {
            background: rgba(255, 255, 255, 0.2);
            padding: 20px;
            border-radius: 10px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 App1</h1>
        <h2>Aplicação Backend 1</h2>
        <div class="info">
            <p><strong>Servidor:</strong> NGINX (Alpine)</p>
            <p><strong>Container:</strong> app1-backend</p>
            <p><strong>Acessado via:</strong> Proxy Reverso NGINX</p>
            <p><strong>Rota:</strong> /app1</p>
            <p><strong>Timestamp:</strong> <span id="time"></span></p>
        </div>
    </div>
    <script>
        document.getElementById('time').textContent = new Date().toLocaleString('pt-BR');
    </script>
</body>
</html>
EOF

# App2
cat > app2/index.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>App2 - Aplicação Backend 2</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            color: white;
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }
        .container {
            text-align: center;
            background: rgba(255, 255, 255, 0.1);
            padding: 40px;
            border-radius: 15px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
        }
        h1 {
            font-size: 3em;
            margin-bottom: 20px;
        }
        .info {
            background: rgba(255, 255, 255, 0.2);
            padding: 20px;
            border-radius: 10px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎯 App2</h1>
        <h2>Aplicação Backend 2</h2>
        <div class="info">
            <p><strong>Servidor:</strong> NGINX (Alpine)</p>
            <p><strong>Container:</strong> app2-backend</p>
            <p><strong>Acessado via:</strong> Proxy Reverso NGINX</p>
            <p><strong>Rota:</strong> /app2</p>
            <p><strong>Timestamp:</strong> <span id="time"></span></p>
        </div>
    </div>
    <script>
        document.getElementById('time').textContent = new Date().toLocaleString('pt-BR');
    </script>
</body>
</html>
EOF

# App3
cat > app3/index.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>App3 - Aplicação Backend 3 (Apache)</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
            color: white;
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }
        .container {
            text-align: center;
            background: rgba(255, 255, 255, 0.1);
            padding: 40px;
            border-radius: 15px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
        }
        h1 {
            font-size: 3em;
            margin-bottom: 20px;
        }
        .info {
            background: rgba(255, 255, 255, 0.2);
            padding: 20px;
            border-radius: 10px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>⚡ App3</h1>
        <h2>Aplicação Backend 3 (Apache)</h2>
        <div class="info">
            <p><strong>Servidor:</strong> Apache HTTP Server</p>
            <p><strong>Container:</strong> app3-backend</p>
            <p><strong>Acessado via:</strong> Proxy Reverso NGINX</p>
            <p><strong>Rota:</strong> /app3</p>
            <p><strong>Timestamp:</strong> <span id="time"></span></p>
        </div>
    </div>
    <script>
        document.getElementById('time').textContent = new Date().toLocaleString('pt-BR');
    </script>
</body>
</html>
EOF

echo -e "${GREEN}✓${NC} Aplicações criadas"

echo ""
echo -e "${YELLOW}[5/8]${NC} Criando docker-compose.yml..."
cat > docker-compose-proxy.yml << 'EOF'
services:
  nginx:
    image: nginx:alpine
    container_name: nginx-proxy
    ports:
      - "80:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - app1
      - app2
      - app3
    networks:
      - proxy-network
    restart: unless-stopped

  app1:
    image: nginx:alpine
    container_name: app1-backend
    volumes:
      - ./app1:/usr/share/nginx/html:ro
    networks:
      - proxy-network
    restart: unless-stopped

  app2:
    image: nginx:alpine
    container_name: app2-backend
    volumes:
      - ./app2:/usr/share/nginx/html:ro
    networks:
      - proxy-network
    restart: unless-stopped

  app3:
    image: httpd:alpine
    container_name: app3-backend
    volumes:
      - ./app3:/usr/local/apache2/htdocs:ro
    networks:
      - proxy-network
    restart: unless-stopped

networks:
  proxy-network:
    driver: bridge
EOF
echo -e "${GREEN}✓${NC} docker-compose-proxy.yml criado"

echo ""
echo -e "${YELLOW}[6/8]${NC} Verificando Docker e Docker Compose..."
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker não está instalado${NC}"
    echo "Instalando Docker..."
    dnf install -y docker docker-compose
    systemctl enable docker
    systemctl start docker
else
    echo -e "${GREEN}✓${NC} Docker instalado"
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}⚠${NC} Docker Compose não encontrado, tentando docker compose..."
fi

echo ""
echo -e "${YELLOW}[7/8]${NC} Subindo containers..."
if docker compose version &> /dev/null; then
    docker compose -f docker-compose-proxy.yml up -d
else
    docker-compose -f docker-compose-proxy.yml up -d
fi

echo ""
echo -e "${YELLOW}[8/8]${NC} Aguardando containers iniciarem..."
sleep 5

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  INSTALAÇÃO CONCLUÍDA!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Verificar status
echo -e "${BLUE}Status dos containers:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "nginx-proxy|app.*-backend|NAMES"

echo ""
echo -e "${BLUE}Testando acesso...${NC}"
echo ""
echo "Teste App1:"
curl -s http://localhost/app1 | grep -o "<title>.*</title>" || echo "Aguardando inicialização..."

echo ""
echo -e "${GREEN}✓${NC} Proxy Reverso NGINX configurado!"
echo ""
echo -e "${YELLOW}Próximos passos:${NC}"
echo "1. Descubra o IP da VM: hostname -I"
echo "2. Acesse no navegador: http://IP_DA_VM/app1"
echo "3. Acesse no navegador: http://IP_DA_VM/app2"
echo "4. Acesse no navegador: http://IP_DA_VM/app3"
echo ""
echo "Para ver os logs: docker logs nginx-proxy"
echo "Para parar: docker-compose -f docker-compose-proxy.yml down"


