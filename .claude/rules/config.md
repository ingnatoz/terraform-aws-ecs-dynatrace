---
paths:
  - "terraform/config/**/*.json"
---

# Reglas de la configuración JSON

- Solo placeholders. Nunca valores reales de una cuenta o empresa.
  - Organización: `corporation` (`ms-<nombre>-corporation`, `cluster-corporation-back`, `/corporation/...`).
  - IDs de AWS con `x`: `vpc-xxxxxxxxxxxxxxxxx`, `subnet-xxxxxxxxxxxxxxxx1`, `sg-xxxxxxxxxxxxxxxx1`. Un ID hexadecimal se trata como real y el hook lo bloquea.
  - Valores propios de cada entorno con `<...>`: `<your-environment-id>.live.dynatrace.com`, `<your-network-zone>`, `<db-host>`.
  - Dominios: `corporation.local`.
- Claves de `service.json` con prefijo de capa: `td_`, `tg_`, `alb_`, `srv_`. Sin prefijo: identidad e imagen.
- `service.json` y `examples/backend-service.json` tienen las mismas claves. Si agregas una clave, agrégala en ambos ejemplos.
- `cluster_to_use` debe existir en `clusters.json`. Con `srv_discovery: true`, también en `namespaces.json`.
- Parámetros SSM: nombre absoluto que empieza con `/`. Los secretos (tokens) no van en `parameter-store/example/parameters.json`; se crean aparte como `SecureString`.
- Mantén el JSON válido (sin comentarios ni comas finales) e indentado con 2 espacios.
