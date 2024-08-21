# OCI multi tenancy setup

OCI stands on several pillars, one of which is identity and access management (IAM), which secures API access to OCI resources. IAM security is combined with flexibility, providing infrastructure tenants with a range of options to lay out their resources. The most important tool for grouping resources together is the compartment.

## Compartment

In a classic data center, hardware is installed in server rooms or cages with physical security barriers and access identification. This serves as the best physical anchor for an IAM compartment, as it groups resources together by providing API-level security barriers and access identification, much like in a physical data center. OCI compartments, as virtual resources, offer even more; they can be configured with their own user identification domain, access policies, default tags for newly created resources, and other properties like security zones, service limits, and budgets.

## Tenancy

An OCI account comes with a default root compartment, called a tenancy. The root compartment is a regular compartment; however, OCI services may use the root for special purposes. A few examples include: some IAM policies that must be registered at the root, Cloud Guard configuration being stored at the root, Budgets residing at the root, and the API audit log always being created per tenancy.

On one hand, a compartment is a self-sufficient partition of the infrastructure that may be used to model corporate divisions’ or projects’ independence. On the other one, root compartment requirements make the tenancy a very unique compartment type, which in some cases cannot be modeled using a standard compartment. Some types of resources are not located in any compartment, which means that the tenancy is their location.

Keep in mind that IAM does not provide the ability to block access  -  you cannot revoke access rights, so it’s not possible to limit access to any compartment for the tenancy administrator - this account always has access to everything in the whole tenancy.

Tenancy is a top-level security context with its own exclusive administrator, root compartment space, service limits, audit log, usage reports, budgets and compartments. Tenancy administrator has access to all resources in all compartments existing in its tenancy.

## Production

Production systems are the most critical environments in any organization, as they host the live applications and services that the business and its customers rely on. These systems hold sensitive customer data, which must remain within enterprise boundaries under all circumstances. Nowadays for any kind of enterprise strict data protection policies applies on a baseline level, and more restricting policies applies to selected industries. The production tier is the heart of most modern enterprises and must be protected against any possible threats, not to witness customer and regulatory complains, and not to be discussed on media as source of leaking data or lack of service availability.

Due to their importance, production systems are always separated from development, testing, and staging environments. This separation ensures stability, security, and performance, as production systems must be highly reliable and resilient to handle real-world workloads without interruption.

Every change must be performed under detailed procedures by authorized personnel only. Resources must be protected by separate access controls and cannot be shared with other types of systems. No part of the system may be shared with other tiers, as even a theoretically even non-critical change could impact stability or security of the production. Personnel who share roles between non-production and production systems should use different identifiers at authorization barriers, or access should be permitted only during predefined time windows.

## Infrastructure development cycle

Infrastructure configuration is the same component of the system as data processing software, and it must be passed through the same development cycle. Infrastructure deployment procedures (including IaaS code) are a type of software products that have their users: deployers and operations staff, and they must be prepared according to regular software development standards to ensure expected quality. Without this, production deployment may fail, monitoring may not work, and operations teams may not know how to operate resources. This may lead to a catastrophe, for example, scalability, failover, or disaster recovery may not work, or even worse - security could be compromised.

In short, each and every production-level procedure must be developed and initially validated in non-production environments before being passed to production use.

## Organization Management

OCI public cloud typically comes with a single tenancy; however, the OCI Organization Management service makes it possible to establish multiple tenancies associated with a single Cloud Account, which means that one bill is issued for all the tenancies. The same applies to DRCC, which is owned and financed by a single business entity. DRCC is an OCI region exclusively used by a single owner. In this situation, the region owner has the freedom to decide if the region should be used as a single tenancy or divided into multiple ones.

In public OCI, a tenancy is typically synonymous with a Cloud Account, as the latter always comes with the former. The Cloud Account is associated with a subscription and contract type, which defines the consumption commitment. In such a model, it doesn’t make sense for a single organization to have multiple tenancies, as it would be difficult to manage the consumption commitment, leading to inefficient spending.

However, this has changed now, as OCI offers an Organization Management service that enhances OCI’s ability to share a subscription among multiple tenancies.

## DRCC

DRCC offers even more flexibility, as the commitment associated with the contract is at the level of the DRCC realm. The DRCC owner may create as many tenancies as needed; moreover, they may use the Organization Management service to group tenancies together under one larger security context.

## Multi tenancy

OCI technology, with the Organization Management service, creates an environment that benefits from multi-tenancy, as the parent tenancy’s subscription is shared among multiple child tenancies. DRCC offers even more flexibility, as DRCC operates at the realm level with a subscription shared among all tenancies in the realm. It’s important to note that tenancy is a foundational IAM service that is free of charge; there is no SKU for tenancy, and the tenancy resource is not billed.
With subscription sharing in place, the DRCC owner can freely create tenancies for each top-level security context. Each major project or organizational division can use its own tenancy. Moreover, the DRCC owner may place shared services in a dedicated tenancy to establish an internal SaaS model.

