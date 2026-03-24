#!/usr/bin/env python3

import os
import sys
import subprocess
import fnmatch

def print_banner():
    print("="*42)
    print("   SEAPATH ISO Builder")
    print("="*42)

def ask_yes_no(prompt):
    """Asks a yes/no question and strictly validates the input."""
    while True:
        choice = input(prompt).strip().lower()
        if choice in ['y', 'yes']:
            return True
        if choice in ['n', 'no', '']:
            return False
        print("Invalid input. Please type 'y' or 'n' (or press Enter for 'n').")

def ask_choice(prompt, options):
    """It display a simple interactive menu and returns the user's choice."""
    while True:
        print(f"\n{prompt}")
        for key, value in options.items():
            print(f"  [{key}] {value}")

        choice = input("Select an option: ").strip()
        if choice in options:
            return choice
        print("Invalid choice. Please try again.")

def find_iso(os_type):
    """This searches for .iso files in the current directory based on keywords"""
    # Lists all .iso files in the current directory
    available_isos = [f for f in os.listdir('.') if f.lower().endswith('.iso')]
    matching_isos = []

    for iso in available_isos:
        iso_lower = iso.lower()
        if os_type == 'rhel':
            # Search for rhel and 9. Ignore the 'boot' ISOs (they are too small, we need the DVD)
            if fnmatch.fnmatch(iso_lower, 'rhel-9*.iso') and not fnmatch.fnmatch(iso_lower, '*boot*.iso'):
                matching_isos.append(iso)
        elif os_type == 'centos':
            # Search for centos, stream and 9
            if fnmatch.fnmatch(iso_lower, '*centos*stream*9*.iso') or fnmatch.fnmatch(iso_lower, 'c9s*.iso'):
                matching_isos.append(iso)

    # First scenario - No ISO found
    if not matching_isos:
        print(f"\n[-] ERROR: No suitable ISO found for {os_type.upper()} in the current directory.")
        if os_type == 'rhel':
            print("    Expected an ISO for RHEL 9 (e.g., rhel-9.x-x86_64-dvd.iso)")
        else:
            print("    Expected an ISO for CentOS 9")
        sys.exit(1)

    # Second scenario: ISO found
    if len(matching_isos) == 1:
        return matching_isos[0]

    # Third scenario: Multiple ISOs found (creates a dynamic menu)
    print(f"\n[!] Multiple {os_type.upper()} ISOs found:")
    options = {str(i+1): iso for i, iso in enumerate(matching_isos)}
    choice = ask_choice("Which ISO do you want to use?", options)
    return options[choice]

def get_ssh_key():
    """Reads the user's public SSH key from the host machine."""
    ssh_dir = os.path.expanduser("~/.ssh")
    if os.path.exists(ssh_dir):
        for f in os.listdir(ssh_dir):
            if f.endswith(".pub"):
                with open(os.path.join(ssh_dir, f), 'r') as key_file:
                    return key_file.read().strip()
    return ""

def validate_environment(config):
    """Validates RHSM credentials and seeks ISO certification."""
    print("\n[+] Validating environment...")

    # This validates RHSM credentials (Only RHEL)
    if config['os'] == 'rhel':
        config['org_id'] = os.environ.get("ORG_ID")
        config['act_key'] = os.environ.get("ACTIVATION_KEY")

        if not config['org_id'] or not config['act_key']:
            print("[-] ERROR: RHEL deployment requires ORG_ID and ACTIVATION_KEY environment variables.")
            print("    Please export them (e.g., export ORG_ID='...') and run the script again.")
            sys.exit(1)
        print("  -> RHSM Credentials found.")

    # validates and finds the ISO dynamically
    iso_name = find_iso(config['os'])
    print(f"  -> Found and selected ISO: {iso_name}")

    config['ssh_key'] = get_ssh_key()
    if config['ssh_key']:
         print("  -> SSH Public Key found.")
    else:
         print("  -> WARNING: No SSH Public Key found in ~/.ssh/*.pub. Key injection will be empty.")

    print("[+] Environment is valid!")
    return iso_name

