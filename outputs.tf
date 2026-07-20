###############################################################################
# Primary outputs (id + arn) — mesh (keystone)
###############################################################################

output "id" {
 description = "The id of the App Mesh service mesh (= the mesh name)."
 value = aws_appmesh_mesh.this.id
}

output "arn" {
 description = <<EOT
The ARN of the App Mesh service mesh (cross-resource reference type:
arn:aws:appmesh:<region>:<account>:mesh/<name>). Consumed by IAM policies
scoping appmesh:* actions and by CloudWatch dashboards.
EOT
 value = aws_appmesh_mesh.this.arn
}

output "name" {
 description = "The name of the App Mesh service mesh."
 value = aws_appmesh_mesh.this.name
}

output "mesh_owner" {
 description = "AWS account ID of the service mesh's owner."
 value = aws_appmesh_mesh.this.mesh_owner
}

output "resource_owner" {
 description = "AWS account ID of the mesh resource's owner."
 value = aws_appmesh_mesh.this.resource_owner
}

###############################################################################
# Virtual nodes
###############################################################################

output "virtual_node_ids" {
 description = "Map of virtual-node key => id. Consumed by terraform-aws-ecs-service for cross-referencing."
 value = { for k, v in aws_appmesh_virtual_node.this: k => v.id }
}

output "virtual_node_arns" {
 description = <<EOT
Map of virtual-node key => ARN. Wire into terraform-aws-ecs-service's Envoy
proxy container (APPMESH_RESOURCE_ARN environment variable) so the sidecar
registers as the correct virtual node at runtime.
EOT
 value = { for k, v in aws_appmesh_virtual_node.this: k => v.arn }
}

output "virtual_node_names" {
 description = "Map of virtual-node key => name (the App Mesh object name, used by backends/routes/virtual services that reference nodes by name)."
 value = { for k, v in aws_appmesh_virtual_node.this: k => v.name }
}

###############################################################################
# Virtual routers
###############################################################################

output "virtual_router_ids" {
 description = "Map of virtual-router key => id."
 value = { for k, v in aws_appmesh_virtual_router.this: k => v.id }
}

output "virtual_router_arns" {
 description = "Map of virtual-router key => ARN. Consumed by IAM policies and monitoring."
 value = { for k, v in aws_appmesh_virtual_router.this: k => v.arn }
}

output "virtual_router_names" {
 description = "Map of virtual-router key => name."
 value = { for k, v in aws_appmesh_virtual_router.this: k => v.name }
}

###############################################################################
# Virtual gateways
###############################################################################

output "virtual_gateway_ids" {
 description = "Map of virtual-gateway key => id."
 value = { for k, v in aws_appmesh_virtual_gateway.this: k => v.id }
}

output "virtual_gateway_arns" {
 description = <<EOT
Map of virtual-gateway key => ARN. Wire into the ECS/EKS gateway task's Envoy
proxy container (APPMESH_RESOURCE_ARN) — a virtual gateway typically runs on
its own dedicated compute rather than sharing a task with a virtual node.
EOT
 value = { for k, v in aws_appmesh_virtual_gateway.this: k => v.arn }
}

output "virtual_gateway_names" {
 description = "Map of virtual-gateway key => name."
 value = { for k, v in aws_appmesh_virtual_gateway.this: k => v.name }
}

###############################################################################
# Virtual services
###############################################################################

output "virtual_service_ids" {
 description = "Map of virtual-service key => id."
 value = { for k, v in aws_appmesh_virtual_service.this: k => v.id }
}

output "virtual_service_arns" {
 description = "Map of virtual-service key => ARN. Consumed by IAM policies and monitoring."
 value = { for k, v in aws_appmesh_virtual_service.this: k => v.arn }
}

output "virtual_service_names" {
 description = "Map of virtual-service key => name (referenced by client virtual nodes' `backend.virtual_service_name` and by gateway-route targets)."
 value = { for k, v in aws_appmesh_virtual_service.this: k => v.name }
}

###############################################################################
# Routes
###############################################################################

output "route_ids" {
 description = "Map of route key => id."
 value = { for k, v in aws_appmesh_route.this: k => v.id }
}

output "route_arns" {
 description = "Map of route key => ARN. Consumed by CloudWatch dashboards and monitoring."
 value = { for k, v in aws_appmesh_route.this: k => v.arn }
}

###############################################################################
# Gateway routes
###############################################################################

output "gateway_route_ids" {
 description = "Map of gateway-route key => id."
 value = { for k, v in aws_appmesh_gateway_route.this: k => v.id }
}

output "gateway_route_arns" {
 description = "Map of gateway-route key => ARN. Consumed by CloudWatch dashboards and monitoring."
 value = { for k, v in aws_appmesh_gateway_route.this: k => v.arn }
}

###############################################################################
# Tags
###############################################################################

output "tags_all" {
 description = "All tags on the mesh, including those inherited from provider default_tags (resource tags win on key conflict)."
 value = aws_appmesh_mesh.this.tags_all
}
