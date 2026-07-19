# tf-mod-aws-appmesh — SCOPE

Composite module for an AWS App Mesh service mesh **control plane**: the mesh
itself plus its virtual nodes, virtual routers, virtual gateways, virtual
services, routes, and gateway routes. This module wires the App Mesh object
graph together (mesh → virtual node/router/gateway → virtual service →
route/gateway route); it does **not** configure the Envoy data-plane sidecar
that must be injected into the ECS task definition or EKS pod spec that
actually carries the mesh traffic.

- **Module type:** Composite
- **Primary resource (keystone):** `aws_appmesh_mesh.this`

> ℹ️ **Reduced AWS investment in App Mesh.** AWS has publicly signaled reduced
> investment in App Mesh in favor of **ECS Service Connect** (for ECS-native
> service discovery + mesh-lite behavior) and **Amazon EKS's native mesh
> integrations** (e.g. VPC Lattice, Istio/Cilium via EKS add-ons). Evaluate
> whether a new workload actually needs full App Mesh (mutual TLS, weighted
> routing, retry policies, Envoy-level observability) before committing to it
> — for many ECS-only use cases, Service Connect is materially simpler to
> operate and is AWS's forward-looking recommendation. This module remains
> fully supported for existing/planned App Mesh estates, but architects should
> make this choice with eyes open.

## In-scope resources

- `aws_appmesh_mesh` — keystone (the service mesh: `spec.egress_filter`,
  `spec.service_discovery.ip_preference`)
- `aws_appmesh_virtual_node` — `map(object(...))`, `for_each`, keyed by caller
  string (listeners, backends, backend_defaults, service_discovery, logging)
- `aws_appmesh_virtual_router` — `map(object(...))`, `for_each` (listener/port_mapping)
- `aws_appmesh_virtual_gateway` — `map(object(...))`, `for_each` (listener, TLS,
  backend_defaults, logging)
- `aws_appmesh_virtual_service` — `map(object(...))`, `for_each` (provider =
  virtual_node OR virtual_router, referenced by sibling key)
- `aws_appmesh_route` — `map(object(...))`, `for_each`, attached to a
  `virtual_router_key` (http/http2/grpc/tcp match + weighted-target action +
  retry_policy + timeout)
- `aws_appmesh_gateway_route` — `map(object(...))`, `for_each`, attached to a
  `virtual_gateway_key` (http/http2/grpc match + target virtual_service + rewrite)

## Out-of-scope resources (consumed by reference)

- **ECS service / task definition** (`aws_ecs_service`, `aws_ecs_task_definition`)
  — the Envoy proxy sidecar and `proxy_configuration { type = "APPMESH" }` are
  configured in `tf-mod-aws-ecs-service`, not here. This module only creates the
  control-plane objects the sidecar registers against.
- **EKS pod/deployment manifests** — Envoy sidecar injection via the App Mesh
  controller/CRDs is a Kubernetes-layer concern, out of Terraform's scope here.
- **AWS Cloud Map namespace/service** (`aws_service_discovery_*`) — consumed by
  ARN/name from `tf-mod-aws-service-discovery` for `aws_cloud_map` service
  discovery on a virtual node.
- **ACM certificate** (`aws_acm_certificate`) — consumed by ARN from
  `tf-mod-aws-acm` for TLS-terminating listeners (`tls.certificate.acm`).
- **IAM roles** — consumed by ARN only; App Mesh resources themselves take no
  `iam:PassRole` (Envoy runs under the ECS task/execution role, managed by
  `tf-mod-aws-ecs-service` / `tf-mod-aws-iam-role`).
- **Private CA** (`aws_acmpca_certificate_authority`) — consumed by ARN from
  `tf-mod-aws-acm-pca` for `trust.acm.certificate_authority_arns` (mutual TLS).

## Consumes

