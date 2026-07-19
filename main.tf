###############################################################################
# Service mesh (keystone)
#
# name is FORCE-NEW — renaming the mesh destroys and recreates every virtual
# node/router/gateway/service/route/gateway route in this module. The egress
# filter default (DROP_ALL) is rendered explicitly rather than relying on the
# provider's implicit default, per the secure-by-default posture.
###############################################################################

resource "aws_appmesh_mesh" "this" {
 name = var.mesh_name

 spec {
 egress_filter {
 type = var.egress_filter_type
 }

 dynamic "service_discovery" {
 for_each = var.mesh_service_discovery_ip_preference != null ? [var.mesh_service_discovery_ip_preference]: []

 content {
 ip_preference = service_discovery.value
 }
 }
 }

 tags = var.tags
}

###############################################################################
# Virtual nodes
#
# name and mesh_name are FORCE-NEW. Each node's listeners/backends/service
# discovery/logging are rendered from deeply-typed nested objects mirroring
# the provider schema exactly.
###############################################################################

resource "aws_appmesh_virtual_node" "this" {
 for_each = var.virtual_nodes

 name = each.key
 mesh_name = aws_appmesh_mesh.this.name

 spec {
 dynamic "listener" {
 for_each = each.value.listeners

 content {
 port_mapping {
 port = listener.value.port_mapping.port
 protocol = listener.value.port_mapping.protocol
 }

 dynamic "health_check" {
 for_each = listener.value.health_check != null ? [listener.value.health_check]: []

 content {
 protocol = health_check.value.protocol
 healthy_threshold = health_check.value.healthy_threshold
 unhealthy_threshold = health_check.value.unhealthy_threshold
 interval_millis = health_check.value.interval_millis
 timeout_millis = health_check.value.timeout_millis
 path = try(health_check.value.path, null)
 port = try(health_check.value.port, null)
 }
 }

 dynamic "connection_pool" {
 for_each = listener.value.connection_pool != null ? [listener.value.connection_pool]: []

 content {
 dynamic "grpc" {
 for_each = connection_pool.value.grpc != null ? [connection_pool.value.grpc]: []
 content {
 max_requests = grpc.value.max_requests
 }
 }

 dynamic "http" {
 for_each = connection_pool.value.http != null ? [connection_pool.value.http]: []
 content {
 max_connections = http.value.max_connections
 max_pending_requests = try(http.value.max_pending_requests, null)
 }
 }

 dynamic "http2" {
 for_each = connection_pool.value.http2 != null ? [connection_pool.value.http2]: []
 content {
 max_requests = http2.value.max_requests
 }
 }

 dynamic "tcp" {
 for_each = connection_pool.value.tcp != null ? [connection_pool.value.tcp]: []
 content {
 max_connections = tcp.value.max_connections
 }
 }
 }
 }

 dynamic "outlier_detection" {
 for_each = listener.value.outlier_detection != null ? [listener.value.outlier_detection]: []

 content {
 max_server_errors = outlier_detection.value.max_server_errors
 max_ejection_percent = outlier_detection.value.max_ejection_percent

 base_ejection_duration {
 unit = outlier_detection.value.base_ejection_duration.unit
 value = outlier_detection.value.base_ejection_duration.value
 }

 interval {
 unit = outlier_detection.value.interval.unit
 value = outlier_detection.value.interval.value
 }
 }
 }

 dynamic "timeout" {
 for_each = listener.value.timeout != null ? [listener.value.timeout]: []

 content {
 dynamic "grpc" {
 for_each = timeout.value.grpc != null ? [timeout.value.grpc]: []
 content {
 dynamic "idle" {
 for_each = grpc.value.idle != null ? [grpc.value.idle]: []
 content {
 unit = idle.value.unit
 value = idle.value.value
 }
 }
 dynamic "per_request" {
 for_each = grpc.value.per_request != null ? [grpc.value.per_request]: []
 content {
 unit = per_request.value.unit
 value = per_request.value.value
 }
 }
 }
 }

 dynamic "http" {
 for_each = timeout.value.http != null ? [timeout.value.http]: []
 content {
 dynamic "idle" {
 for_each = http.value.idle != null ? [http.value.idle]: []
 content {
 unit = idle.value.unit
 value = idle.value.value
 }
 }
 dynamic "per_request" {
 for_each = http.value.per_request != null ? [http.value.per_request]: []
 content {
 unit = per_request.value.unit
 value = per_request.value.value
 }
 }
 }
 }

 dynamic "http2" {
 for_each = timeout.value.http2 != null ? [timeout.value.http2]: []
 content {
 dynamic "idle" {
 for_each = http2.value.idle != null ? [http2.value.idle]: []
 content {
 unit = idle.value.unit
 value = idle.value.value
 }
 }
 dynamic "per_request" {
 for_each = http2.value.per_request != null ? [http2.value.per_request]: []
 content {
 unit = per_request.value.unit
 value = per_request.value.value
 }
 }
 }
 }

 dynamic "tcp" {
 for_each = timeout.value.tcp != null ? [timeout.value.tcp]: []
 content {
 dynamic "idle" {
 for_each = tcp.value.idle != null ? [tcp.value.idle]: []
 content {
 unit = idle.value.unit
 value = idle.value.value
 }
 }
 }
 }
 }
 }

 dynamic "tls" {
 for_each = listener.value.tls != null ? [listener.value.tls]: []

 content {
 mode = tls.value.mode

 certificate {
 dynamic "acm" {
 for_each = tls.value.certificate.acm != null ? [tls.value.certificate.acm]: []
 content {
 certificate_arn = acm.value.certificate_arn
 }
 }
 dynamic "file" {
 for_each = tls.value.certificate.file != null ? [tls.value.certificate.file]: []
 content {
 certificate_chain = file.value.certificate_chain
 private_key = file.value.private_key
 }
 }
 dynamic "sds" {
 for_each = tls.value.certificate.sds != null ? [tls.value.certificate.sds]: []
 content {
 secret_name = sds.value.secret_name
 }
 }
 }

 dynamic "validation" {
 for_each = tls.value.validation != null ? [tls.value.validation]: []

 content {
 dynamic "subject_alternative_names" {
 for_each = validation.value.subject_alternative_names != null ? [validation.value.subject_alternative_names]: []
 content {
 match {
 exact = subject_alternative_names.value.match.exact
 }
 }
 }

 trust {
 # Listener-context trust supports only file/sds (no "acm") in the
 # provider schema — see the SCOPE.md Provider gotchas note.
 dynamic "file" {
 for_each = validation.value.trust.file != null ? [validation.value.trust.file]: []
 content {
 certificate_chain = file.value.certificate_chain
 }
 }
 dynamic "sds" {
 for_each = validation.value.trust.sds != null ? [validation.value.trust.sds]: []
 content {
 secret_name = sds.value.secret_name
 }
 }
 }
 }
 }
 }
 }
 }
 }

 dynamic "backend" {
 for_each = each.value.backends

 content {
 virtual_service {
 virtual_service_name = backend.value.virtual_service_name

 dynamic "client_policy" {
 for_each = backend.value.client_policy_tls != null ? [backend.value.client_policy_tls]: []

 content {
 tls {
 enforce = try(client_policy.value.enforce, true)
 ports = try(client_policy.value.ports, null)

 dynamic "certificate" {
 for_each = client_policy.value.certificate != null ? [client_policy.value.certificate]: []
 content {
 dynamic "file" {
 for_each = certificate.value.file != null ? [certificate.value.file]: []
 content {
 certificate_chain = file.value.certificate_chain
 private_key = file.value.private_key
 }
 }
 dynamic "sds" {
 for_each = certificate.value.sds != null ? [certificate.value.sds]: []
 content {
 secret_name = sds.value.secret_name
 }
 }
 }
 }

 validation {
 dynamic "subject_alternative_names" {
 for_each = client_policy.value.validation.subject_alternative_names != null ? [client_policy.value.validation.subject_alternative_names]: []
 content {
 match {
 exact = subject_alternative_names.value.match.exact
 }
 }
 }

 trust {
 dynamic "acm" {
 for_each = client_policy.value.validation.trust.acm != null ? [client_policy.value.validation.trust.acm]: []
 content {
 certificate_authority_arns = acm.value.certificate_authority_arns
 }
 }
 dynamic "file" {
 for_each = client_policy.value.validation.trust.file != null ? [client_policy.value.validation.trust.file]: []
 content {
 certificate_chain = file.value.certificate_chain
 }
 }
 dynamic "sds" {
 for_each = client_policy.value.validation.trust.sds != null ? [client_policy.value.validation.trust.sds]: []
 content {
 secret_name = sds.value.secret_name
 }
 }
 }
 }
 }
 }
 }
 }
 }
 }

 dynamic "backend_defaults" {
 for_each = each.value.backend_defaults_client_policy_tls != null ? { this = each.value.backend_defaults_client_policy_tls }: {}

 content {
 client_policy {
 tls {
 enforce = try(backend_defaults.value.enforce, true)
 ports = try(backend_defaults.value.ports, null)

 dynamic "certificate" {
 for_each = backend_defaults.value.certificate != null ? [backend_defaults.value.certificate]: []
 content {
 dynamic "file" {
 for_each = certificate.value.file != null ? [certificate.value.file]: []
 content {
 certificate_chain = file.value.certificate_chain
 private_key = file.value.private_key
 }
 }
 dynamic "sds" {
 for_each = certificate.value.sds != null ? [certificate.value.sds]: []
 content {
 secret_name = sds.value.secret_name
 }
 }
 }
 }

 validation {
 dynamic "subject_alternative_names" {
 for_each = backend_defaults.value.validation.subject_alternative_names != null ? [backend_defaults.value.validation.subject_alternative_names]: []
 content {
 match {
 exact = subject_alternative_names.value.match.exact
 }
 }
 }

 trust {
 dynamic "acm" {
 for_each = backend_defaults.value.validation.trust.acm != null ? [backend_defaults.value.validation.trust.acm]: []
 content {
 certificate_authority_arns = acm.value.certificate_authority_arns
 }
 }
 dynamic "file" {
 for_each = backend_defaults.value.validation.trust.file != null ? [backend_defaults.value.validation.trust.file]: []
 content {
 certificate_chain = file.value.certificate_chain
 }
 }
 dynamic "sds" {
 for_each = backend_defaults.value.validation.trust.sds != null ? [backend_defaults.value.validation.trust.sds]: []
 content {
 secret_name = sds.value.secret_name
 }
 }
 }
 }
 }
 }
 }
 }

 dynamic "service_discovery" {
 for_each = each.value.service_discovery != null ? [each.value.service_discovery]: []

 content {
 dynamic "dns" {
 for_each = service_discovery.value.dns != null ? [service_discovery.value.dns]: []
 content {
 hostname = dns.value.hostname
 ip_preference = try(dns.value.ip_preference, null)
 response_type = try(dns.value.response_type, null)
 }
 }

 dynamic "aws_cloud_map" {
 for_each = service_discovery.value.aws_cloud_map != null ? [service_discovery.value.aws_cloud_map]: []
 content {
 namespace_name = aws_cloud_map.value.namespace_name
 service_name = aws_cloud_map.value.service_name
 attributes = try(aws_cloud_map.value.attributes, null)
 }
 }
 }
 }

 dynamic "logging" {
 for_each = each.value.logging_access_log_path != null ? { this = each.value }: {}

 content {
 access_log {
 file {
 path = logging.value.logging_access_log_path

 dynamic "format" {
 for_each = (length(logging.value.logging_access_log_format_json) > 0 || logging.value.logging_access_log_format_text != null) ? [1]: []

 content {
 dynamic "json" {
 for_each = logging.value.logging_access_log_format_json
 content {
 key = json.value.key
 value = json.value.value
 }
 }
 text = logging.value.logging_access_log_format_text
 }
 }
 }
 }
 }
 }
 }

 tags = merge(var.tags, each.value.tags)
}

