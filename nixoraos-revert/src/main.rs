use libc;
use serde::Deserialize;
use std::io::{self, Write};
use std::process::{Command, exit};

#[derive(Debug)]
struct Deployment {
    id: String,
    version: String,
    date: String,
    is_booted: bool,
}

fn main() {
    require_root();

    let deployments = get_deployments();

    if deployments.is_empty() {
        eprintln!("No deployments found.");
        exit(1);
    }

    println!();
    println!("=== NixoraOS Revert Tool ===");
    println!();

    let mut menu: Vec<(String, String)> = Vec::new();

    // Latest
    let latest = &deployments[0];
    menu.push(("NixoraOS Latest".to_string(), latest.id.clone()));

    // Stable
    if deployments.len() > 1 {
        let stable = &deployments[1];
        menu.push(("NixoraOS Stable".to_string(), stable.id.clone()));
    }

    // Last Used
    if let Some(last) = deployments.iter().find(|d| d.is_booted) {
        menu.push(("NixoraOS Last Used".to_string(), last.id.clone()));
    }

    for (i, (label, _)) in menu.iter().enumerate() {
        println!("{}. {}", i + 1, label);
    }

    println!("----------------------------");
    println!("Old Versions");

    let base_index = menu.len();

    for (i, dep) in deployments.iter().enumerate() {
        println!(
            "{}. {} ({})",
            base_index + i + 1,
            dep.version,
            dep.date
        );

        menu.push((
            format!("{} ({})", dep.version, dep.date),
            dep.id.clone(),
        ));
    }

    println!();
    print!("Select version to boot into: ");
    io::stdout().flush().unwrap();

    let mut input = String::new();
    io::stdin().read_line(&mut input).unwrap();

    let selection: usize = match input.trim().parse() {
        Ok(n) => n,
        Err(_) => {
            eprintln!("Invalid selection.");
            exit(1);
        }
    };

    if selection == 0 || selection > menu.len() {
        eprintln!("Selection out of range.");
        exit(1);
    }

    let chosen = &menu[selection - 1];

    println!();
    println!("You selected: {}", chosen.0);
    print!("Proceed with revert? (y/N): ");
    io::stdout().flush().unwrap();

    let mut confirm = String::new();
    io::stdin().read_line(&mut confirm).unwrap();

    if confirm.trim().to_lowercase() != "y" {
        println!("Cancelled.");
        return;
    }

    set_boot_target(&chosen.1);

    println!("Boot target updated.");
    println!("Rebooting into selected version...");

    Command::new("reboot")
        .status()
        .expect("Failed to reboot");
}

fn require_root() {
    if unsafe { libc::geteuid() } != 0 {
        eprintln!("This tool must be run as root.");
        exit(1);
    }
}

fn set_boot_target(deployment_id: &str) {
    let status = Command::new("rpm-ostree")
        .args(["deploy", deployment_id])
        .status()
        .expect("Failed to set boot target");

    if !status.success() {
        eprintln!("Failed to deploy selected version.");
        exit(1);
    }
}

fn get_deployments() -> Vec<Deployment> {
    let output = Command::new("rpm-ostree")
        .args(["status", "--json"])
        .output()
        .expect("Failed to run rpm-ostree status");

    if !output.status.success() {
        return Vec::new();
    }

    let json = String::from_utf8_lossy(&output.stdout);

    #[derive(Deserialize)]
    struct Status {
        deployments: Vec<RpmDeployment>,
    }

    #[derive(Deserialize)]
    struct RpmDeployment {
        id: String,
        #[serde(default)]
        version: Option<String>,
        booted: bool,
        #[serde(default)]
        timestamp: Option<u64>,
    }

    let parsed: Status =
        serde_json::from_str(&json).unwrap_or(Status { deployments: Vec::new() });

    parsed.deployments
        .into_iter()
        .map(|d| {
            let version = d.version.unwrap_or_else(|| "Unknown Version".to_string());

            let date = if let Some(ts) = d.timestamp {
                use chrono::{TimeZone, Utc};
                match Utc.timestamp_opt(ts as i64, 0).single() {
                    Some(dt) => dt.format("%Y-%m-%d").to_string(),
                    None => "Unknown Date".to_string(),
                }
            } else {
                "Unknown Date".to_string()
            };

            Deployment {
                id: d.id,
                version,
                date,
                is_booted: d.booted,
            }
        })
        .collect()
}