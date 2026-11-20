
SHELL := /bin/bash

# No imprimir "Entering/Leaving directory" en llamadas recursivas
MAKEFLAGS += --no-print-directory

################################################################################
# terraform-aws-ecs-dynatrace
# Despliegue de servicios en AWS ECS Fargate con Dynatrace OneAgent (sidecar)
# Requiere: terraform >= 1.3, aws cli v2, docker, jq
################################################################################

.PHONY: help aws-set aws-login aws-push \
        ecs-init ecs-validate ecs-plan ecs-ecr ecs-alb ecs-service ecs-apply ecs-status ecs-destroy \
        params-init params-validate params-plan params-apply params-clean params-status params-destroy

# Colors
RESET   = \033[0m
GREEN   = \033[32m
MAGENTA = \033[35m
CYAN    = \033[36m
BOLD    = \033[1m

# ==============================================================================
# Dynamic config from terraform/config/ecs-fargate-service/service.json
# ==============================================================================
ECS_CONFIG        := terraform/config/ecs-fargate-service/service.json
SERVICE_NAME_FULL := $(shell jq -r '.service_name' $(ECS_CONFIG))
SERVICE_TAG       := $(shell jq -r '.ecr_image_tag' $(ECS_CONFIG))

# Artifacts: imagen Docker exportada con `docker save` (entrada de aws-push)
ARTIFACTS_DIR := terraform/artifacts
ARTIFACT_TAR  := $(ARTIFACTS_DIR)/$(SERVICE_NAME_FULL)-$(SERVICE_TAG).tar

# Terraform stacks (cada uno lee su config de terraform/config/ via jsondecode)
ECS_DIR := terraform/stacks/ecs-fargate-service
PS_DIR := terraform/stacks/parameter-store

# AWS
AWS_PROFILE  := default
AWS_REGION   := us-east-1
# Account ID: se obtiene de las credenciales activas, una sola vez y solo cuando se usa.
# Se puede fijar a mano: make aws-push AWS_ACCOUNT_ID=<id>
AWS_ACCOUNT_ID ?= $(eval AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text))$(AWS_ACCOUNT_ID)
AWS_ECR_HOST  = $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
AWS_ECR_NAME  = $(AWS_ECR_HOST)/$(SERVICE_NAME_FULL):$(SERVICE_TAG)

# Helpers de impresion (una linea por paso)
define step
@printf '\n$(BOLD)$(CYAN)==> %s$(RESET)\n' "$(1)"
endef

define ok
@printf '$(BOLD)$(GREEN)OK %s$(RESET)\n' "$(1)"
endef

define success
@printf '\n$(BOLD)$(GREEN)============================================================$(RESET)\n'
@printf '$(BOLD)$(GREEN)  %s$(RESET)\n' "$(1)"
@printf '$(BOLD)$(GREEN)============================================================$(RESET)\n'
endef

help:
	$(call step,terraform-aws-ecs-dynatrace - Infrastructure as Code)
	@printf '  aws-set         - Configura el AWS CLI (interactivo)\n'
	@printf '  aws-login       - Login al ECR de AWS\n'
	@printf '  aws-push        - Carga el .tar de terraform/artifacts y lo sube al ECR\n'
	@printf '  ecs-init        - Inicializa Terraform y selecciona el workspace del servicio\n'
	@printf '  ecs-validate    - Valida la configuracion (sin tocar AWS)\n'
	@printf '  ecs-plan        - Muestra el plan del servicio sin aplicar\n'
	@printf '  ecs-ecr         - Despliega el ECR y sube la imagen\n'
	@printf '  ecs-alb         - Despliega CloudWatch y ALB (Target Group/Rules)\n'
	@printf '  ecs-service     - Despliega el servicio ECS Fargate y su Task Definition\n'
	@printf '  ecs-apply       - Despliega TODA la infraestructura de manera secuencial\n'
	@printf '  ecs-status      - Lista los recursos del servicio en el estado\n'
	@printf '  ecs-destroy     - Destruye toda la infraestructura del servicio\n'
	@printf '  params-init     - Inicializa Terraform para Parameter Store\n'
	@printf '  params-validate - Valida la configuracion de Parameter Store\n'
	@printf '  params-plan     - Muestra el plan de Parameter Store sin aplicar\n'
	@printf '  params-apply    - Crea/actualiza los parametros en SSM\n'
	@printf '  params-clean    - Suelta los parametros del estado (siguen en AWS)\n'
	@printf '  params-status   - Lista los parametros en el estado\n'
	@printf '  params-destroy  - Destruye los parametros administrados por Terraform\n'

# ==============================================================================
# AWS Targets
# ==============================================================================
aws-set:
	$(call step,Configurando AWS CLI (interactivo))
	@printf "AWS Access Key ID: "; IFS= read KID; test -n "$$KID" || { echo "ERROR: falta AWS Access Key ID"; exit 1; }; \
	printf "AWS Secret Access Key: "; stty -echo; IFS= read SK; stty echo; printf "\n"; test -n "$$SK" || { echo "ERROR: falta AWS Secret Access Key"; exit 1; }; \
	printf "AWS Session Token: "; stty -echo; IFS= read ST; stty echo; printf "\n"; test -n "$$ST" || { echo "ERROR: falta AWS Session Token"; exit 1; }; \
	aws configure set aws_access_key_id     "$$KID" --profile "$(AWS_PROFILE)"; \
	aws configure set aws_secret_access_key "$$SK"  --profile "$(AWS_PROFILE)"; \
	aws configure set aws_session_token     "$$ST"  --profile "$(AWS_PROFILE)"; \
	aws configure set region                "$(AWS_REGION)" --profile "$(AWS_PROFILE)"; \
	aws configure set output                "json"  --profile "$(AWS_PROFILE)"
	$(call step,Verificando identidad)
	@aws sts get-caller-identity --profile "$(AWS_PROFILE)" --output json || true
	$(call ok,AWS CLI configurado)

aws-login:
	$(call step,Login al ECR de AWS)
	@rm -f ~/.docker/config.json
	@aws ecr get-login-password --region '$(AWS_REGION)' | docker login --username AWS --password-stdin $(AWS_ECR_HOST)
	$(call ok,Login OK)

aws-push:
	@test -f $(ARTIFACT_TAR) || { \
		printf '$(BOLD)$(MAGENTA)ERROR: no existe $(ARTIFACT_TAR)$(RESET)\n'; \
		printf 'Generalo con: docker save -o $(ARTIFACT_TAR) $(SERVICE_NAME_FULL):$(SERVICE_TAG)\n'; \
		exit 1; }
	@$(MAKE) aws-login
	$(call step,Cargando artefacto $(ARTIFACT_TAR))
	@docker load -i $(ARTIFACT_TAR)
	$(call step,Subiendo imagen al ECR)
	@docker tag $(SERVICE_NAME_FULL):$(SERVICE_TAG) $(AWS_ECR_NAME)
	@aws ecr batch-delete-image --repository-name $(SERVICE_NAME_FULL) --image-ids imageTag=$(SERVICE_TAG) >/dev/null 2>&1 || true
	@docker push $(AWS_ECR_NAME)
	@docker rmi $(AWS_ECR_NAME) --force >/dev/null 2>&1 || true
	$(call ok,Imagen en ECR)

# ==============================================================================
# ECS Targets
# ==============================================================================
ecs-init:
	$(call step,Inicializando Terraform y workspace)
	@cd $(ECS_DIR) && terraform init
	@cd $(ECS_DIR) && terraform workspace select $(SERVICE_NAME_FULL) || terraform workspace new $(SERVICE_NAME_FULL)

ecs-validate: ecs-init
	$(call step,Validando configuracion)
	@cd $(ECS_DIR) && terraform validate

ecs-plan: ecs-validate
	$(call step,Plan del servicio (sin aplicar))
	@cd $(ECS_DIR) && terraform plan

ecs-ecr: ecs-validate
	$(call step,Desplegando ECR)
	@cd $(ECS_DIR) && terraform apply -target=module.ecr
	@$(MAKE) aws-push
	$(call ok,ECR + imagen listos)

ecs-alb: ecs-validate
	$(call step,Desplegando CloudWatch + ALB (Target Group/Rules))
	@cd $(ECS_DIR) && terraform apply -target=module.cloudwatch -target=module.alb
	$(call ok,CloudWatch + ALB listos)

ecs-service: ecs-validate
	$(call step,Desplegando ECS Fargate Service + Task Definition)
	@cd $(ECS_DIR) && terraform apply -target=module.ecs_service
	$(call ok,Servicio desplegado)

ecs-apply: ecs-ecr ecs-alb ecs-service
	$(call step,Recursos en el estado)
	@cd $(ECS_DIR) && terraform state list
	$(call success,Infraestructura aplicada con exito)

ecs-status: ecs-init
	$(call step,Recursos en el estado)
	@cd $(ECS_DIR) && terraform state list

ecs-destroy: ecs-init
	$(call step,DESTRUYENDO toda la infraestructura del servicio)
	@cd $(ECS_DIR) && terraform destroy
	$(call ok,Infraestructura destruida)

# ==============================================================================
# Parameter Store Targets
# ==============================================================================
params-init:
	$(call step,Inicializando Terraform (Parameter Store))
	@cd $(PS_DIR) && terraform init

params-validate: params-init
	$(call step,Validando configuracion (Parameter Store))
	@cd $(PS_DIR) && terraform validate

params-plan: params-validate
	$(call step,Plan de Parameter Store (sin aplicar))
	@cd $(PS_DIR) && terraform plan

params-apply: params-validate
	$(call step,Aplicando parametros en SSM)
	@cd $(PS_DIR) && terraform apply
	$(call step,Parametros en el estado)
	@cd $(PS_DIR) && terraform state list
	$(call success,Infraestructura aplicada con exito)

params-clean: params-init
	$(call step,Soltando parametros del estado (siguen en AWS))
	@cd $(PS_DIR) && \
	if terraform state list | grep -q '^module.parameter_store.aws_ssm_parameter.this'; then \
		terraform state rm 'module.parameter_store.aws_ssm_parameter.this'; \
	else \
		printf 'Estado ya vacio, nada que soltar.\n'; \
	fi
	$(call ok,Workspace limpio - los parametros en AWS quedan intactos)

params-status: params-init
	$(call step,Parametros en el estado)
	@cd $(PS_DIR) && terraform state list

params-destroy: params-init
	$(call step,DESTRUYENDO los parametros administrados)
	@cd $(PS_DIR) && terraform destroy
	$(call ok,Parametros destruidos)
