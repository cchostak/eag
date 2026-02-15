output "global_ip" {
  value = google_compute_global_address.eag.address
}

output "security_policy_id" {
  value = google_compute_security_policy.tailscale_allowlist.id
}
