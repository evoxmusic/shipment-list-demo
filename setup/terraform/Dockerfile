FROM python:3.9-alpine

#ARG TF_VAR_terraform_backend_bucket
#ARG TF_VAR_aws_region
ARG TF_VAR_aws_access_key_id
ARG TF_VAR_aws_secret_access_key

ENV AWS_ACCESS_KEY_ID=$TF_VAR_aws_access_key_id
ENV AWS_SECRET_ACCESS_KEY=$TF_VAR_aws_secret_access_key

RUN pip install terraform-local

ADD . .

RUN tflocal init 
#\
#-backend-config="bucket=${TF_VAR_terraform_backend_bucket}" \
#-backend-config="key=${TF_VAR_qovery_environment_id}" \
#-backend-config="region=${TF_VAR_aws_region}" \
#-backend-config="encrypt=false"

ENTRYPOINT [ "/bin/sh" ]
