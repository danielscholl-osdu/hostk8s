# infra/scripts/show-help.ps1 - Display help information for HostK8s
. "$PSScriptRoot\common.ps1"

Write-Host 'HostK8s - Host-Mode Kubernetes Development Platform'
Write-Host ''
Write-Host 'Usage:'
Write-Host '  make ' -NoNewline; Write-Host '<target>' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Setup' -ForegroundColor White
Write-Host '  ' -NoNewline; Write-Host 'help' -ForegroundColor Cyan -NoNewline; Write-Host '             Show this help message'
Write-Host '  ' -NoNewline; Write-Host 'install' -ForegroundColor Cyan -NoNewline; Write-Host '          Install dependencies and setup environment (Usage: make install [dev])'
Write-Host ''
Write-Host 'Infrastructure' -ForegroundColor White
Write-Host '  ' -NoNewline; Write-Host 'start' -ForegroundColor Cyan -NoNewline; Write-Host '            Start cluster (Usage: make start [config-name] - auto-discovers kind-*.yaml files)'
Write-Host '  ' -NoNewline; Write-Host 'stop' -ForegroundColor Cyan -NoNewline; Write-Host '             Stop cluster'
Write-Host '  ' -NoNewline; Write-Host 'up' -ForegroundColor Cyan -NoNewline; Write-Host '               Deploy software stack (Usage: make up [stack-name] - defaults to ''sample'')'
Write-Host '  ' -NoNewline; Write-Host 'down' -ForegroundColor Cyan -NoNewline; Write-Host '             Remove software stack (Usage: make down <stack-name>)'
Write-Host '  ' -NoNewline; Write-Host 'restart' -ForegroundColor Cyan -NoNewline; Write-Host '          Quick cluster reset for development iteration (Usage: make restart [stack-name])'
Write-Host '  ' -NoNewline; Write-Host 'clean' -ForegroundColor Cyan -NoNewline; Write-Host '            Complete cleanup (destroy cluster and data)'
Write-Host '  ' -NoNewline; Write-Host 'status' -ForegroundColor Cyan -NoNewline; Write-Host '           Show cluster health and running services'
Write-Host '  ' -NoNewline; Write-Host 'sync' -ForegroundColor Cyan -NoNewline; Write-Host '             Force Flux reconciliation (Usage: make sync [stack-name] or REPO=name/KUSTOMIZATION=name make sync)'
Write-Host '  ' -NoNewline; Write-Host 'suspend' -ForegroundColor Cyan -NoNewline; Write-Host '          Suspend GitOps reconciliation (pause all GitRepository sources)'
Write-Host '  ' -NoNewline; Write-Host 'resume' -ForegroundColor Cyan -NoNewline; Write-Host '           Resume GitOps reconciliation (restore all GitRepository sources)'
Write-Host ''
Write-Host 'Applications' -ForegroundColor White
Write-Host '  ' -NoNewline; Write-Host 'deploy' -ForegroundColor Cyan -NoNewline; Write-Host '           Deploy application (Usage: make deploy [app-name] [namespace] - defaults to ''simple'')'
Write-Host '  ' -NoNewline; Write-Host 'remove' -ForegroundColor Cyan -NoNewline; Write-Host '           Remove application (Usage: make remove <app-name> [namespace] or NAMESPACE=ns make remove <app-name>)'
Write-Host ''
Write-Host 'Development Tools' -ForegroundColor White
Write-Host '  ' -NoNewline; Write-Host 'logs' -ForegroundColor Cyan -NoNewline; Write-Host '             View recent cluster events and logs'
Write-Host '  ' -NoNewline; Write-Host 'build' -ForegroundColor Cyan -NoNewline; Write-Host '            Build and push application from src/ (Usage: make build src/APP_NAME)'
