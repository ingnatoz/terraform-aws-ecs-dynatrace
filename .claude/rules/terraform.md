---
paths:
  - "terraform/**/*.tf"
---

# Reglas de Terraform

- Cada módulo tiene exactamente `main.tf`, `variables.tf`, `outputs.tf` y `versions.tf`.
- `versions.tf`: `required_version = ">= 1.3.0"` y provider `hashicorp/aws` `>= 4.0.0`. El bloque `provider` va solo en los stacks.
- Toda variable y todo output llevan `description` en inglés. Las variables llevan `type`.
- Los módulos no leen archivos: reciben todo por variables. La lectura de `terraform/config/*.json` ocurre solo en `terraform/stacks/`.
- Sin account IDs, regiones ni ARNs fijos: usa `data.aws_caller_identity`, `var.aws_region` y nombres de parámetros SSM (el módulo arma el ARN).
- Nombres de recursos AWS derivados de `service_name` con los prefijos existentes: `tg-`, `td-`, `srv-`, `sd-`, `container-`.
- Una clave nueva en `service.json` se lee en el stack (`local.config["..."]`) y se pasa al módulo como variable. Usa `try(..., default)` si es opcional.
- Valida supuestos con `validation` o `precondition` en lugar de comentarios.
- Después de editar, el código debe pasar `terraform fmt` y `terraform validate`.