It’s important to understand that each tenancy is a separate security and functional context, and the majority of OCI services operate within that tenancy. The first obvious example is the IAM service, which governs tenancy-level authentication and authorization policies. Load balancers used to require access to VCNs, but recent upgrades allow the use of IP addresses. The DNS service with private views also requires access to a VCN; however, you can define several remote endpoints by IP address. Cloud Guard operates within a single tenancy. Similarly, the Network Security Group operates only inside the VCN, so inter-tenancy NSG addressing is not possible.
All of this is great as it's the purpose of the tenancy - to establish an exclusive security context.

## Multi tenant communication

Network communication between tenancies may be achieved using public addresses as such communication will never leave DRCC reaching DRCC edge routers to come back to the target tenancy. Owner may setup security lists or firewall to limit communication to internal addresses only. Unfortunately, there is no possibility to configure edge router firewall, however DRCC owner may provide Oracle with Internet lines behind customer's firewall. Anyway, it sounds like a required approach to control DRCC traffic by external security device. Having this customer may block public access to DRCC public addresses, keeping only required traffic with Oracle region management systems.Using public IP addresses in DRCC is an effective approach when proper protection from the public internet is implemented.

Another, more secure model is to use other data exchange methods, such as object storage, to establish communication between data tiers. This is the preferred model for data exchange between non-production and production tiers.

Tenancies on the same tier may be connected by:

* remote peering - establishing connection between DRG in two tenancies,
* cross-tenancy VCN attachment - to establish connectivity with selected VCN from remote tenancy.

To be able to use these methods, DRCC design must manage internal non-public IP addresses, which should be assigned to the tenancies. An internal policy of using IP address classes A, B, and C should be established.
Using DRG to communicate with other tenancies is the most secure method, as such traffic will not be routed to the public internet, and public internet devices will never reach tenancy resources with private interfaces.

## FastConnect sharing

The multi-tenancy model requires configuration of FastConnect in “partner mode,” as it may not be cost-effective to procure a FastConnect port for each tenancy. Under this model, the DRCC owner receives from Oracle a “FastConnect partner” tenancy - similar to what regular partners use on the public cloud. Each tenancy configures a virtual circuit with an agreed VLAN tag using the “internal partner” physical FastConnect port. Tenancies may establish their own virtual circuits or use DRG capabilities to route data through a hub tenancy, utilizing only one pair of virtual circuits per system.
When sharing the FastConnect port, the customer is responsible for QoS configuration to ensure tenancies receive the required bandwidth. If the customer is unable to configure QoS on edge devices, they should select dedicated pairs of FastConnect ports for the system’s tiers.

In addition to the FastConnect shared or dedicated setup, customers should always procure two FastConnect ports from different edge devices as a baseline for high availability to safeguard against line outages and device maintenance windows. All aspects of FastConnect are described in a dedicated article.

It’s important to emphasize that “partner mode” is available only in DRCC because the realm is owned by a single customer. In the public cloud, this technique cannot be used, and customers need to organize dedicated FastConnect ports or virtual circuits using services from FastConnect partners integrated with the public realm. DRCC with virtual circuits (VLNs) provides a more natural environment for IP-level QoS to share available bandwidth among system tiers. The same may be achieved without VLANs; however, network engineers need to configure QoS using OCI-side CIDR ranges.

## Sandbox

Oracle recommends that infrastructure engineers have access to a sandbox environment, where they can freely experiment with OCI technology. A sandbox environment is a crucial tool for infrastructure engineers working with OCI. It provides a safe, isolated space for learning, experimentation, and testing, which leads to better-prepared and more confident deployments in production. Oracle’s recommendation for a sandbox environment aligns with best practices in cloud infrastructure management, ensuring that teams can innovate and develop their skills while minimizing risks to critical business operations.

A sandbox should always be a separate tenancy, as it is not possible to share this kind of space with any other system tier. It is also unacceptable to share it with the production tenancy, as engineers need access to root compartment-level configuration and services.

## Shared services

DRCC creates an ideal environment to create tenancies that provide shared services. The owner may easily set up a configuration similar to Oracle Services Network, where certain services are run in dedicated tenancies. Communication with shared services can be performed over non-routable CIDR using DRG remote connectivity or over public IP addresses. DRCC does not charge for outbound internet traffic, so it’s possible to utilize public addresses without limits, provided that proper network access configuration is in place to eliminate potential access from the public network.

The shared services lifecycle must be organized in the same way as any other service, with a development process and engineering sandbox. It may be tempting to consolidate some services, such as firewall or FastConnect, into a central hub to increase cost-efficiency; however, such decisions must always be supported by considerations such as maintenance windows, error resilience, bandwidth sharing, security, and other relevant factors.

## No! Let's do multi compartment

OK. So, you want to stay in a single tenancy with multiple compartments. That’s possible, and you will clearly benefit from easier configuration. It will be easier to establish hub/spokes, virtual circuits can utilize FastConnect ports without partner mode, and administrators will have easy access to production and non-production tiers with protection from identity domains. You can even use a single state file to handle all the resources within the tenancy.

However, you will need to prepare an infrastructure development strategy, perform a risk analysis, split the audit log into production and non-production within your SIEM, determine who is the owner of the tenancy, and define how non-production stakeholders will request adjustments to root compartment level. You must also validate that such a shared system is compliant with all relevant policies and regulations that the enterprise must follow. And of course, a sandbox will be limited to compartment-level configurations, which means Cloud Guard, dynamic groups, and other features will be out of scope for research and infrastructure development activities.