| Input | Type | Source module |
|---|---|---|
| `virtual_nodes[*].service_discovery.aws_cloud_map.namespace_name` / `.service_name` | `string` | `tf-mod-aws-service-discovery` |
| `virtual_nodes[*].listeners[*].tls.certificate.acm.certificate_arn` | `string` (ARN) | `tf-mod-aws-acm` (regional cert) |
| `virtual_gateways[*].listener.tls.certificate.acm.certificate_arn` | `string` (ARN) | `tf-mod-aws-acm` (regional cert) |
| `*.tls.validation.trust.acm.certificate_authority_arns` | `list(string)` (ARNs) | `tf-mod-aws-acm-pca` |
| ECS task definition `proxy_configuration` / container `APPMESH_*` env vars | n/a | `tf-mod-aws-ecs-service` (consumes THIS module's outputs, not the reverse) |

> **Near-foundation module** — App Mesh consumes ACM certs, Cloud Map services,
> and (optionally) Private CA ARNs, but nothing from compute. Compute modules
> (`tf-mod-aws-ecs-service`) consume this module's virtual-node/virtual-service
> names, not the other way around.

## Required IAM permissions

| Action | Required for |
|---|---|
| `appmesh:CreateMesh`, `appmesh:DescribeMesh`, `appmesh:UpdateMesh`, `appmesh:DeleteMesh`, `appmesh:ListMeshes`, `appmesh:TagResource`, `appmesh:UntagResource` | Mesh lifecycle |
| `appmesh:CreateVirtualNode`, `appmesh:DescribeVirtualNode`, `appmesh:UpdateVirtualNode`, `appmesh:DeleteVirtualNode`, `appmesh:ListVirtualNodes` | Virtual node lifecycle |
| `appmesh:CreateVirtualRouter`, `appmesh:DescribeVirtualRouter`, `appmesh:UpdateVirtualRouter`, `appmesh:DeleteVirtualRouter`, `appmesh:ListVirtualRouters` | Virtual router lifecycle |
| `appmesh:CreateVirtualGateway`, `appmesh:DescribeVirtualGateway`, `appmesh:UpdateVirtualGateway`, `appmesh:DeleteVirtualGateway`, `appmesh:ListVirtualGateways` | Virtual gateway lifecycle |
| `appmesh:CreateVirtualService`, `appmesh:DescribeVirtualService`, `appmesh:UpdateVirtualService`, `appmesh:DeleteVirtualService`, `appmesh:ListVirtualServices` | Virtual service lifecycle |
| `appmesh:CreateRoute`, `appmesh:DescribeRoute`, `appmesh:UpdateRoute`, `appmesh:DeleteRoute`, `appmesh:ListRoutes` | Route lifecycle |
| `appmesh:CreateGatewayRoute`, `appmesh:DescribeGatewayRoute`, `appmesh:UpdateGatewayRoute`, `appmesh:DeleteGatewayRoute`, `appmesh:ListGatewayRoutes` | Gateway route lifecycle |

No `iam:PassRole` is required by this module — the ACM certificate ARN and
Cloud Map service ARN are referenced directly, not assumed. If mutual TLS with
a Private CA is used, the Terraform identity does not need PCA IAM actions
either; only the Envoy runtime (via the ECS task role, out of scope here)
needs `acm-pca:GetCertificateAuthorityCertificate`.

## AWS Prerequisites

- **No service-linked role** is required for App Mesh itself.
- **Data-plane sidecar is NOT managed here.** App Mesh only takes effect once
  the Envoy proxy container is injected into the ECS task definition
  (`proxy_configuration { type = "APPMESH" }`, plus the `init` container and
  `APPMESH_RESOURCE_ARN` environment variable pointing at this module's
  `virtual_node_arns[key]` output) or the EKS pod spec (via the App Mesh
  Kubernetes controller). Wire this module's outputs into
  `tf-mod-aws-ecs-service`'s `proxy_configuration` and container definitions.
- **Region:** App Mesh is a regional service; no us-east-1 constraint applies.
  Standard provider inheritance (no `region` variable in this module).
- **Cloud Map dependency:** `aws_cloud_map` service discovery requires an
  existing AWS Cloud Map namespace/service (`tf-mod-aws-service-discovery`)
  created before the virtual node references it.
- **Quotas:** 250 meshes per account (soft), 5,000 virtual nodes / 5,000
  virtual services per mesh, 10 listeners per virtual node (soft) — see the
  App Mesh service quotas page if approaching these limits.
- **Strategic note:** see the `> ℹ️` callout above — confirm App Mesh (vs. ECS
  Service Connect / EKS-native mesh) is the intended long-term architecture
  before building on it.

## Emits

| Output | Description | Consumed by |
|---|---|---|
| `id` | Mesh id (= mesh name) | Cross-references within this module |
| `arn` | Mesh ARN | IAM policies scoping `appmesh:*` actions |
| `virtual_node_ids` / `virtual_node_arns` | Map keyed by caller key | `tf-mod-aws-ecs-service` (`APPMESH_RESOURCE_ARN`, `proxy_configuration`) |
| `virtual_router_ids` / `virtual_router_arns` | Map keyed by caller key | Route wiring, monitoring |
| `virtual_gateway_ids` / `virtual_gateway_arns` | Map keyed by caller key | Gateway route wiring, ECS/EKS gateway task |
| `virtual_service_ids` / `virtual_service_arns` | Map keyed by caller key | Client-side virtual node `backend` references, gateway route targets |
| `route_ids` / `route_arns` | Map keyed by caller key | Monitoring / CloudWatch dashboards |
| `gateway_route_ids` / `gateway_route_arns` | Map keyed by caller key | Monitoring / CloudWatch dashboards |
| `tags_all` | Mesh tags including provider `default_tags` | Governance/audit |

## Provider gotchas

- **Creation order is implicit-dependency driven, not automatic.** A virtual
  service's `provider` block references a virtual router or virtual node by
  **name** (not ARN) — Terraform infers the dependency correctly only because
  this module passes `aws_appmesh_virtual_router.this[key].name` /
  `aws_appmesh_virtual_node.this[key].name` as the value, so always reference
  the resource attribute, never a bare string, even though the API itself
  takes a string.
- **Routes/gateway routes reference virtual nodes and virtual services by
  name**, so the same rule applies: route `action.weighted_target.virtual_node`
  and gateway-route `action.target.virtual_service.virtual_service_name` are
  wired from `aws_appmesh_virtual_node.this[key].name` /
  `aws_appmesh_virtual_service.this[key].name`, not raw caller strings, so
  Terraform's dependency graph — not creation order luck — governs apply order.
- **`spec` blocks are deeply nested** — modeled here with nested `object()`
  types mirroring the schema exactly (never `any`, never a loose `map` for
  structured data), including `listener.tls.certificate` (`acm`/`file`/`sds`),
  `listener.tls.validation.trust` (`acm`/`file`/`sds`), `connection_pool`
  (`grpc`/`http`/`http2`/`tcp`), `outlier_detection`, per-protocol `timeout`,
  and per-route `match`/`action`/`retry_policy`.
- **`mesh_name` / `virtual_router_name` / `virtual_gateway_name` are FORCE-NEW**
  on the child resources — renaming the parent mesh/router/gateway destroys and
  recreates every dependent virtual node/router/gateway/route.
- **`name` is FORCE-NEW on every App Mesh resource** — there is no in-place
  rename; changing any `name` key destroys and recreates that object (and
  cascades to anything referencing it by name).
- **Import key format is compound**, e.g. `mesh_name/name` for virtual
  nodes/routers/gateways/services, and `mesh_name/virtual_router_name/name` for
  routes, `mesh_name/virtual_gateway_name/name` for gateway routes — document
  this in any import example.
- **`egress_filter` DROP_ALL is the mesh default** even if the argument is
  omitted entirely — this module makes that default explicit in the type
  system rather than relying on the provider's implicit default, per the Casey's
  secure-by-default posture.
- **Destroy ordering**: virtual services must be destroyed before the virtual
  node/router they reference can be destroyed (Terraform infers this from the
  `name` reference, but a manual `terraform destroy -target` sequence must
  respect it too); gateway routes must be destroyed before their virtual
  gateway.
- **Schema asymmetry — listener TLS trust vs. client-policy TLS trust**
  (discovered during authoring, confirmed against the live v6.54.0 schema): a
  **listener's** `tls.validation.trust` block (on `aws_appmesh_virtual_node`
  and `aws_appmesh_virtual_gateway`) supports only `file`/`sds` — **no
  `acm`** — while a **client_policy's** `tls.validation.trust` block (used on
  `backend`/`backend_defaults`, i.e. the OUTBOUND mTLS trust a node extends to
  its backends) supports `acm`/`file`/`sds`. This module's variable types
  mirror that asymmetry exactly; adding `acm` to the listener path is a
  provider-level `Unsupported block type` error, not a bug in this module.
