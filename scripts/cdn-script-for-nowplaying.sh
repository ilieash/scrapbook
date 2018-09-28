#!/bin/bash

# Authenticates with kubernetes cluster via gcloud
#
# You will need to set the following environment variables:
#

mkdir -p "$HOME/.config/gcloud"

if [[ -n "$GCLOUD_SERVICE_KEY" ]]; then
    echo "$GCLOUD_SERVICE_KEY" > "$HOME/.config/gcloud/application_default_credentials.json"
fi

gcloud auth activate-service-account --key-file "$HOME/.config/gcloud/application_default_credentials.json"
gcloud container clusters get-credentials "$CLOUDSDK_CONTAINER_CLUSTER" || exit 1

success=0
end=$((SECONDS+360))
BACKEND=$(kubectl get ing $NOWPLAYING_INGRESS -o json | jq -j '.metadata.annotations."ingress.kubernetes.io/backends"' | jq -j 'keys[0]')
BACKEND_DEFAULT=$(kubectl get ing $NOWPLAYING_INGRESS -o json | jq -j '.metadata.annotations."ingress.kubernetes.io/backends"' | jq -j 'keys[1]')

if [[ $BACKEND = *"UNHEALTHY"* ]] && [[ $BACKEND_DEFAULT = *"UNHEALTHY"* ]]
then
        sleep 120
fi

DESCRIPTION=$(gcloud compute backend-services describe $BACKEND --global | grep 'description')



while [ $success -eq 0 ] && [ $SECONDS -lt $end ]
do
        if [[ $DESCRIPTION = *"nowplaying"* ]]
        then
                gcloud compute backend-services update --global $BACKEND --enable-cdn
                gcloud compute backend-services update $BACKEND --global --timeout=86400
                success=1
        else
                DESCRIPTION=$(gcloud compute backend-services describe $BACKEND_DEFAULT --global | grep 'description')
                if [[ $DESCRIPTION = *"nowplaying"* ]]
                then
                        gcloud compute backend-services update --global $BACKEND_DEFAULT --enable-cdn
                        gcloud compute backend-services update $BACKEND_DEFAULT --global --timeout=86400
                        success=1
                else
                        sleep 60
                        echo "sleeping for backend to trun healthy.."
                fi
#       else
#               echo "$end seconds left to end the task if not successfull"
        fi
done

