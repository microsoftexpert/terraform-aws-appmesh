###############################################################################
# Identity — mesh (keystone)
###############################################################################

variable "mesh_name" {
 description = <<EOT
Name of the App Mesh service mesh. Must be between 1 and 255 characters.
FORCE-NEW — changing this destroys and recreates the mesh, which cascades to
every virtual node/router/gateway/service/route/gateway route in this module
(they are all keyed off mesh_name).
EOT
 type = string

 validation {
 condition = length(var.mesh_name) > 0 && length(var.mesh_name) <= 255
 error_message = "mesh_name must be between 1 and 255 characters."
 }
}

###############################################################################
# Mesh spec — egress filter and service discovery
###############################################################################

variable "egress_filter_type" {
 description = <<EOT
Egress filter type for the mesh (spec.egress_filter.type). SECURE DEFAULT:
"DROP_ALL" — a virtual node may only reach the backends it explicitly declares
via its `backend` block; anything else is dropped at the Envoy proxy. Set to
"ALLOW_ALL" to let virtual nodes reach any endpoint (documented exception —
weakens mesh-level egress control).
EOT
 type = string
 default = "DROP_ALL"

 validation {
 condition = contains(["ALLOW_ALL", "DROP_ALL"], var.egress_filter_type)
 error_message = "egress_filter_type must be ALLOW_ALL or DROP_ALL."
 }
}

variable "mesh_service_discovery_ip_preference" {
 description = <<EOT
IP version used to control traffic within the mesh (spec.service_discovery.ip_preference).
Null (default) leaves the AWS default. Valid values: IPv6_PREFERRED,
IPv4_PREFERRED, IPv4_ONLY, IPv6_ONLY.
EOT
 type = string
 default = null

 validation {
 condition = var.mesh_service_discovery_ip_preference == null || contains(["IPv6_PREFERRED", "IPv4_PREFERRED", "IPv4_ONLY", "IPv6_ONLY"], coalesce(var.mesh_service_discovery_ip_preference, "IPv4_PREFERRED"))
 error_message = "mesh_service_discovery_ip_preference must be one of: IPv6_PREFERRED, IPv4_PREFERRED, IPv4_ONLY, IPv6_ONLY (or null)."
 }
}

###############################################################################
# Virtual nodes — map(object), for_each, keyed by a caller-supplied stable name
#
# Each virtual node represents one logical service (or a version/variant of
# one) and is what the Envoy proxy sidecar registers as at runtime. name is
# FORCE-NEW on the resource.
###############################################################################

