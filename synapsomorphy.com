# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    
    server_name synapsomorphy.com www.synapsomorphy.com;
    
    return 301 https://synapsomorphy.com$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    
    server_name synapsomorphy.com www.synapsomorphy.com;
    
    root /var/www/synapsomorphy.com;
    index index.html index.htm;
    
    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/synapsomorphy.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/synapsomorphy.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    
    # Enable gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Main location block
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # Cache static assets
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # ARC viz subdomain
    location /arc/ {
        proxy_pass http://127.0.0.1:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Script-Name /arc;
    }
    
    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }
    
    # Redirect www to non-www
    if ($host = www.synapsomorphy.com) {
        return 301 https://synapsomorphy.com$request_uri;
    }
}