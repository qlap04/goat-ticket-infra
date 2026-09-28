# GOAT Ticket — Infrastructure

## Learn APPGW Component

### Frontend IP Address

The frontend IP address is the IP associated with the App Gateway: public IP, private IP, or both.

In v2, the Azure Application Gateway v2 SKU can be configured to support both a static internal IP address and a static public IP address, or only a static public IP address.

### Listeners

A listener is a logical entity that checks for incoming connection requests. A listener accepts a request if the protocol, port, hostname, and IP address associated with the request match the same elements associated with the listener configuration.

Before you use an application gateway, you must add at least one listener. There can be multiple listeners attached to an application gateway, and they can be used for the same protocol.

After a listener detects incoming requests from clients, the application gateway routes these requests to members in the backend pool configured in the rule.

Listeners support the following ports and protocols:

- Port: V2 → 1 to 64999

> **Fun info:** Application Gateway lets you create custom error pages instead of displaying default error pages. You can use your own branding and layout using a custom error page. Application Gateway displays a custom error page when a request can't reach the backend.

#### Types of listeners

There are two types of listeners:

- **Basic.** This type of listener listens to a single domain site, where it has a single DNS mapping to the IP address of the application gateway. This listener configuration is required when you host a single site behind an application gateway.

- **Multi-site.** This listener configuration is required when you want to configure routing based on host name or domain name for more than one web application on the same application gateway. It allows you to configure a more efficient topology for your deployments by adding up to 100+ websites to one application gateway. Each website can be directed to its own backend pool. For example, three domains — contoso.com, fabrikam.com, and adatum.com — point to the IP address of the application gateway. You'd create three multi-site listeners and configure each listener for the respective port and protocol setting.

The request routing rule also allows you to redirect traffic on the application gateway. This is a generic redirection mechanism, so you can redirect to and from any port you define by using rules.

### Request Routing Rules

A routing rule binds a listener to a backend pool + HTTP setting, determining
how a matched request gets forwarded. Two types:

- **Basic** — routes all requests on the listener to a single backend pool.
- **Path-based** — routes based on URL path patterns to different backend pools
  (e.g., /api/* → API pool, /images/* → static content pool).

### HTTP Settings

An HTTP setting, also called a backend setting, is the configuration that determines how traffic reaches the backend servers. It defines the port and protocol that the application gateway uses to connect to those servers, how connections behave, and how the gateway monitors backend health. A request routing rule specifies which HTTP setting to apply when it forwards a request to a backend pool.

### Backend Pools

A backend pool routes requests to backend servers, which serve the request. Backend pools can contain:

- NICs
- Virtual machine scale sets
- Public IP addresses
- Internal IP addresses
- FQDNs (fully qualified domain names) or short names (single-label domain names), provided your DNS server can resolve them
- Multitenant backends such as Azure App Service and Azure Container Apps

### Health Probes

By default, an application gateway monitors the health of all resources in its backend pool and automatically removes unhealthy ones. It then monitors unhealthy instances and adds them back to the healthy backend pool when they become available and respond to health probes.
