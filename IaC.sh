#!/usr/bin/env bash
set -euo pipefail

# ===========
# Settings
# ===========
BUCKET_NAME="cloud-armory-lead-magnets"            # S3 bucket name (must be globally unique)
REGION="${AWS_REGION:-us-east-2}"     # Or export AWS_REGION
DIST_COMMENT="Downloads for lead magnets (PDF/ZIP)"
PROFILE="landingpage"

CONFIG_PATH="./cloudfront-dist-config.json"   # stable path (no /tmp)
POLICY_PATH="./s3-bucket-policy.json"         # stable path

# ===========
# Pre-flight
# ===========
command -v aws >/dev/null || { echo "aws CLI not found"; exit 1; }
command -v jq  >/dev/null || { echo "jq not found"; exit 1; }

ACCOUNT_ID="$(aws sts get-caller-identity --profile "${PROFILE}" --query Account --output text)"
DATE_TAG="$(date -u +%Y%m%d%H%M%S)"
CALLER_REF="lead-magnets-${DATE_TAG}"

# ===========
# Deferred Settings
# ===========
OAC_NAME="${BUCKET_NAME}-oac-${ACCOUNT_ID}"

echo "Using account: ${ACCOUNT_ID}"
echo "Region: ${REGION}"
echo "Profile: ${PROFILE}"


# ===========
# Create/verify S3 bucket (robust)
# ===========
bucket_status() {
  # Returns one of: NOT_EXISTS | OWNED_OR_ACCESSIBLE | EXISTS_NOT_OWNED
  # Prints extra info (like region) on stdout when available.
  set +e
  OUT="$(aws s3api get-bucket-location \
      --bucket "${BUCKET_NAME}" \
      --profile "${PROFILE}" 2>&1)"
  RC=$?
  set -e
  if [ $RC -eq 0 ]; then
    # us-east-1 returns null/None; normalize to us-east-1
    LOC=$(echo "$OUT" | jq -r '.LocationConstraint // "us-east-1"')
    echo "OWNED_OR_ACCESSIBLE ${LOC}"
    return 0
  fi
  if echo "$OUT" | grep -q "NoSuchBucket"; then
    echo "NOT_EXISTS"
    return 0
  fi
  if echo "$OUT" | grep -q "AccessDenied"; then
    echo "EXISTS_NOT_OWNED"
    return 0
  fi
  echo "UNKNOWN ${OUT}"
  return 1
}

read STATUS ACTUAL_REGION <<<"$(bucket_status)"

case "${STATUS}" in
  NOT_EXISTS)
    echo "Bucket does not exist. Creating ${BUCKET_NAME} in ${REGION}..."
    if [ "${REGION}" = "us-east-1" ]; then
      aws s3api create-bucket --bucket "${BUCKET_NAME}" --profile "${PROFILE}"
    else
      aws s3api create-bucket \
        --bucket "${BUCKET_NAME}" \
        --create-bucket-configuration LocationConstraint="${REGION}" \
        --profile "${PROFILE}"
    fi
    ;;

  OWNED_OR_ACCESSIBLE)
    echo "Bucket ${BUCKET_NAME} already exists and is accessible."
    if [ -n "${ACTUAL_REGION}" ] && [ "${ACTUAL_REGION}" != "${REGION}" ]; then
      echo "NOTE: Bucket is actually in region ${ACTUAL_REGION}, not ${REGION}."
      echo "Using ${ACTUAL_REGION} for S3-origin domain."
      REGION="${ACTUAL_REGION}"
    fi
    ;;

  EXISTS_NOT_OWNED)
    echo "ERROR: Bucket name '${BUCKET_NAME}' is already taken by another account."
    echo "Choose a different bucket name (S3 names are global)."
    exit 1
    ;;

  *)
    echo "Unexpected status from bucket check: ${STATUS} ${ACTUAL_REGION}"
    exit 1
    ;;
esac


# Enforce bucket-owner (disable ACLs)
aws s3api put-bucket-ownership-controls \
  --bucket "${BUCKET_NAME}" \
  --ownership-controls 'Rules=[{ObjectOwnership=BucketOwnerEnforced}]' \
  --profile "${PROFILE}"

# Block all public access
aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
  --profile "${PROFILE}"

# Optional: enable versioning
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled \
  --profile "${PROFILE}"

# Optional: CORS
aws s3api put-bucket-cors \
  --bucket "${BUCKET_NAME}" \
  --cors-configuration '{
    "CORSRules":[
      {
        "AllowedMethods":["GET"],
        "AllowedOrigins":["*"],
        "AllowedHeaders":["*"],
        "MaxAgeSeconds": 3000
      }
    ]
  }' \
  --profile "${PROFILE}"

