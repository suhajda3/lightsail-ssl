# lightsail-ssl
Simple script for setting up Let's Encrypt SSL on AWS Lightsail instances

## Requirements
- Fresh AWS Lightsail Linux installation

- This script was primary written for WordPress instances (Certified by Bitnami and Automattic)

## Arguments

lightsail-ssl.sh [domain] [email]

- [domain] FQDN domain name pointing to the instance where this script is run

- [email] Email address where Let's Encrypt will send notifications when the SSL certificate is expiring

[domain] and [email] arguments are optional if they are not provided the script will ask for them.

## Installation
Connect to your instance using SSH

Run the following command in the terminal. This will download the script and set up Let's Encrypt.

`wget -O - https://raw.githubusercontent.com/suhajda3/lightsail-ssl/main/lightsail-ssl.sh | sudo bash`

## Functions

Functions - in order - that the script does:

1. Update the Linux OS
2. Install / update [lego](https://github.com/go-acme/lego)
3. Request Let's Encrypt certificate
4. Set up automatic Let's Encrypt certificate renewal
5. Display WordPress login credentials

You can run the script as many times as you like to update your system.

## Demo

My blog post [Running WordPress on AWS](https://roadtoaws.com/2021/07/08/running-wordpress-on-aws-the-cheap-and-easy-way/) describes in detail how to use this script.

## Contributing

Feel free to open an issue (or even better, send a Pull Request) to contribute. Contributions are always welcomed! 😄

<a href="https://www.buymeacoffee.com/misi" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png" alt="Buy Me A Coffee" style="height: auto !important;width: auto !important;" ></a>

Please consider donating. 🙏
