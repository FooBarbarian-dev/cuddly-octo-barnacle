alias Clio.Repo
alias Clio.Tags.Tag

now = DateTime.utc_now()

tags = [
  # MITRE ATT&CK Technique tags (13)
  %{name: "reconnaissance", color: "#EF4444", category: "technique", description: "Initial reconnaissance activities", is_default: true, created_by: "system"},
  %{name: "resource-development", color: "#EF4444", category: "technique", description: "Resource development activities", is_default: true, created_by: "system"},
  %{name: "initial-access", color: "#EF4444", category: "technique", description: "Initial access to target", is_default: true, created_by: "system"},
  %{name: "execution", color: "#EF4444", category: "technique", description: "Code execution on target", is_default: true, created_by: "system"},
  %{name: "persistence", color: "#EF4444", category: "technique", description: "Maintaining access", is_default: true, created_by: "system"},
  %{name: "privilege-escalation", color: "#EF4444", category: "technique", description: "Gaining elevated privileges", is_default: true, created_by: "system"},
  %{name: "defense-evasion", color: "#EF4444", category: "technique", description: "Avoiding detection", is_default: true, created_by: "system"},
  %{name: "credential-access", color: "#EF4444", category: "technique", description: "Credential harvesting", is_default: true, created_by: "system"},
  %{name: "discovery", color: "#EF4444", category: "technique", description: "Environment discovery", is_default: true, created_by: "system"},
  %{name: "lateral-movement", color: "#EF4444", category: "technique", description: "Moving within network", is_default: true, created_by: "system"},
  %{name: "collection", color: "#EF4444", category: "technique", description: "Data collection", is_default: true, created_by: "system"},
  %{name: "exfiltration", color: "#EF4444", category: "technique", description: "Data exfiltration", is_default: true, created_by: "system"},
  %{name: "command-and-control", color: "#EF4444", category: "technique", description: "C2 communication", is_default: true, created_by: "system"},

  # Tool tags (15)
  %{name: "mimikatz", color: "#F59E0B", category: "tool", description: "Mimikatz credential tool", is_default: true, created_by: "system"},
  %{name: "cobalt-strike", color: "#F59E0B", category: "tool", description: "Cobalt Strike C2", is_default: true, created_by: "system"},
  %{name: "nmap", color: "#F59E0B", category: "tool", description: "Network scanner", is_default: true, created_by: "system"},
  %{name: "bloodhound", color: "#F59E0B", category: "tool", description: "Active Directory analysis", is_default: true, created_by: "system"},
  %{name: "rubeus", color: "#F59E0B", category: "tool", description: "Kerberos abuse tool", is_default: true, created_by: "system"},
  %{name: "impacket", color: "#F59E0B", category: "tool", description: "Network protocol toolkit", is_default: true, created_by: "system"},
  %{name: "crackmapexec", color: "#F59E0B", category: "tool", description: "Network exploitation suite", is_default: true, created_by: "system"},
  %{name: "metasploit", color: "#F59E0B", category: "tool", description: "Exploitation framework", is_default: true, created_by: "system"},
  %{name: "burp-suite", color: "#F59E0B", category: "tool", description: "Web application testing", is_default: true, created_by: "system"},
  %{name: "powershell", color: "#F59E0B", category: "tool", description: "PowerShell scripting", is_default: true, created_by: "system"},
  %{name: "sliver", color: "#F59E0B", category: "tool", description: "Sliver C2 framework", is_default: true, created_by: "system"},
  %{name: "brute-ratel", color: "#F59E0B", category: "tool", description: "Brute Ratel C2", is_default: true, created_by: "system"},
  %{name: "sharphound", color: "#F59E0B", category: "tool", description: "BloodHound data collector", is_default: true, created_by: "system"},
  %{name: "certify", color: "#F59E0B", category: "tool", description: "AD CS abuse tool", is_default: true, created_by: "system"},
  %{name: "kerbrute", color: "#F59E0B", category: "tool", description: "Kerberos brute force", is_default: true, created_by: "system"},

  # Target tags (10)
  %{name: "domain-controller", color: "#8B5CF6", category: "target", description: "Domain controller", is_default: true, created_by: "system"},
  %{name: "workstation", color: "#8B5CF6", category: "target", description: "User workstation", is_default: true, created_by: "system"},
  %{name: "web-server", color: "#8B5CF6", category: "target", description: "Web server", is_default: true, created_by: "system"},
  %{name: "database-server", color: "#8B5CF6", category: "target", description: "Database server", is_default: true, created_by: "system"},
  %{name: "file-server", color: "#8B5CF6", category: "target", description: "File server", is_default: true, created_by: "system"},
  %{name: "mail-server", color: "#8B5CF6", category: "target", description: "Mail server", is_default: true, created_by: "system"},
  %{name: "cloud-resource", color: "#8B5CF6", category: "target", description: "Cloud resource", is_default: true, created_by: "system"},
  %{name: "network-device", color: "#8B5CF6", category: "target", description: "Network device", is_default: true, created_by: "system"},
  %{name: "linux-server", color: "#8B5CF6", category: "target", description: "Linux server", is_default: true, created_by: "system"},
  %{name: "windows-server", color: "#8B5CF6", category: "target", description: "Windows server", is_default: true, created_by: "system"},

  # Status tags (5)
  %{name: "compromised", color: "#DC2626", category: "status", description: "Fully compromised", is_default: true, created_by: "system"},
  %{name: "partial-access", color: "#F97316", category: "status", description: "Partial access gained", is_default: true, created_by: "system"},
  %{name: "failed-attempt", color: "#6B7280", category: "status", description: "Failed attempt", is_default: true, created_by: "system"},
  %{name: "in-progress", color: "#3B82F6", category: "status", description: "In progress", is_default: true, created_by: "system"},
  %{name: "completed", color: "#10B981", category: "status", description: "Completed", is_default: true, created_by: "system"},

  # Priority tags (4)
  %{name: "critical", color: "#DC2626", category: "priority", description: "Critical priority", is_default: true, created_by: "system"},
  %{name: "high", color: "#F97316", category: "priority", description: "High priority", is_default: true, created_by: "system"},
  %{name: "medium", color: "#F59E0B", category: "priority", description: "Medium priority", is_default: true, created_by: "system"},
  %{name: "low", color: "#10B981", category: "priority", description: "Low priority", is_default: true, created_by: "system"},

  # Workflow tags (4)
  %{name: "needs-review", color: "#F59E0B", category: "workflow", description: "Needs peer review", is_default: true, created_by: "system"},
  %{name: "follow-up", color: "#3B82F6", category: "workflow", description: "Requires follow-up", is_default: true, created_by: "system"},
  %{name: "documented", color: "#10B981", category: "workflow", description: "Fully documented", is_default: true, created_by: "system"},
  %{name: "reported", color: "#6B7280", category: "workflow", description: "Included in report", is_default: true, created_by: "system"},

  # Evidence tags (4)
  %{name: "screenshot", color: "#EC4899", category: "evidence", description: "Screenshot evidence", is_default: true, created_by: "system"},
  %{name: "packet-capture", color: "#EC4899", category: "evidence", description: "Packet capture", is_default: true, created_by: "system"},
  %{name: "memory-dump", color: "#EC4899", category: "evidence", description: "Memory dump", is_default: true, created_by: "system"},
  %{name: "log-file", color: "#EC4899", category: "evidence", description: "Log file evidence", is_default: true, created_by: "system"},

  # Security tags (3)
  %{name: "sensitive", color: "#DC2626", category: "security", description: "Sensitive data", is_default: true, created_by: "system"},
  %{name: "pii", color: "#DC2626", category: "security", description: "Contains PII", is_default: true, created_by: "system"},
  %{name: "classified", color: "#DC2626", category: "security", description: "Classified information", is_default: true, created_by: "system"},

  # Operation tags (6)
  %{name: "phishing", color: "#3B82F6", category: "operation", description: "Phishing campaign", is_default: true, created_by: "system"},
  %{name: "social-engineering", color: "#3B82F6", category: "operation", description: "Social engineering", is_default: true, created_by: "system"},
  %{name: "physical-access", color: "#3B82F6", category: "operation", description: "Physical access test", is_default: true, created_by: "system"},
  %{name: "network-pentest", color: "#3B82F6", category: "operation", description: "Network penetration test", is_default: true, created_by: "system"},
  %{name: "web-app-test", color: "#3B82F6", category: "operation", description: "Web application test", is_default: true, created_by: "system"},
  %{name: "red-team-exercise", color: "#3B82F6", category: "operation", description: "Full red team exercise", is_default: true, created_by: "system"}
]

for tag_attrs <- tags do
  tag_attrs = Map.merge(tag_attrs, %{inserted_at: now, updated_at: now})
  Repo.insert!(%Tag{} |> Ecto.Changeset.change(tag_attrs), on_conflict: :nothing, conflict_target: :name)
end

IO.puts("Seeded #{length(tags)} default tags.")