- **Schema asymmetry — gateway-route action `rewrite`** (discovered during
  authoring): `http_route`/`http2_route` gateway-route actions support an
  optional `rewrite` block (hostname/path/prefix rewriting); `grpc_route`
  gateway-route actions do **not** — `rewrite` is an HTTP-only concept and is
  omitted entirely from this module's `grpc_route` type for gateway routes.

## Secure-by-default decisions

| Posture | Default | Opt-out |
|---|---|---|
| Mesh egress filter | `egress_filter_type = "DROP_ALL"` (explicit allow-list; a virtual node may only reach backends declared via `backend`) | Set `egress_filter_type = "ALLOW_ALL"` — documented exception, effectively disables mesh-level egress control |
| Listener TLS mode | No baked-in default is forced onto the type (`mode` is a required field on every `tls` object the caller supplies), but the **README and SCOPE recommend `STRICT`** with an ACM-issued certificate (`tls.certificate.acm`) for any listener carrying NPI-adjacent traffic; `PERMISSIVE` is acceptable only during a migration window | Omit the `tls` block entirely (unencrypted listener) — must be a documented exception; never silently defaulted |
| Access logging | `logging_access_log_path` — when set, renders `logging.access_log.file.path`; the README's virtual-node/virtual-gateway examples default this to `/dev/stdout` so container log drivers (`awslogs`) capture it without extra volume mounts | Leave `logging_access_log_path = null` to disable Envoy access logs (reduces auditability — discouraged for NPI-adjacent services) |
| Client-policy TLS enforcement | When a caller supplies `client_policy.tls`, `enforce` defaults to `true` (the App Mesh/provider default) | Set `enforce = false` to allow both encrypted and unencrypted upstream connections — documented exception |
| Route retry policy | Optional (not forced) — the README's HTTP-route example demonstrates `retry_policy` with `server-error`/`gateway-error` events as the recommended baseline for resilience | Omit `retry_policy` for fire-and-forget routes |