###############################################################################
# Virtual routers
#
# name and mesh_name are FORCE-NEW. App Mesh currently supports one listener
# per virtual router, but the schema itself allows the block to repeat, so it
# is rendered via for_each for forward compatibility.
###############################################################################

resource "aws_appmesh_virtual_router" "this" {
 for_each = var.virtual_routers

 name = each.key
 mesh_name = aws_appmesh_mesh.this.name

 spec {
 dynamic "listener" {
 for_each = each.value.listeners

 content {
 port_mapping {
 port = listener.value.port_mapping.port
 protocol = listener.value.port_mapping.protocol
 }
 }
 }
 }

 tags = merge(var.tags, each.value.tags)
}

###############################################################################
# Virtual gateways
#
# name and mesh_name are FORCE-NEW. Exactly one listener is required per
# virtual gateway (rendered as a static block, not dynamic, since the schema
# requires it).
###############################################################################

resource "aws_appmesh_virtual_gateway" "this" {
 for_each = var.virtual_gateways

 name = each.key
 mesh_name = aws_appmesh_mesh.this.name

 spec {
 listener {
 port_mapping {
 port = each.value.listener.port_mapping.port
 protocol = each.value.listener.port_mapping.protocol
 }

 dynamic "health_check" {
 for_each = each.value.listener.health_check != null ? [each.value.listener.health_check]: []

 content {
 protocol = health_check.value.protocol
 healthy_threshold = health_check.value.healthy_threshold
 unhealthy_threshold = health_check.value.unhealthy_threshold
 interval_millis = health_check.value.interval_millis
 timeout_millis = health_check.value.timeout_millis
 path = try(health_check.value.path, null)
 port = try(health_check.value.port, null)
 }
 }

 dynamic "connection_pool" {
 for_each = each.value.listener.connection_pool != null ? [each.value.listener.connection_pool]: []

 content {
 dynamic "grpc" {
 for_each = connection_pool.value.grpc != null ? [connection_pool.value.grpc]: []
 content {
 max_requests = grpc.value.max_requests
 }
 }

 dynamic "http" {
 for_each = connection_pool.value.http != null ? [connection_pool.value.http]: []
 content {
 max_connections = http.value.max_connections
 max_pending_requests = try(http.value.max_pending_requests, null)
 }
 }

 dynamic "http2" {
 for_each = connection_pool.value.http2 != null ? [connection_pool.value.http2]: []
 content {
 max_requests = http2.value.max_requests
 }
 }
 }
 }

 dynamic "tls" {
 for_each = each.value.listener.tls != null ? [each.value.listener.tls]: []

 content {
 mode = tls.value.mode

 certificate {
 dynamic "acm" {
 for_each = tls.value.certificate.acm != null ? [tls.value.certificate.acm]: []
 content {
 certificate_arn = acm.value.certificate_arn
 }
 }
 dynamic "file" {
 for_each = tls.value.certificate.file != null ? [tls.value.certificate.file]: []
 content {
 certificate_chain = file.value.certificate_chain
 private_key = file.value.private_key
 }
 }
 dynamic "sds" {
 for_each = tls.value.certificate.sds != null ? [tls.value.certificate.sds]: []
 content {
 secret_name = sds.value.secret_name
 }
 }
 }

 dynamic "validation" {
 for_each = tls.value.validation != null ? [tls.value.validation]: []

 content {
 dynamic "subject_alternative_names" {
 for_each = validation.value.subject_alternative_names != null ? [validation.value.subject_alternative_names]: []
 content {
 match {
 exact = subject_alternative_names.value.match.exact
 }
 }
 }

 trust {
 # Listener-context trust supports only file/sds (no "acm") in the
 # provider schema — see the SCOPE.md Provider gotchas note.
 dynamic "file" {
 for_each = validation.value.trust.file != null ? [validation.value.trust.file]: []
 content {
 certificate_chain = file.value.certificate_chain
 }
 }
 dynamic "sds" {
 for_each = validation.value.trust.sds != null ? [validation.value.trust.sds]: []
 content {
 secret_name = sds.value.secret_name
 }
 }
 }
 }
 }
 }
 }
 }

 dynamic "backend_defaults" {
 for_each = each.value.backend_defaults_client_policy_tls != null ? { this = each.value.backend_defaults_client_policy_tls }: {}

 content {
 client_policy {
 tls {
 enforce = try(backend_defaults.value.enforce, true)
 ports = try(backend_defaults.value.ports, null)

 dynamic "certificate" {
 for_each = backend_defaults.value.certificate != null ? [backend_defaults.value.certificate]: []
 content {
 dynamic "file" {
 for_each = certificate.value.file != null ? [certificate.value.file]: []
 content {
 certificate_chain = file.value.certificate_chain
 private_key = file.value.private_key
 }
 }
 dynamic "sds" {
 for_each = certificate.value.sds != null ? [certificate.value.sds]: []
 content {
 secret_name = sds.value.secret_name
 }
 }
 }
 }

 validation {
 dynamic "subject_alternative_names" {
 for_each = backend_defaults.value.validation.subject_alternative_names != null ? [backend_defaults.value.validation.subject_alternative_names]: []
 content {
 match {
 exact = subject_alternative_names.value.match.exact
 }
 }
 }

 trust {
 dynamic "acm" {
 for_each = backend_defaults.value.validation.trust.acm != null ? [backend_defaults.value.validation.trust.acm]: []
 content {
 certificate_authority_arns = acm.value.certificate_authority_arns
 }
 }
 dynamic "file" {
 for_each = backend_defaults.value.validation.trust.file != null ? [backend_defaults.value.validation.trust.file]: []
 content {
 certificate_chain = file.value.certificate_chain
 }
 }
 dynamic "sds" {
 for_each = backend_defaults.value.validation.trust.sds != null ? [backend_defaults.value.validation.trust.sds]: []
 content {
 secret_name = sds.value.secret_name
 }
 }
 }
 }
 }
 }
 }
 }

 dynamic "logging" {
 for_each = each.value.logging_access_log_path != null ? { this = each.value.logging_access_log_path }: {}

 content {
 access_log {
 file {
 path = logging.value
 }
 }
 }
 }
 }

 tags = merge(var.tags, each.value.tags)
}