variable "virtual_nodes" {
 description = <<EOT
Map of App Mesh virtual nodes keyed by a stable caller name (the map key is
used as the App Mesh `name`; NOT the same as the Kubernetes/ECS service name,
though they are commonly aligned). FORCE-NEW per node — renaming a node
destroys and recreates it and anything referencing it by name (backends,
virtual services, routes).

 - listeners: list of inbound listeners (spec.listener; App Mesh permits
 multiple listener blocks per node). Each:
 - port_mapping: { port, protocol } — protocol one of http, http2,
 tcp, grpc (required).
 - health_check: { protocol, healthy_threshold, unhealthy_threshold,
 interval_millis, timeout_millis, path, port }.
 - connection_pool: per-protocol connection limits:
 { grpc = { max_requests }, http = { max_connections,
 max_pending_requests }, http2 = { max_requests },
 tcp = { max_connections } }.
 - outlier_detection: { max_server_errors, max_ejection_percent,
 base_ejection_duration = { unit, value },
 interval = { unit, value } }.
 - timeout: per-protocol idle/per_request timeouts:
 { grpc|http|http2 = { idle = {unit,value},
 per_request = {unit,value} }, tcp = { idle = {unit,value} } }.
 - tls: listener TLS termination. SECURE RECOMMENDATION:
 set mode = "STRICT" with an ACM-issued cert for
 any listener carrying PII-adjacent traffic;
 "PERMISSIVE" only during a migration window.
 { mode = DISABLED|PERMISSIVE|STRICT,
 certificate = { acm = { certificate_arn },
 file = { certificate_chain, private_key },
 sds = { secret_name } },
 validation = { subject_alternative_names = { match = { exact } },
 trust = { acm = { certificate_authority_arns },
 file = { certificate_chain },
 sds = { secret_name } } } }
 - backends: list of virtual services this node is allowed to call
 (spec.backend[*].virtual_service). Each:
 - virtual_service_name: FQDN-style name of the backend virtual service
 (must match an aws_appmesh_virtual_service name
 — wire via the sibling virtual_services map, or
 an external mesh's virtual service name).
 - client_policy_tls: optional outbound mTLS policy for this backend:
 { enforce (default true), ports,
 certificate = { file = {...}, sds = {...} },
 validation = { subject_alternative_names = {...},
 trust = { acm = {...}, file = {...}, sds = {...} } } }.
 - backend_defaults_client_policy_tls: default client_policy.tls applied to
 every backend that does not set its own (same shape as backends[*].client_policy_tls).
 - service_discovery: exactly one of:
 - dns: { hostname (required), ip_preference, response_type
 (LOADBALANCER|ENDPOINTS) }.
 - aws_cloud_map: { namespace_name, service_name (required),
 attributes (map, optional) } — wire namespace/service
 name from tf-mod-aws-service-discovery.
 - logging_access_log_path: Envoy access-log file path (e.g.
 "/dev/stdout" to flow into the container's
 awslogs driver). SECURE DEFAULT
 RECOMMENDATION: always set this for
 PII-adjacent services; null disables
 access logging.
 - logging_access_log_format_json: list of { key, value } JSON log-format
 fields (mutually exclusive with the text
 format below).
 - logging_access_log_format_text: plain-text log format string (1-1000 chars).
 - tags: extra tags merged over the module tags for this virtual node.
EOT
 type = map(object({
 listeners = optional(list(object({
 port_mapping = object({
 port = number
 protocol = string
 })
 health_check = optional(object({
 protocol = string
 healthy_threshold = number
 unhealthy_threshold = number
 interval_millis = number
 timeout_millis = number
 path = optional(string)
 port = optional(number)
 }))
 connection_pool = optional(object({
 grpc = optional(object({
 max_requests = number
 }))
 http = optional(object({
 max_connections = number
 max_pending_requests = optional(number)
 }))
 http2 = optional(object({
 max_requests = number
 }))
 tcp = optional(object({
 max_connections = number
 }))
 }))
 outlier_detection = optional(object({
 max_server_errors = number
 max_ejection_percent = number
 base_ejection_duration = object({
 unit = string
 value = number
 })
 interval = object({
 unit = string
 value = number
 })
 }))
 timeout = optional(object({
 grpc = optional(object({
 idle = optional(object({ unit = string, value = number }))
 per_request = optional(object({ unit = string, value = number }))
 }))
 http = optional(object({
 idle = optional(object({ unit = string, value = number }))
 per_request = optional(object({ unit = string, value = number }))
 }))
 http2 = optional(object({
 idle = optional(object({ unit = string, value = number }))
 per_request = optional(object({ unit = string, value = number }))
 }))
 tcp = optional(object({
 idle = optional(object({ unit = string, value = number }))
 }))
 }))
 tls = optional(object({
 mode = string
 certificate = object({
 acm = optional(object({
 certificate_arn = string
 }))
 file = optional(object({
 certificate_chain = string
 private_key = string
 }))
 sds = optional(object({
 secret_name = string
 }))
 })
 # NOTE: unlike client_policy.tls.validation.trust (below), the
 # LISTENER tls.validation.trust block does not support "acm" in the
 # provider schema — only file/sds. This is a genuine App Mesh API
 # asymmetry, not an oversight; see the Provider gotchas in SCOPE.md.
 validation = optional(object({
 subject_alternative_names = optional(object({
 match = object({
 exact = list(string)
 })
 }))
 trust = object({
 file = optional(object({
 certificate_chain = string
 }))
 sds = optional(object({
 secret_name = string
 }))
 })
 }))
 }))
 })), [])

 backends = optional(list(object({
 virtual_service_name = string
 client_policy_tls = optional(object({
 enforce = optional(bool, true)
 ports = optional(list(number))
 certificate = optional(object({
 file = optional(object({
 certificate_chain = string
 private_key = string
 }))
 sds = optional(object({
 secret_name = string
 }))
 }))
 validation = object({
 subject_alternative_names = optional(object({
 match = object({
 exact = list(string)
 })
 }))
 trust = object({
 acm = optional(object({
 certificate_authority_arns = list(string)
 }))
 file = optional(object({
 certificate_chain = string
 }))
 sds = optional(object({
 secret_name = string
 }))
 })
 })
 }))
 })), [])

 backend_defaults_client_policy_tls = optional(object({
 enforce = optional(bool, true)
 ports = optional(list(number))
 certificate = optional(object({
 file = optional(object({
 certificate_chain = string
 private_key = string
 }))
 sds = optional(object({
 secret_name = string
 }))
 }))
 validation = object({
 subject_alternative_names = optional(object({
 match = object({
 exact = list(string)
 })
 }))
 trust = object({
 acm = optional(object({
 certificate_authority_arns = list(string)
 }))
 file = optional(object({
 certificate_chain = string
 }))
 sds = optional(object({
 secret_name = string
 }))
 })
 })
 }))

 service_discovery = optional(object({
 dns = optional(object({
 hostname = string
 ip_preference = optional(string)
 response_type = optional(string)
 }))
 aws_cloud_map = optional(object({
 namespace_name = string
 service_name = string
 attributes = optional(map(string), {})
 }))
 }))

 logging_access_log_path = optional(string)
 logging_access_log_format_json = optional(list(object({ key = string, value = string })), [])
 logging_access_log_format_text = optional(string)

 tags = optional(map(string), {})
 }))
 default = {}

 validation {
 condition = alltrue(flatten([
 for k, v in var.virtual_nodes: [
 for l in coalesce(v.listeners, []): contains(["http", "http2", "tcp", "grpc"], l.port_mapping.protocol)
 ]
 ]))
 error_message = "Each virtual_nodes[*].listeners[*].port_mapping.protocol must be one of: http, http2, tcp, grpc."
 }

 validation {
 condition = alltrue(flatten([
 for k, v in var.virtual_nodes: [
 for l in coalesce(v.listeners, []): l.tls == null || contains(["DISABLED", "PERMISSIVE", "STRICT"], l.tls.mode)
 ]
 ]))
 error_message = "Each virtual_nodes[*].listeners[*].tls.mode must be one of: DISABLED, PERMISSIVE, STRICT."
 }
}

###############################################################################
# Virtual routers — map(object), for_each
#
# A virtual router receives inbound traffic from other virtual nodes/gateways
# and dispatches it to one or more virtual nodes via routes (see var.routes).
###############################################################################

variable "virtual_routers" {
 description = <<EOT
Map of App Mesh virtual routers keyed by a stable caller name (the map key is
used as the App Mesh `name`). FORCE-NEW per router. App Mesh currently
supports one listener per virtual router.

 - listeners: list of { port_mapping = { port, protocol } }. protocol one of
 http, http2, tcp, grpc.
 - tags: extra tags merged over the module tags for this router.
EOT
 type = map(object({
 listeners = optional(list(object({
 port_mapping = object({
 port = number
 protocol = string
 })
 })), [])
 tags = optional(map(string), {})
 }))
 default = {}

 validation {
 condition = alltrue(flatten([
 for k, v in var.virtual_routers: [
 for l in coalesce(v.listeners, []): contains(["http", "http2", "tcp", "grpc"], l.port_mapping.protocol)
 ]
 ]))
 error_message = "Each virtual_routers[*].listeners[*].port_mapping.protocol must be one of: http, http2, tcp, grpc."
 }
}

###############################################################################
# Virtual gateways — map(object), for_each
#
# A virtual gateway is the mesh's ingress point for traffic originating
# OUTSIDE the mesh (e.g. from an ALB/NLB). App Mesh permits exactly one
# listener block per virtual gateway.
###############################################################################

variable "virtual_gateways" {
 description = <<EOT
Map of App Mesh virtual gateways keyed by a stable caller name (the map key is
used as the App Mesh `name`). FORCE-NEW per gateway. Exactly one `listener` is
required per virtual gateway.

 - listener: { port_mapping = { port, protocol (http|http2|tcp|grpc) },
 health_check = { protocol, healthy_threshold, unhealthy_threshold,
 interval_millis, timeout_millis, path, port },
 connection_pool = { grpc = {max_requests}, http = {max_connections,
 max_pending_requests}, http2 = {max_requests} },
 tls = { mode (DISABLED|PERMISSIVE|STRICT — SECURE RECOMMENDATION: STRICT
 with an ACM cert for internet-facing gateways),
 certificate = { acm = {certificate_arn}, file = {certificate_chain,
 private_key}, sds = {secret_name} },
 validation = { subject_alternative_names = {match={exact}},
 trust = { acm = {certificate_authority_arns}, file = {certificate_chain},
 sds = {secret_name} } } } }
 - backend_defaults_client_policy_tls: default outbound mTLS policy applied
 to backends this gateway routes to (same shape as virtual_nodes'
 backend_defaults_client_policy_tls).
 - logging_access_log_path: Envoy access-log file path (e.g. "/dev/stdout").
 SECURE DEFAULT RECOMMENDATION: always set for internet-facing gateways.
 - tags: extra tags merged over the module tags for this gateway.
EOT
 type = map(object({
 listener = object({
 port_mapping = object({
 port = number
 protocol = string
 })
 health_check = optional(object({
 protocol = string
 healthy_threshold = number
 unhealthy_threshold = number
 interval_millis = number
 timeout_millis = number
 path = optional(string)
 port = optional(number)
 }))
 connection_pool = optional(object({
 grpc = optional(object({
 max_requests = number
 }))
 http = optional(object({
 max_connections = number
 max_pending_requests = optional(number)
 }))
 http2 = optional(object({
 max_requests = number
 }))
 }))
 tls = optional(object({
 mode = string
 certificate = object({
 acm = optional(object({
 certificate_arn = string
 }))
 file = optional(object({
 certificate_chain = string
 private_key = string
 }))
 sds = optional(object({
 secret_name = string
 }))
 })
 # NOTE: unlike client_policy.tls.validation.trust (below), the
 # LISTENER tls.validation.trust block does not support "acm" in the
 # provider schema — only file/sds. See Provider gotchas in SCOPE.md.
 validation = optional(object({
 subject_alternative_names = optional(object({
 match = object({
 exact = list(string)
 })
 }))
 trust = object({
 file = optional(object({
 certificate_chain = string
 }))
 sds = optional(object({
 secret_name = string
 }))
 })
 }))
 }))
 })

 backend_defaults_client_policy_tls = optional(object({
 enforce = optional(bool, true)
 ports = optional(list(number))
 certificate = optional(object({
 file = optional(object({
 certificate_chain = string
 private_key = string
 }))
 sds = optional(object({
 secret_name = string
 }))
 }))
 validation = object({
 subject_alternative_names = optional(object({
 match = object({
 exact = list(string)
 })
 }))
 trust = object({
 acm = optional(object({
 certificate_authority_arns = list(string)
 }))
 file = optional(object({
 certificate_chain = string
 }))
 sds = optional(object({
 secret_name = string
 }))
 })
 })
 }))

 logging_access_log_path = optional(string)

 tags = optional(map(string), {})
 }))
 default = {}

 validation {
 condition = alltrue([for k, v in var.virtual_gateways: contains(["http", "http2", "tcp", "grpc"], v.listener.port_mapping.protocol)])
 error_message = "Each virtual_gateways[*].listener.port_mapping.protocol must be one of: http, http2, tcp, grpc."
 }

 validation {
 condition = alltrue([for k, v in var.virtual_gateways: v.listener.tls == null || contains(["DISABLED", "PERMISSIVE", "STRICT"], v.listener.tls.mode)])
 error_message = "Each virtual_gateways[*].listener.tls.mode must be one of: DISABLED, PERMISSIVE, STRICT."
 }
}

###############################################################################
# Virtual services — map(object), for_each
#
# A virtual service is the stable, client-facing name other virtual nodes call
# via `backend`. Its provider is EITHER a virtual router (for routed traffic)
# OR a single virtual node (for direct, unrouted traffic) — never both.
###############################################################################

variable "virtual_services" {
 description = <<EOT
Map of App Mesh virtual services keyed by a stable caller name (the map key is
used as the App Mesh `name` — conventionally a DNS-style FQDN such as
"payments.internal.mesh.local", matched by client virtual nodes' `backend`
entries). FORCE-NEW per service.

Set at most one of provider_virtual_node_key / provider_virtual_router_key
(referencing a key in var.virtual_nodes / var.virtual_routers respectively).
Leave both null for a virtual service with no provider configured yet.

 - provider_virtual_node_key: key into var.virtual_nodes — direct provider.
 - provider_virtual_router_key: key into var.virtual_routers — routed provider.
 - tags: extra tags merged over the module tags.
EOT
 type = map(object({
 provider_virtual_node_key = optional(string)
 provider_virtual_router_key = optional(string)
 tags = optional(map(string), {})
 }))
 default = {}

 validation {
 condition = alltrue([for k, v in var.virtual_services: !(v.provider_virtual_node_key != null && v.provider_virtual_router_key != null)])
 error_message = "Each virtual_services entry may set at most one of provider_virtual_node_key or provider_virtual_router_key, not both."
 }
}

###############################################################################
# Routes — map(object), for_each, attached to a virtual router
#
# Exactly one of http_route / http2_route / grpc_route / tcp_route should be
# set per route (the App Mesh API allows one route-type block per route).
###############################################################################

variable "routes" {
 description = <<EOT
Map of App Mesh routes keyed by a stable caller name (the map key is used as
the App Mesh route `name`). Each route attaches to one virtual router (by
sibling key) and sets exactly one of http_route / http2_route / grpc_route /
tcp_route. Weighted targets reference virtual nodes by sibling key (in
var.virtual_nodes).

 - virtual_router_key: key into var.virtual_routers this route attaches to (required).
 - priority: 0-1000, lower = higher priority. Null lets App Mesh order arbitrarily.
 - http_route / http2_route: {
 match: { prefix, path = {exact, regex}, method, scheme (http|https), port,
 headers = [{ name, invert, match = {exact,prefix,suffix,regex,
 range={start,end}} }], query_parameters = [{ name, match={exact} }] }
 action: { weighted_targets = [{ virtual_node_key, weight (0-100), port }] }
 retry_policy: { http_retry_events, tcp_retry_events, max_retries,
 per_retry_timeout = {unit,value} }
 timeout: { idle = {unit,value}, per_request = {unit,value} }
 }
 - grpc_route: {
 match: { service_name, method_name, port,
 metadata = [{ name, invert, match={exact,prefix,suffix,regex,
 range={start,end}} }] }
 action: { weighted_targets = [{ virtual_node_key, weight (0-100), port }] }
 retry_policy: { grpc_retry_events, http_retry_events, tcp_retry_events,
 max_retries, per_retry_timeout = {unit,value} }
 timeout: { idle = {unit,value}, per_request = {unit,value} }
 }
 - tcp_route: {
 action: { weighted_targets = [{ virtual_node_key, weight (0-100), port }] }
 timeout: { idle = {unit,value} }
 }
 - tags: extra tags merged over the module tags for this route.

SECURE-BY-DEFAULT RECOMMENDATION: pair http_route/http2_route/grpc_route with a
retry_policy (e.g. server-error/gateway-error events) for resilience against
transient upstream failures — see the README's retry-policy example.
EOT
 type = map(object({
 virtual_router_key = string
 priority = optional(number)

 http_route = optional(object({
 match = object({
 prefix = optional(string)
 path = optional(object({
 exact = optional(string)
 regex = optional(string)
 }))
 method = optional(string)
 scheme = optional(string)
 port = optional(number)
 headers = optional(list(object({
 name = string
 invert = optional(bool, false)
 match = optional(object({
 exact = optional(string)
 prefix = optional(string)
 suffix = optional(string)
 regex = optional(string)
 range = optional(object({
 start = number
 end = number
 }))
 }))
 })), [])
 query_parameters = optional(list(object({
 name = string
 match = optional(object({
 exact = optional(string)
 }))
 })), [])
 })
 action = object({
 weighted_targets = list(object({
 virtual_node_key = string
 weight = number
 port = optional(number)
 }))
 })
 retry_policy = optional(object({
 http_retry_events = optional(list(string), [])
 tcp_retry_events = optional(list(string), [])
 max_retries = number
 per_retry_timeout = object({
 unit = string
 value = number
 })
 }))
 timeout = optional(object({
 idle = optional(object({ unit = string, value = number }))
 per_request = optional(object({ unit = string, value = number }))
 }))
 }))

 http2_route = optional(object({
 match = object({
 prefix = optional(string)
 path = optional(object({
 exact = optional(string)
 regex = optional(string)
 }))
 method = optional(string)
 scheme = optional(string)
 port = optional(number)
 headers = optional(list(object({
 name = string
 invert = optional(bool, false)
 match = optional(object({
 exact = optional(string)
 prefix = optional(string)
 suffix = optional(string)
 regex = optional(string)
 range = optional(object({
 start = number
 end = number
 }))
 }))
 })), [])
 query_parameters = optional(list(object({
 name = string
 match = optional(object({
 exact = optional(string)
 }))
 })), [])
 })
 action = object({
 weighted_targets = list(object({
 virtual_node_key = string
 weight = number
 port = optional(number)
 }))
 })
 retry_policy = optional(object({
 http_retry_events = optional(list(string), [])
 tcp_retry_events = optional(list(string), [])
 max_retries = number
 per_retry_timeout = object({
 unit = string
 value = number
 })
 }))
 timeout = optional(object({
 idle = optional(object({ unit = string, value = number }))
 per_request = optional(object({ unit = string, value = number }))
 }))
 }))

 grpc_route = optional(object({
 match = object({
 service_name = optional(string)
 method_name = optional(string)
 port = optional(number)
 metadata = optional(list(object({
 name = string
 invert = optional(bool, false)
 match = optional(object({
 exact = optional(string)
 prefix = optional(string)
 suffix = optional(string)
 regex = optional(string)
 range = optional(object({
 start = number
 end = number
 }))
 }))
 })), [])
 })
 action = object({
 weighted_targets = list(object({
 virtual_node_key = string
 weight = number
 port = optional(number)
 }))
 })
 retry_policy = optional(object({
 grpc_retry_events = optional(list(string), [])
 http_retry_events = optional(list(string), [])
 tcp_retry_events = optional(list(string), [])
 max_retries = number
 per_retry_timeout = object({
 unit = string
 value = number
 })
 }))
 timeout = optional(object({
 idle = optional(object({ unit = string, value = number }))
 per_request = optional(object({ unit = string, value = number }))
 }))
 }))

 tcp_route = optional(object({
 action = object({
 weighted_targets = list(object({
 virtual_node_key = string
 weight = number
 port = optional(number)
 }))
 })
 timeout = optional(object({
 idle = optional(object({ unit = string, value = number }))
 }))
 }))

 tags = optional(map(string), {})
 }))
 default = {}

 validation {
 condition = alltrue([for k, v in var.routes: v.priority == null || (v.priority >= 0 && v.priority <= 1000)])
 error_message = "Each routes[*].priority must be between 0 and 1000 (or null)."
 }

 validation {
 condition = alltrue([
 for k, v in var.routes: length(compact([
 v.http_route != null ? "x": "",
 v.http2_route != null ? "x": "",
 v.grpc_route != null ? "x": "",
 v.tcp_route != null ? "x": "",
 ])) == 1
 ])
 error_message = "Each routes entry must set exactly one of http_route, http2_route, grpc_route, or tcp_route."
 }
}

###############################################################################
# Gateway routes — map(object), for_each, attached to a virtual gateway
#
# Exactly one of http_route / http2_route / grpc_route should be set per
# gateway route. The action target is always a virtual service (by sibling
# key in var.virtual_services), never a virtual node directly.
###############################################################################

variable "gateway_routes" {
 description = <<EOT
Map of App Mesh gateway routes keyed by a stable caller name (the map key is
used as the App Mesh gateway-route `name`). Each attaches to one virtual
gateway (by sibling key) and sets exactly one of http_route / http2_route /
grpc_route. The action target is a virtual service (by sibling key in
var.virtual_services) — gateway routes never target a virtual node directly.

 - virtual_gateway_key: key into var.virtual_gateways this route attaches to (required).
 - priority: 0-1000, lower = higher priority. Null lets App Mesh order arbitrarily.
 - http_route / http2_route: {
 match: { prefix, path={exact,regex}, port, hostname={exact,suffix},
 headers=[{name,invert,match={exact,prefix,suffix,regex,range={start,end}}}],
 query_parameters=[{name,match={exact}}] }
 action: { target = { virtual_service_key, port },
 rewrite = { hostname={default_target_hostname (ENABLED|DISABLED)},
 path={exact}, prefix={default_prefix (ENABLED|DISABLED), value} } }
 }
 - grpc_route: {
 match: { service_name (required), port }
 action: { target = { virtual_service_key, port } }
 (no "rewrite" — that is HTTP/HTTP2-only in the provider schema)
 }
 - tags: extra tags merged over the module tags for this gateway route.
EOT
 type = map(object({
 virtual_gateway_key = string
 priority = optional(number)

 http_route = optional(object({
 match = object({
 prefix = optional(string)
 path = optional(object({
 exact = optional(string)
 regex = optional(string)
 }))
 port = optional(number)
 hostname = optional(object({
 exact = optional(string)
 suffix = optional(string)
 }))
 headers = optional(list(object({
 name = string
 invert = optional(bool, false)
 match = optional(object({
 exact = optional(string)
 prefix = optional(string)
 suffix = optional(string)
 regex = optional(string)
 range = optional(object({
 start = number
 end = number
 }))
 }))
 })), [])
 query_parameters = optional(list(object({
 name = string
 match = optional(object({
 exact = optional(string)
 }))
 })), [])
 })
 action = object({
 target = object({
 virtual_service_key = string
 port = optional(number)
 })
 rewrite = optional(object({
 hostname = optional(object({
 default_target_hostname = string
 }))
 path = optional(object({
 exact = string
 }))
 prefix = optional(object({
 default_prefix = optional(string)
 value = optional(string)
 }))
 }))
 })
 }))

 http2_route = optional(object({
 match = object({
 prefix = optional(string)
 path = optional(object({
 exact = optional(string)
 regex = optional(string)
 }))
 port = optional(number)
 hostname = optional(object({
 exact = optional(string)
 suffix = optional(string)
 }))
 headers = optional(list(object({
 name = string
 invert = optional(bool, false)
 match = optional(object({
 exact = optional(string)
 prefix = optional(string)
 suffix = optional(string)
 regex = optional(string)
 range = optional(object({
 start = number
 end = number
 }))
 }))
 })), [])
 query_parameters = optional(list(object({
 name = string
 match = optional(object({
 exact = optional(string)
 }))
 })), [])
 })
 action = object({
 target = object({
 virtual_service_key = string
 port = optional(number)
 })
 rewrite = optional(object({
 hostname = optional(object({
 default_target_hostname = string
 }))
 path = optional(object({
 exact = string
 }))
 prefix = optional(object({
 default_prefix = optional(string)
 value = optional(string)
 }))
 }))
 })
 }))

 # NOTE: unlike http_route/http2_route, the grpc_route action in the
 # provider schema supports only "target" — no "rewrite" (hostname/path/
 # prefix rewriting is an HTTP-specific concept). See SCOPE.md gotchas.
 grpc_route = optional(object({
 match = object({
 service_name = string
 port = optional(number)
 })
 action = object({
 target = object({
 virtual_service_key = string
 port = optional(number)
 })
 })
 }))

 tags = optional(map(string), {})
 }))
 default = {}

 validation {
 condition = alltrue([for k, v in var.gateway_routes: v.priority == null || (v.priority >= 0 && v.priority <= 1000)])
 error_message = "Each gateway_routes[*].priority must be between 0 and 1000 (or null)."
 }

 validation {
 condition = alltrue([
 for k, v in var.gateway_routes: length(compact([
 v.http_route != null ? "x": "",
 v.http2_route != null ? "x": "",
 v.grpc_route != null ? "x": "",
 ])) == 1
 ])
 error_message = "Each gateway_routes entry must set exactly one of http_route, http2_route, or grpc_route."
 }
}

###############################################################################
# Universal tail
#
# NOTE: aws_appmesh_* resources have NO configurable `timeouts` block in the
# provider schema (create/update/delete complete synchronously via the App
# Mesh control-plane API) — this module intentionally omits a `timeouts`
# variable.
###############################################################################

variable "tags" {
 description = <<EOT
A map of tags to assign to all taggable resources created by this module (the
mesh, virtual nodes, virtual routers, virtual gateways, virtual services,
routes, and gateway routes). These merge with provider-level default_tags;
resource tags win on key conflict. Per-item tags on each child collection
merge over this map. The computed tags_all output (on the mesh) reflects the
merged set.
EOT
 type = map(string)
 default = {}
}