def execute_build(config):
    """Orchestrates the execution of the Podman by injecting the dynamic variables."""
    print("\n" + "="*42)
    print("[+] PHASE 2: Container Build & ISO Generation")
    print("="*42)

    container_tag = f"{config['os']}4seapath"

    print(f"\n[*] Building container image '{container_tag}'...")

    if config['os'] == 'rhel':
        build_cmd = [
            "sudo", "env",
            f"ORG_ID={config['org_id']}",
            f"ACTIVATION_KEY={config['act_key']}",
            "podman", "build", "-t", container_tag,
            "--build-arg", "OS_TYPE=rhel",
            "--build-arg", "BASE_IMAGE=registry.access.redhat.com/ubi9/ubi:latest",
            "--secret", "id=org_id,type=env,env=ORG_ID",
            "--secret", "id=act_key,type=env,env=ACTIVATION_KEY"
        ]
    else:
        build_cmd = [
            "sudo", "podman", "build", "-t", container_tag,
            "--build-arg", "OS_TYPE=centos",
            "--build-arg", "BASE_IMAGE=quay.io/centos/centos:stream9"
        ]

    build_cmd.extend(["-f", "container/Containerfile", "."])

    try:
        subprocess.run(build_cmd, check=True)
    except subprocess.CalledProcessError as e:
        print(f"\n[-] ERROR: Failed to build the Podman container. (Exit code: {e.returncode})")
        print(f"    Command: {' '.join(e.cmd)}")
        sys.exit(1)

    # Creation of the ISO
    print("\n[*] Starting ISO generation process...")
    run_cmd = [
        "sudo", "podman", "run", "--privileged", "--rm",
        "--security-opt", "label=disable",
        "-v", "/dev:/dev",
        "-v", f"{os.getcwd()}:/build:Z",
        "-w", "/build",
        "-e", f"BASE_ISO={config['iso_file']}",
        "-e", f"DEPLOY_ENV={config['env']}",
        "-e", f"OS_TYPE={config['os']}",
        "-e", f"TARGET_DISK={config['disk']}",
        "-e", f"INTERFACE={config['net_iface']}",
        "-e", f"SSH_PUB_KEY={config['ssh_key']}"
    ]

    if config['os'] == 'rhel':
        run_cmd.extend([
            "-e", f"ORG_ID={config['org_id']}",
            "-e", f"ACTIVATION_KEY={config['act_key']}"
        ])

    run_cmd.extend(["-it", container_tag, "bash", "scripts/create_vm_isos.sh"])

    try:
        subprocess.run(run_cmd, check=True)
        print("\n[+] SUCCESS: SEAPATH ISOs successfully generated!")
    except subprocess.CalledProcessError as e:
        print(f"\n[-] ERROR: ISO generation script failed inside the container. (Exit code: {e.returncode})")
        print(f"    Command: {' '.join(e.cmd)}")
        sys.exit(1)

def deploy_infrastructure(config):
    """Handles Phase 3: Libvirt Network and VM Deployment."""
    if config['env'] != 'vm':
        return

    print("\n" + "="*42)
    print("[+] PHASE 3: Virtual Machine Infrastructure")
    print("="*42)
    
    try:
        if ask_yes_no("\nDo you want to configure the Libvirt Network (Host Bridges)? [y/N]: "):
            print("[*] Running network preparation...")
            subprocess.run(["bash", "scripts/prepare_vm_host.sh"], check=True)
        
        if ask_yes_no("\nDo you want to deploy the VMs (Libvirt Domains)? [y/N]: "):
            cluster_flag = "--cluster" if ask_yes_no("Deploy as a 3-Node Cluster? [y/N]: ") else ""
            
            print("[*] Running VM deployment...")
            deploy_cmd = ["bash", "scripts/deploy_node.sh"]
            if cluster_flag:
                deploy_cmd.append(cluster_flag)
                
            subprocess.run(deploy_cmd, check=True)
            
        print("\n[+] Infrastructure phase completed!")
        
    except subprocess.CalledProcessError as e:
        print(f"\n[-] ERROR: Infrastructure deployment failed. (Exit code: {e.returncode})")
        sys.exit(1)

def main():
    print_banner()

    config = {}

    os_choice = ask_choice(
        "Which Operating System do you want to build?",
        {"1": "Red Hat Enterprise Linux 9 (RHEL)", "2": "CentOS Stream 9"}
    )
    config['os'] = 'rhel' if os_choice == "1" else 'centos'

    deploy_choice = ask_choice(
        "What is the target deployment environment?",
        {"1": "Virtual Machines (Libvirt Cluster)", "2": "Bare Metal (Physical Servers)"}
    )
    config['env'] = 'vm' if deploy_choice == "1" else 'baremetal'

    # Dynamic Disk and Interface configuration
    default_disk = "sda"
    user_disk = input(f"\nEnter the target installation disk [{default_disk}]: ").strip()
    config['disk'] = user_disk if user_disk else default_disk

    default_iface = "enp1s0" if config['env'] == "vm" else "eno1"
    user_iface = input(f"Enter the primary network interface [{default_iface}]: ").strip()
    config['net_iface'] = user_iface if user_iface else default_iface

    config['iso_file'] = validate_environment(config)

    print("\n[+] Ready to build!")
    print(f"    OS: {config['os'].upper()}")
    print(f"    Target: {config['env'].upper()}")
    print(f"    Base ISO: {config['iso_file']}")
    print(f"    Installation Disk: /dev/{config['disk']}")
    print(f"    Network Interface: {config['net_iface']}")

    should_build = True
    if os.path.exists("isos"):
        existing_isos = [f for f in os.listdir("isos") if f.startswith("seapath-node") and f.endswith(".iso")]
        if existing_isos:
            print("\n[!] Existing generated ISOs found in 'isos/' directory:")
            for f in sorted(existing_isos):
                print(f"    - isos/{f}")
            should_build = ask_yes_no("\nDo you want to rebuild and overwrite these ISOs? [y/N]: ")

    if should_build:
        execute_build(config)
    else:
        print("\n[*] Skipping ISO generation phase. Using existing ISOs.")

    deploy_infrastructure(config)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nExecution cancelled.")
        sys.exit(0)