###############################################################################
# Virtual services
#
# name and mesh_name are FORCE-NEW. The provider block references a virtual
# node or virtual router by NAME — always via the resource attribute (never a
# bare caller string) so Terraform's dependency graph, not creation-order
# luck, governs apply order.
###############################################################################

resource "aws_appmesh_virtual_service" "this" {
 for_each = var.virtual_services

 name = each.key
 mesh_name = aws_appmesh_mesh.this.name

 spec {
 dynamic "provider" {
 for_each = (each.value.provider_virtual_node_key != null || each.value.provider_virtual_router_key != null) ? { this = each.value }: {}

 content {
 dynamic "virtual_node" {
 for_each = provider.value.provider_virtual_node_key != null ? { this = provider.value.provider_virtual_node_key }: {}
 content {
 virtual_node_name = aws_appmesh_virtual_node.this[virtual_node.value].name
 }
 }

 dynamic "virtual_router" {
 for_each = provider.value.provider_virtual_router_key != null ? { this = provider.value.provider_virtual_router_key }: {}
 content {
 virtual_router_name = aws_appmesh_virtual_router.this[virtual_router.value].name
 }
 }
 }
 }
 }

 tags = merge(var.tags, each.value.tags)
}

###############################################################################
# Routes
#
# name, mesh_name, and virtual_router_name are FORCE-NEW. Exactly one of
# http_route/http2_route/grpc_route/tcp_route is set per entry (enforced by
# variable validation). Weighted targets reference a sibling virtual node by
# NAME via the resource attribute, not a bare caller string.
###############################################################################