## Design decisions

- **Composite boundary = the full App Mesh object graph**, because meshes,
  virtual nodes/routers/gateways, virtual services, and routes/gateway routes
  are meaningless in isolation and are almost always authored together for one
  logical mesh; splitting them into seven modules would force the caller to
  hand-wire every cross-reference that Terraform's own dependency graph already
  resolves for free within one module.
- **Keyed `for_each` maps throughout** (no `count`) so a caller can add/remove
  an individual virtual node, route, etc. without shifting indices and forcing
  unrelated resources to be recreated.
- **Sibling-key cross-references** (`virtual_router_key`, `provider_virtual_node_key`,
  `virtual_node_key` inside route weighted targets, `virtual_service_key` inside
  gateway-route targets) mirror the pattern already established in
  `tf-mod-aws-lb` (`target_group_key`, `listener_key`) so callers of composite
  Casey's modules see one consistent idiom for "reference a sibling resource by its
  map key" across the whole library.
- **Deliberately data-plane-agnostic.** This module never touches an ECS task
  definition or EKS manifest — it only emits the ARNs/names the data plane
  needs. Keeping the control plane and data plane in separate modules lets
  `tf-mod-aws-ecs-service` (or a future EKS-side module) own the sidecar
  injection concern independently, and lets a mesh be modeled once and
  consumed by multiple compute modules.
