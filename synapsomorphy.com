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
    
    # Cache static assets for the main site (not /arc/)
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff2?|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }

    # ARC viz - take precedence over regex locations
    location ^~ /arc/ {
        alias /var/www/arc/viz/dist/;
        index index.html;

        # Serve files if they exist; fallback to index.html for SPA routing
        # Use URI /arc/ so it maps back into this alias and serves index.html
        try_files $uri $uri/ /arc/;
    }

    # ARC API - proxy to backend
    location /arc/api/ {
        proxy_pass http://127.0.0.1:8010;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
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