resource "aws_appmesh_route" "this" {
 for_each = var.routes

 name = each.key
 mesh_name = aws_appmesh_mesh.this.name
 virtual_router_name = aws_appmesh_virtual_router.this[each.value.virtual_router_key].name

 spec {
 priority = try(each.value.priority, null)

 dynamic "http_route" {
 for_each = each.value.http_route != null ? [each.value.http_route]: []

 content {
 match {
 prefix = try(http_route.value.match.prefix, null)
 method = try(http_route.value.match.method, null)
 scheme = try(http_route.value.match.scheme, null)
 port = try(http_route.value.match.port, null)

 dynamic "path" {
 for_each = http_route.value.match.path != null ? [http_route.value.match.path]: []
 content {
 exact = try(path.value.exact, null)
 regex = try(path.value.regex, null)
 }
 }

 dynamic "header" {
 for_each = http_route.value.match.headers
 content {
 name = header.value.name
 invert = try(header.value.invert, false)

 dynamic "match" {
 for_each = header.value.match != null ? [header.value.match]: []
 content {
 exact = try(match.value.exact, null)
 prefix = try(match.value.prefix, null)
 suffix = try(match.value.suffix, null)
 regex = try(match.value.regex, null)

 dynamic "range" {
 for_each = match.value.range != null ? [match.value.range]: []
 content {
 start = range.value.start
 end = range.value.end
 }
 }
 }
 }
 }
 }

 dynamic "query_parameter" {
 for_each = http_route.value.match.query_parameters
 content {
 name = query_parameter.value.name

 dynamic "match" {
 for_each = query_parameter.value.match != null ? [query_parameter.value.match]: []
 content {
 exact = try(match.value.exact, null)
 }
 }
 }
 }
 }

 action {
 dynamic "weighted_target" {
 for_each = http_route.value.action.weighted_targets
 content {
 virtual_node = aws_appmesh_virtual_node.this[weighted_target.value.virtual_node_key].name
 weight = weighted_target.value.weight
 port = try(weighted_target.value.port, null)
 }
 }
 }

 dynamic "retry_policy" {
 for_each = http_route.value.retry_policy != null ? [http_route.value.retry_policy]: []

 content {
 http_retry_events = try(retry_policy.value.http_retry_events, null)
 tcp_retry_events = try(retry_policy.value.tcp_retry_events, null)
 max_retries = retry_policy.value.max_retries

 per_retry_timeout {
 unit = retry_policy.value.per_retry_timeout.unit
 value = retry_policy.value.per_retry_timeout.value
 }
 }
 }

 dynamic "timeout" {
 for_each = http_route.value.timeout != null ? [http_route.value.timeout]: []

 content {
 dynamic "idle" {
 for_each = timeout.value.idle != null ? [timeout.value.idle]: []
 content {
 unit = idle.value.unit
 value = idle.value.value
 }
 }
 dynamic "per_request" {
 for_each = timeout.value.per_request != null ? [timeout.value.per_request]: []
 content {
 unit = per_request.value.unit
 value = per_request.value.value
 }
 }
 }
 }
 }
 }

 dynamic "http2_route" {
 for_each = each.value.http2_route != null ? [each.value.http2_route]: []

 content {
 match {
 prefix = try(http2_route.value.match.prefix, null)
 method = try(http2_route.value.match.method, null)
 scheme = try(http2_route.value.match.scheme, null)
 port = try(http2_route.value.match.port, null)

 dynamic "path" {
 for_each = http2_route.value.match.path != null ? [http2_route.value.match.path]: []
 content {
 exact = try(path.value.exact, null)
 regex = try(path.value.regex, null)
 }
 }

 dynamic "header" {
 for_each = http2_route.value.match.headers
 content {
 name = header.value.name
 invert = try(header.value.invert, false)

 dynamic "match" {
 for_each = header.value.match != null ? [header.value.match]: []
 content {
 exact = try(match.value.exact, null)
 prefix = try(match.value.prefix, null)
 suffix = try(match.value.suffix, null)
 regex = try(match.value.regex, null)

 dynamic "range" {
 for_each = match.value.range != null ? [match.value.range]: []
 content {
 start = range.value.start
 end = range.value.end
 }
 }
 }
 }
 }
 }

 dynamic "query_parameter" {
 for_each = http2_route.value.match.query_parameters
 content {
 name = query_parameter.value.name

 dynamic "match" {
 for_each = query_parameter.value.match != null ? [query_parameter.value.match]: []
 content {
 exact = try(match.value.exact, null)
 }
 }
 }
 }
 }

 action {
 dynamic "weighted_target" {
 for_each = http2_route.value.action.weighted_targets
 content {
 virtual_node = aws_appmesh_virtual_node.this[weighted_target.value.virtual_node_key].name
 weight = weighted_target.value.weight
 port = try(weighted_target.value.port, null)
 }
 }
 }

 dynamic "retry_policy" {
 for_each = http2_route.value.retry_policy != null ? [http2_route.value.retry_policy]: []

 content {
 http_retry_events = try(retry_policy.value.http_retry_events, null)
 tcp_retry_events = try(retry_policy.value.tcp_retry_events, null)
 max_retries = retry_policy.value.max_retries

 per_retry_timeout {
 unit = retry_policy.value.per_retry_timeout.unit
 value = retry_policy.value.per_retry_timeout.value
 }
 }
 }

 dynamic "timeout" {
 for_each = http2_route.value.timeout != null ? [http2_route.value.timeout]: []

 content {
 dynamic "idle" {
 for_each = timeout.value.idle != null ? [timeout.value.idle]: []
 content {
 unit = idle.value.unit
 value = idle.value.value
 }
 }
 dynamic "per_request" {
 for_each = timeout.value.per_request != null ? [timeout.value.per_request]: []
 content {
 unit = per_request.value.unit
 value = per_request.value.value
 }
 }
 }
 }
 }
 }

 dynamic "grpc_route" {
 for_each = each.value.grpc_route != null ? [each.value.grpc_route]: []

 content {
 match {
 service_name = try(grpc_route.value.match.service_name, null)
 method_name = try(grpc_route.value.match.method_name, null)
 port = try(grpc_route.value.match.port, null)

 dynamic "metadata" {
 for_each = grpc_route.value.match.metadata
 content {
 name = metadata.value.name
 invert = try(metadata.value.invert, false)

 dynamic "match" {
 for_each = metadata.value.match != null ? [metadata.value.match]: []
 content {
 exact = try(match.value.exact, null)
 prefix = try(match.value.prefix, null)
 suffix = try(match.value.suffix, null)
 regex = try(match.value.regex, null)

 dynamic "range" {
 for_each = match.value.range != null ? [match.value.range]: []
 content {
 start = range.value.start
 end = range.value.end
 }
 }
 }
 }
 }
 }
 }

 action {
 dynamic "weighted_target" {
 for_each = grpc_route.value.action.weighted_targets
 content {
 virtual_node = aws_appmesh_virtual_node.this[weighted_target.value.virtual_node_key].name
 weight = weighted_target.value.weight
 port = try(weighted_target.value.port, null)
 }
 }
 }

 dynamic "retry_policy" {
 for_each = grpc_route.value.retry_policy != null ? [grpc_route.value.retry_policy]: []

 content {
 grpc_retry_events = try(retry_policy.value.grpc_retry_events, null)
 http_retry_events = try(retry_policy.value.http_retry_events, null)
 tcp_retry_events = try(retry_policy.value.tcp_retry_events, null)
 max_retries = retry_policy.value.max_retries

 per_retry_timeout {
 unit = retry_policy.value.per_retry_timeout.unit
 value = retry_policy.value.per_retry_timeout.value
 }
 }
 }

 dynamic "timeout" {
 for_each = grpc_route.value.timeout != null ? [grpc_route.value.timeout]: []

 content {
 dynamic "idle" {
 for_each = timeout.value.idle != null ? [timeout.value.idle]: []
 content {
 unit = idle.value.unit
 value = idle.value.value
 }
 }
 dynamic "per_request" {
 for_each = timeout.value.per_request != null ? [timeout.value.per_request]: []
 content {
 unit = per_request.value.unit
 value = per_request.value.value
 }
 }
 }
 }
 }
 }

 dynamic "tcp_route" {
 for_each = each.value.tcp_route != null ? [each.value.tcp_route]: []

 content {
 action {
 dynamic "weighted_target" {
 for_each = tcp_route.value.action.weighted_targets
 content {
 virtual_node = aws_appmesh_virtual_node.this[weighted_target.value.virtual_node_key].name
 weight = weighted_target.value.weight
 port = try(weighted_target.value.port, null)
 }
 }
 }

 dynamic "timeout" {
 for_each = tcp_route.value.timeout != null ? [tcp_route.value.timeout]: []
 content {
 dynamic "idle" {
 for_each = timeout.value.idle != null ? [timeout.value.idle]: []
 content {
 unit = idle.value.unit
 value = idle.value.value
 }
 }
 }
 }
 }
 }
 }

 tags = merge(var.tags, each.value.tags)
}

