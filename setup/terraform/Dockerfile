FROM hashicorp/terraform:1.3.6

ENV PYTHONUNBUFFERED=1
RUN apk add --update --no-cache python3 && ln -sf python3 /usr/bin/python
RUN python3 -m ensurepip
RUN pip3 install --no-cache --upgrade pip setuptools
RUN pip3 install terraform-local

#ARG TF_VAR_terraform_backend_bucket
#ARG TF_VAR_aws_region
ARG TF_VAR_aws_access_key_id
ARG TF_VAR_aws_secret_access_key
ARG TF_VAR_localstack_hostname
ARG LOCALSTACK_HOSTNAME
ARG S3_HOSTNAME

ENV AWS_ACCESS_KEY_ID=$TF_VAR_aws_access_key_id
ENV AWS_SECRET_ACCESS_KEY=$TF_VAR_aws_secret_access_key
ENV TF_VAR_localstack_hostname=$LOCALSTACK_HOSTNAME
ENV S3_HOSTNAME=$S3_HOSTNAME

ADD . .

RUN terraform init 
#\
#-backend-config="bucket=${TF_VAR_terraform_backend_bucket}" \
#-backend-config="key=${TF_VAR_qovery_environment_id}" \
#-backend-config="region=${TF_VAR_aws_region}" \
#-backend-config="encrypt=false"

ENTRYPOINT [ "/bin/sh" ]
