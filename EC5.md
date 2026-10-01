# EC5

- Instance: `i-0849256f603a7d056`
- Region: Mumbai (`ap-south-1`)
- OS: Ubuntu Server 24.04 LTS
- Size: `t3.micro` (2 vCPU, 1 GiB RAM), standard CPU credits
- Disk: 8 GiB encrypted gp3; deleted when the instance is terminated
- Initial public IP: `13.201.10.54` (can change after stop/start)
- SSH user: `ubuntu`
- Private key: `.ssh/EC5.pem`
- Security group: `sg-012001cc3f3dd0303`; inbound TCP 22 from `0.0.0.0/0`

From PowerShell in this folder:

```powershell
.\connect-EC5.ps1
```

The script looks up the current address and verifies the SSH host key using the AWS console output. It needs this project's `.env` credentials.

Direct SSH from another computer with a securely copied private key:

```sh
ssh -i EC5.pem ubuntu@13.201.10.54
```

On Linux or macOS, run `chmod 400 EC5.pem` first. The private key is required; password login is disabled. Keep the key private. `.env`, `.ssh/`, and `.aws-local/` are excluded from Git.

AWS usage charges apply for compute, storage, and public IPv4, subject to your account's credits or free tier. Stopping the instance stops compute usage but retains storage charges.

## Python and Java

Connect from PowerShell with `.\connect-EC5.ps1`, then run these commands inside Ubuntu to install Python, pip, virtual environments, and the Java 21 JDK:

```sh
sudo apt update
sudo apt install -y python3 python3-pip python3-venv openjdk-21-jdk-headless
python3 --version
pip3 --version
java -version
javac -version
```

For Python project dependencies, use a virtual environment:

```sh
python3 -m venv ~/myenv
source ~/myenv/bin/activate
```

Use `deactivate` to leave the virtual environment.