# ===========
# Get-or-create CloudFront Origin Access Control (OAC)
# ===========
get_oac_id_by_name() {
  aws cloudfront list-origin-access-controls \
    --profile "${PROFILE}" \
    --query "OriginAccessControlList.Items[?Name=='${OAC_NAME}'].Id | [0]" \
    --output text
}

OAC_ID="$(get_oac_id_by_name || true)"
if [ -n "${OAC_ID}" ] && [ "${OAC_ID}" != "None" ]; then
  echo "Found existing OAC '${OAC_NAME}': ${OAC_ID}"
else
  OAC_ID="$(
    aws cloudfront create-origin-access-control \
      --profile "${PROFILE}" \
      --origin-access-control-config "Name=${OAC_NAME},Description=OAC for ${BUCKET_NAME},SigningProtocol=sigv4,SigningBehavior=always,OriginAccessControlOriginType=s3" \
      --query 'OriginAccessControl.Id' --output text
  )"
  echo "Created OAC: ${OAC_ID}"
fi

# ===========
# Create CloudFront distribution (no CachedMethods)
# ===========
ORIGIN_DOMAIN="${BUCKET_NAME}.s3.${REGION}.amazonaws.com"

cat > "${CONFIG_PATH}" <<JSON
{
  "CallerReference": "${CALLER_REF}",
  "Comment": "${DIST_COMMENT}",
  "Origins": {
    "Items": [
      {
        "Id": "s3-${BUCKET_NAME}",
        "DomainName": "${ORIGIN_DOMAIN}",
        "S3OriginConfig": { "OriginAccessIdentity": "" },
        "OriginAccessControlId": "${OAC_ID}"
      }
    ],
    "Quantity": 1
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "s3-${BUCKET_NAME}",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Items": ["GET","HEAD"],
      "Quantity": 2
    },
    "Compress": true,
    "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
    "OriginRequestPolicyId": "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"
  },
  "Enabled": true,
  "PriceClass": "PriceClass_100"
}
JSON


# Double-check the file exists and looks like JSON
[ -s "${CONFIG_PATH}" ] || { echo "ERROR: ${CONFIG_PATH} not created"; exit 1; }
jq . < "${CONFIG_PATH}" >/dev/null || { echo "ERROR: ${CONFIG_PATH} is not valid JSON"; exit 1; }

DIST_CREATE_OUT="$(aws cloudfront create-distribution --distribution-config file://"${CONFIG_PATH}" --profile "${PROFILE}")"
DIST_ID="$(echo "${DIST_CREATE_OUT}" | jq -r '.Distribution.Id')"
DIST_DOMAIN="$(echo "${DIST_CREATE_OUT}" | jq -r '.Distribution.DomainName')"
DIST_ARN="arn:aws:cloudfront::${ACCOUNT_ID}:distribution/${DIST_ID}"

echo "Created CloudFront distribution: ${DIST_ID}"
echo "CloudFront domain: https://${DIST_DOMAIN}"

# ===========
# Apply S3 bucket policy for CloudFront
# ===========
cat > "${POLICY_PATH}" <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontReadViaOAC",
      "Effect": "Allow",
      "Principal": { "Service": "cloudfront.amazonaws.com" },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "${DIST_ARN}"
        }
      }
    }
  ]
}
JSON

[ -s "${POLICY_PATH}" ] || { echo "ERROR: ${POLICY_PATH} not created"; exit 1; }
jq . < "${POLICY_PATH}" >/dev/null || { echo "ERROR: ${POLICY_PATH} is not valid JSON"; exit 1; }

aws s3api put-bucket-policy --bucket "${BUCKET_NAME}" --policy file://"${POLICY_PATH}" --profile "${PROFILE}"
echo "Attached restrictive bucket policy for CloudFront distribution ${DIST_ID}"

# ===========
# Output
# ===========
cat <<EONOTE

Setup complete ✅

Bucket: s3://${BUCKET_NAME}
Region: ${REGION}
Profile: ${PROFILE}
CloudFront distribution ID: ${DIST_ID}
CloudFront domain (use for downloads): https://${DIST_DOMAIN}

If you later add a custom domain:
1) Get an ACM cert in us-east-1.
2) Update the distribution with your domain as an Alternate Domain Name + attach the cert.
3) Point DNS (CNAME) to ${DIST_DOMAIN}.

EONOTE