###############################################################################
# Gateway routes
#
# name, mesh_name, and virtual_gateway_name are FORCE-NEW. Exactly one of
# http_route/http2_route/grpc_route is set per entry (enforced by variable
# validation). The action target is always a virtual SERVICE by name via the
# resource attribute — gateway routes never target a virtual node directly.
###############################################################################

resource "aws_appmesh_gateway_route" "this" {
 for_each = var.gateway_routes

 name = each.key
 mesh_name = aws_appmesh_mesh.this.name
 virtual_gateway_name = aws_appmesh_virtual_gateway.this[each.value.virtual_gateway_key].name

 spec {
 priority = try(each.value.priority, null)

 dynamic "http_route" {
 for_each = each.value.http_route != null ? [each.value.http_route]: []

 content {
 match {
 prefix = try(http_route.value.match.prefix, null)
 port = try(http_route.value.match.port, null)

 dynamic "path" {
 for_each = http_route.value.match.path != null ? [http_route.value.match.path]: []
 content {
 exact = try(path.value.exact, null)
 regex = try(path.value.regex, null)
 }
 }

 dynamic "hostname" {
 for_each = http_route.value.match.hostname != null ? [http_route.value.match.hostname]: []
 content {
 exact = try(hostname.value.exact, null)
 suffix = try(hostname.value.suffix, null)
 }
 }

 dynamic "header" {
 for_each = http_route.value.match.headers
 content {
 name = header.value.name
 invert = try(header.value.invert, false)

 dynamic "match" {
 for_each = header.value.match != null ? [header.value.match]: []
 content {
 exact = try(match.value.exact, null)
 prefix = try(match.value.prefix, null)
 suffix = try(match.value.suffix, null)
 regex = try(match.value.regex, null)

 dynamic "range" {
 for_each = match.value.range != null ? [match.value.range]: []
 content {
 start = range.value.start
 end = range.value.end
 }
 }
 }
 }
 }
 }

 dynamic "query_parameter" {
 for_each = http_route.value.match.query_parameters
 content {
 name = query_parameter.value.name

 dynamic "match" {
 for_each = query_parameter.value.match != null ? [query_parameter.value.match]: []
 content {
 exact = try(match.value.exact, null)
 }
 }
 }
 }
 }

 action {
 target {
 port = try(http_route.value.action.target.port, null)

 virtual_service {
 virtual_service_name = aws_appmesh_virtual_service.this[http_route.value.action.target.virtual_service_key].name
 }
 }

 dynamic "rewrite" {
 for_each = http_route.value.action.rewrite != null ? [http_route.value.action.rewrite]: []

 content {
 dynamic "hostname" {
 for_each = rewrite.value.hostname != null ? [rewrite.value.hostname]: []
 content {
 default_target_hostname = hostname.value.default_target_hostname
 }
 }
 dynamic "path" {
 for_each = rewrite.value.path != null ? [rewrite.value.path]: []
 content {
 exact = path.value.exact
 }
 }
 dynamic "prefix" {
 for_each = rewrite.value.prefix != null ? [rewrite.value.prefix]: []
 content {
 default_prefix = try(prefix.value.default_prefix, null)
 value = try(prefix.value.value, null)
 }
 }
 }
 }
 }
 }
 }

 dynamic "http2_route" {
 for_each = each.value.http2_route != null ? [each.value.http2_route]: []

 content {
 match {
 prefix = try(http2_route.value.match.prefix, null)
 port = try(http2_route.value.match.port, null)

 dynamic "path" {
 for_each = http2_route.value.match.path != null ? [http2_route.value.match.path]: []
 content {
 exact = try(path.value.exact, null)
 regex = try(path.value.regex, null)
 }
 }

 dynamic "hostname" {
 for_each = http2_route.value.match.hostname != null ? [http2_route.value.match.hostname]: []
 content {
 exact = try(hostname.value.exact, null)
 suffix = try(hostname.value.suffix, null)
 }
 }

 dynamic "header" {
 for_each = http2_route.value.match.headers
 content {
 name = header.value.name
 invert = try(header.value.invert, false)

 dynamic "match" {
 for_each = header.value.match != null ? [header.value.match]: []
 content {
 exact = try(match.value.exact, null)
 prefix = try(match.value.prefix, null)
 suffix = try(match.value.suffix, null)
 regex = try(match.value.regex, null)

 dynamic "range" {
 for_each = match.value.range != null ? [match.value.range]: []
 content {
 start = range.value.start
 end = range.value.end
 }
 }
 }
 }
 }
 }

 dynamic "query_parameter" {
 for_each = http2_route.value.match.query_parameters
 content {
 name = query_parameter.value.name

 dynamic "match" {
 for_each = query_parameter.value.match != null ? [query_parameter.value.match]: []
 content {
 exact = try(match.value.exact, null)
 }
 }
 }
 }
 }

 action {
 target {
 port = try(http2_route.value.action.target.port, null)

 virtual_service {
 virtual_service_name = aws_appmesh_virtual_service.this[http2_route.value.action.target.virtual_service_key].name
 }
 }

 dynamic "rewrite" {
 for_each = http2_route.value.action.rewrite != null ? [http2_route.value.action.rewrite]: []

 content {
 dynamic "hostname" {
 for_each = rewrite.value.hostname != null ? [rewrite.value.hostname]: []
 content {
 default_target_hostname = hostname.value.default_target_hostname
 }
 }
 dynamic "path" {
 for_each = rewrite.value.path != null ? [rewrite.value.path]: []
 content {
 exact = path.value.exact
 }
 }
 dynamic "prefix" {
 for_each = rewrite.value.prefix != null ? [rewrite.value.prefix]: []
 content {
 default_prefix = try(prefix.value.default_prefix, null)
 value = try(prefix.value.value, null)
 }
 }
 }
 }
 }
 }
 }

 dynamic "grpc_route" {
 for_each = each.value.grpc_route != null ? [each.value.grpc_route]: []

 content {
 match {
 service_name = grpc_route.value.match.service_name
 port = try(grpc_route.value.match.port, null)
 }

 # NOTE: unlike http_route/http2_route, the grpc_route action in the
 # provider schema supports only "target" — no "rewrite" (hostname/path/
 # prefix rewriting is an HTTP-specific concept). See SCOPE.md gotchas.
 action {
 target {
 port = try(grpc_route.value.action.target.port, null)

 virtual_service {
 virtual_service_name = aws_appmesh_virtual_service.this[grpc_route.value.action.target.virtual_service_key].name
 }
 }
 }
 }
 }
 }

 tags = merge(var.tags, each.value.tags)
}
