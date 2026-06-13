# Networking Notes

## Assumptions

- The dedicated Ubuntu server will live on the local network.
- The server should receive a stable IP address, ideally via DHCP reservation.
- Administration will happen over SSH from the Mac Mini.

## Initial Service Ports

- Forgejo HTTP: `3000`
- Forgejo SSH: `2222`
- Hermes: `8080`
- n8n: `5678`

## Firewall Baseline

- Allow `OpenSSH`
- Deny other inbound traffic by default
- Open application ports deliberately as services are exposed

## Future Improvements

- Add reverse proxy routing for multiple internal services
- Add TLS termination for browser-facing applications
- Split public and private service exposure where needed
- Document port allocations as the homelab grows
