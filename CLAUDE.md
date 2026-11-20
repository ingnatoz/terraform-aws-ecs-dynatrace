# CLAUDE.md

Terraform para desplegar servicios en **AWS ECS Fargate** (clusters existentes) con **Dynatrace OneAgent** inyectado por un contenedor sidecar. Un servicio por corrida. El uso completo está en `README.md`.

Repositorio **público**: todo valor de ejemplo es un placeholder.

## Arquitectura

- `terraform/config/`: configuración en JSON, sin código. Los stacks la leen con `jsondecode(file(...))`; no se usan `.tfvars`.
  - `common.json`: tags de todos los recursos.
  - `ecs-fargate-service/service.json`: servicio activo, copiado de `examples/`.
  - `ecs-fargate-service/clusters.json`: catálogo de clusters. `cluster_to_use` elige uno (`back/<x>`, `front/<x>`).
  - `ecs-fargate-service/namespaces.json`: namespace de Cloud Map por cluster (solo back).
  - `ecs-fargate-service/dynatrace.json`: imagen del instalador y nombres SSM compartidos de Dynatrace.
  - `parameter-store/parameters.json`: ignorado por git; plantilla en `example/`.
- `terraform/stacks/<stack>/`: root modules. Leen la config y componen los módulos.
- `terraform/modules/<módulo>/`: reutilizables. No leen archivos JSON; todo llega por variables.
- `Makefile`: punto de entrada (`make help`). El workspace de Terraform es el `service_name`.

`make ecs-apply` aplica en orden: `module.ecr` + push de la imagen, luego `module.cloudwatch` + `module.alb`, luego `module.ecs_service`.

## Convenciones

- Claves de `service.json` con prefijo de capa: `td_` task definition, `tg_` target group, `alb_` listener rule, `srv_` servicio ECS. Sin prefijo: identidad e imagen.
- `service_name`: `ms-<nombre>-<org>` (backend) o `mfe-<nombre>-<org>` (frontend). Los recursos AWS usan prefijos fijos: `tg-`, `td-`, `srv-`, `sd-`, `container-`.
- Los valores SSM de la config son nombres de parámetro (empiezan con `/`). El módulo arma el ARN con la cuenta actual y `aws_region`; no hardcodees account IDs ni regiones.
- `td_main_cpu + td_dynatrace_cpu <= td_task_cpu`: lo valida una `precondition`.
- Código, `description` y comentarios de Terraform en inglés. Documentación en español.

## Comandos

- `terraform fmt -recursive terraform`: formato. El hook `terraform-fmt.sh` lo aplica a cada `.tf` editado.
- `make ecs-validate` / `make params-validate`: validación sin cambios en AWS.
- `make ecs-plan` / `make params-plan`: plan contra AWS (requiere credenciales).

## Reglas

- No ejecutes `terraform apply`, `terraform destroy`, `terraform state rm`, `make aws-push` ni `git push` sin confirmación explícita del usuario.
- Nunca escribas datos reales: account IDs, IDs de VPC/subnet/SG, nombres internos de clusters o ALB, dominios, correos ni tokens. Usa los placeholders del repo: `corporation`, `vpc-xxxxxxxxxxxxxxxxx`, `/corporation/...`, `<your-...>`.
- Commits con Conventional Commits en inglés (`feat:`, `fix:`, `docs:`, `refactor:`, `build:`, `chore:`): atómicos, en imperativo, asunto de 72 caracteres como máximo.
- Antes de publicar, ejecuta el subagente `security-auditor`. El hook `check-sensitive.sh` bloquea `git commit` y `git push` si detecta datos sensibles.
