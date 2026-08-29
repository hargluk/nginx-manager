# 🇬🇧 nginx-manager — simple website management on VPS

Interactive bash script for simplified creation, removal, enabling/disabling websites (virtual hosts) in nginx. Additionally, it allows you to install popular web packages, manage SSL certificates via Certbot, control ports with UFW, and configure automatic Certbot hooks. The script installs itself to `/usr/local/bin/nginx-manager` on first run.

---

## 🔥 Features

- ✅ Interactive menu with colored output  
- ✅ Create a website in 30 seconds (static or proxy)  
- ✅ **List all sites** – detects configs even without `.conf` extension  
- ✅ Works with **external sites** (not created by the script) – asks for confirmation before deletion/disable  
- ✅ Remove packages (PHP, MySQL, PostgreSQL, SQLite3, Certbot) with version display  
- ✅ Install packages selectively or all missing with one key  
- ✅ **Full SSL/Certbot management**:  
  - obtain certificate for a domain (with option to add `www`)  
  - renew all certificates  
  - list existing certificates  
  - **interactive mode** `certbot --nginx` – choose domains from a list  
- ✅ **UFW port management**:  
  - install UFW  
  - open/close ports (TCP/UDP)  
  - enable/disable firewall  
- ✅ **Configure Certbot hooks** – automatically open port 80 before running Certbot and close after  
- ✅ **Script info and self-removal** – show version, path, and option to delete the script itself  
- ✅ Check nginx syntax and automatically reload  
- ✅ Self-installation – available as `sudo nginx-manager`

---

## 📦 One‑minute installation

Copy the script to your VPS and run:

```bash
sudo wget -O /usr/local/bin/nginx-manager https://raw.githubusercontent.com/hargluk/nginx-manager/refs/heads/main/nginx-manager-en && sudo chmod +x /usr/local/bin/nginx-manager && sudo nginx-manager

```

On first run, the script will ask to install itself to `/usr/local/bin/nginx-manager`. Confirm – then you can manage sites with a single command:

```bash
sudo nginx-manager
```

> If you decline installation, the script will continue to work but you won’t be able to call it from anywhere.

---

## ⚙️ Requirements

- Ubuntu / Debian (or any other Linux with apt and nginx)
- sudo privileges (root)
- Internet connection for package installation

---

## 📋 Menu

After startup, the main menu appears:

```
======================================
      nginx site management
======================================
1. Create site
2. List all sites
3. Delete site
4. Enable/Disable site
5. Reload nginx
6. Install packages (PHP, MySQL, PostgreSQL, SQLite3, Certbot)
7. SSL certificates (Certbot)
8. Port management (UFW)
9. Configure Certbot hooks (ufw: open/close port 80)
10. Script info and removal
0. Exit
======================================
```

### 1. Create site

- Enter a **short name** (e.g., `mysite`) – it will be used for the folder and config name.
- Enter the **domain** (e.g., `example.com`) – used in `server_name`.
- Choose the **type**:
  - **Static** – plain static site (HTML/CSS/JS).
  - **Proxy** – forwards to a local port (e.g., for a Node.js app on port 3000).
- Automatically:
  - Folder `/var/www/<name>` is created
  - `index.html` is created (if empty)
  - nginx config is generated in `/etc/nginx/sites-available/<name>.conf`
  - Symlink is created in `sites-enabled`
  - Config is tested and nginx reloaded

### 2. List all sites

Shows **all** configs found in `/etc/nginx/sites-available/` (regardless of `.conf` extension).  
For each site it displays:
- Name
- Domain (if extractable from config)
- Label: `[own]` (created by script) or `[external]` (created manually or by other tools)
- Status: `enabled` or `disabled` (checks symlink in `sites-enabled`)

### 3. Delete site

Lists all sites (own and external).  
When you select a site:
- If **own** – config and symlink are removed (folder `/var/www/<name>` is removed on request).
- If **external** – script warns and asks for confirmation before deletion.

### 4. Enable/Disable site

Toggles the symlink in `sites-enabled`.  
For external sites, confirmation is requested.

### 5. Reload nginx

Tests configuration with `nginx -t` and reloads the service.

### 6. Install packages

Displays a list of packages (PHP, MySQL, PostgreSQL, SQLite3, Certbot) with current status and version (if installed).  
You can:
- Enter package numbers separated by space (e.g., `1 3 5`) – to install (if missing) or remove (if already installed, asks for confirmation).
- Press `9` – install all missing packages.
- Press `0` – exit.

After installation/removal, statuses are updated automatically.

### 7. SSL certificates (Certbot)

When entering this submenu, the script checks if Certbot is installed. If not, it offers to install it right away.  
Submenu:

```
1. Obtain certificate for domain (with www)
2. Renew all certificates
3. Show existing certificates
4. Run certbot --nginx (interactive mode)
0. Back
```

- **Item 1** – asks for domain and whether to add `www`. After successful issuance, reloads nginx.
- **Item 2** – runs `certbot renew`.
- **Item 3** – lists active certificates.
- **Item 4** – runs `certbot --nginx` interactively: you can select domains from a list using space and arrows, and also add additional ones.

### 8. Port management (UFW)

Allows managing the UFW firewall. If UFW is not installed – offers to install it.  
Available actions:

- Show status and rules
- Open a port (specify port number and protocol tcp/udp)
- Close a port (remove rule)
- Enable UFW
- Disable UFW
- Back

When opening port 22 (SSH), a rule is added automatically to avoid losing access.

### 9. Configure Certbot hooks (ufw)

Creates or updates `/etc/letsencrypt/cli.ini` with:

```
pre-hook = ufw allow 80/tcp
post-hook = ufw delete allow 80/tcp
```

This allows Certbot to automatically open port 80 before running (if using standalone mode) and close it afterwards.  
Before configuring, the script checks UFW installation and that port 22 is open.

### 10. Script info and removal

Shows:
- Name
- Version (e.g., `5.3`)
- Path to executable
- Author

Offers to remove the script (with confirmation). After removal, the script exits.

---

## 📁 Folder structure created by the script

```
/var/www/
  └── <name>/
      └── index.html

/etc/nginx/
  ├── sites-available/
  │   ├── <name>.conf    (for sites created by script)
  │   └── <name>         (may be without extension if config is external)
  ├── sites-enabled/
  │   └── <name>.conf -> ../sites-available/<name>.conf
  └── .my_sites          (file with list of names created by script)
```

> The script now works correctly with configs both with and without `.conf` extension.

---

## 📝 Example configurations

### Static

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;
    root /var/www/mysite;
    index index.html index.htm index.php;
    location / {
        try_files $uri $uri/ =404;
    }
}
```

### Proxy

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name api.example.com www.api.example.com;
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## 🔒 Security

- All operations require `sudo`.
- The script will not delete or toggle an external site without additional confirmation.
- When deleting a site, the folder `/var/www/<name>` is removed only after explicit consent.
- The script does not modify other web server configurations.
- Enabling UFW always opens port 22 (SSH) by default to avoid losing access.

---

## 🗑️ Removing the script

If you no longer need `nginx-manager`, run:

```bash
sudo rm /usr/local/bin/nginx-manager
```

Or choose menu item **10** and confirm removal.

Created sites and configs will remain untouched.

---

## 📄 License

MIT. Use as you like.

---

## 🌐 Links

- [GitHub repository](https://github.com/hargluk/nginx-manager)
- Report issues: [Issues](https://github.com/hargluk/nginx-manager/issues)

---

**Enjoy!** 🚀
