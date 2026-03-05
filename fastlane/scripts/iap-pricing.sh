#!/bin/bash
#
# iap-pricing.sh - Manage IAP prices via App Store Connect API
#
# Usage:
#   ./iap-pricing.sh [--dry-run] <start_date>:<config-file> [start_date:config-file] ...
#
# Multiple config files are merged into a single price schedule.
# Entries are sorted by start_date (null first, then chronologically).
# Use "null" as start_date for immediate pricing.
#
# Example:
#   ./iap-pricing.sh --dry-run null:base.json 2025-12-01:sale.json 2026-01-01:normal.json
#
# Environment variables required:
#   ASC_KEY_ID         - App Store Connect API Key ID
#   ASC_ISSUER_ID      - App Store Connect API Issuer ID
#   ASC_KEY_PATH       - Path to the .p8 private key file
#   IAP_ID             - In-App Purchase ID
#   IAP_BASE_TERRITORY - Base territory code (e.g., DEU)
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# API base URL
API_BASE="https://api.appstoreconnect.apple.com"

# Parse arguments
DRY_RUN=false
CONFIG_ENTRIES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            CONFIG_ENTRIES+=("$1")
            shift
            ;;
    esac
done

if [[ ${#CONFIG_ENTRIES[@]} -eq 0 ]]; then
    echo -e "${RED}Error: At least one config entry is required${NC}"
    echo "Usage: $0 [--dry-run] <start_date>:<config-file> [start_date:config-file] ..."
    echo "Example: $0 --dry-run null:base.json 2025-12-01:sale.json"
    exit 1
fi

# Validate config entries format and file existence
for entry in "${CONFIG_ENTRIES[@]}"; do
    if [[ ! "$entry" =~ ^[^:]+:.+$ ]]; then
        echo -e "${RED}Error: Invalid format '$entry'. Expected <start_date>:<config-file>${NC}"
        exit 1
    fi
    config_file="${entry#*:}"
    if [[ ! -f "$config_file" ]]; then
        echo -e "${RED}Error: Config file not found: $config_file${NC}"
        exit 1
    fi
done

# Check for required tools
for cmd in jq curl ruby; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: Required tool '$cmd' is not installed${NC}"
        exit 1
    fi
done

# Check for required environment variables
for var in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH IAP_ID IAP_BASE_TERRITORY; do
    if [[ -z "${!var}" ]]; then
        echo -e "${RED}Error: Environment variable $var is not set${NC}"
        exit 1
    fi
done

if [[ ! -f "$ASC_KEY_PATH" ]]; then
    echo -e "${RED}Error: API key file not found: $ASC_KEY_PATH${NC}"
    exit 1
fi

# Generate JWT token using Ruby (handles ES256 signing with proper DER→raw conversion)
generate_jwt() {
    ruby -e '
require "openssl"
require "base64"
require "json"

def base64url(data)
  Base64.strict_encode64(data).tr("+/", "-_").delete("=")
end

key_id = ENV["ASC_KEY_ID"]
issuer_id = ENV["ASC_ISSUER_ID"]
key_path = ENV["ASC_KEY_PATH"]

header = { alg: "ES256", kid: key_id, typ: "JWT" }
payload = { iss: issuer_id, iat: Time.now.to_i, exp: Time.now.to_i + 1200, aud: "appstoreconnect-v1" }

signing_input = [header, payload].map { |h| base64url(h.to_json) }.join(".")

key = OpenSSL::PKey::EC.new(File.read(key_path))
signature = key.sign("SHA256", signing_input)

# Convert DER signature to raw R||S format (required for JWT ES256)
asn1 = OpenSSL::ASN1.decode(signature)
r = asn1.value[0].value.to_s(2).rjust(32, "\x00")[-32, 32]
s = asn1.value[1].value.to_s(2).rjust(32, "\x00")[-32, 32]

puts "#{signing_input}.#{base64url(r + s)}"
'
}

# Make API request
api_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"

    local jwt=$(generate_jwt)
    local url="${API_BASE}${endpoint}"

    if [[ "$method" == "GET" ]]; then
        curl -s -g -X GET "$url" \
            -H "Authorization: Bearer $jwt" \
            -H "Content-Type: application/json"
    else
        curl -s -g -X "$method" "$url" \
            -H "Authorization: Bearer $jwt" \
            -H "Content-Type: application/json" \
            -d "$data"
    fi
}

# Find price point ID by territory and customer price (exact match)
find_price_point_id() {
    local territory="$1"
    local target_price="$2"
    local key="${territory}_${target_price}"

    # Direct lookup from index
    local result=$(echo "$PRICE_LOOKUP_INDEX" | jq -r --arg key "$key" '.[$key] // empty')

    if [[ -z "$result" ]]; then
        echo -e "${RED}Error: Price $target_price not found for $territory${NC}" >&2
        echo -e "${YELLOW}Available prices for $territory (first 20):${NC}" >&2
        echo "$PRICE_POINTS_DATA" | jq -r --arg t "$territory" '
            [.[] | select(.relationships.territory.data.id == $t) | .attributes.customerPrice] |
            unique | sort_by(tonumber) | .[0:20] | join(", ")
        ' >&2
        return 1
    fi

    echo "$result"
}

# Add a price entry to the payload arrays
# Arguments: price_point_id, start_date, end_date
add_price_entry() {
    local price_point_id="$1"
    local start_date="$2"
    local end_date="$3"

    local price_id="\${price${PRICE_COUNTER}}"
    PRICE_COUNTER=$((PRICE_COUNTER + 1))

    MANUAL_PRICES_DATA=$(echo "$MANUAL_PRICES_DATA" | jq --arg id "$price_id" \
        '. + [{"type": "inAppPurchasePrices", "id": $id}]')

    # Build attributes object based on start_date and end_date
    local attributes
    if [[ "$start_date" == "null" && -z "$end_date" ]]; then
        attributes='{"startDate": null}'
    elif [[ "$start_date" == "null" && -n "$end_date" ]]; then
        attributes=$(jq -n --arg end "$end_date" '{"startDate": null, "endDate": $end}')
    elif [[ "$start_date" != "null" && -z "$end_date" ]]; then
        attributes=$(jq -n --arg start "$start_date" '{"startDate": $start}')
    else
        attributes=$(jq -n --arg start "$start_date" --arg end "$end_date" '{"startDate": $start, "endDate": $end}')
    fi

    INCLUDED_ARRAY=$(echo "$INCLUDED_ARRAY" | jq \
        --arg id "$price_id" \
        --arg iap_id "$IAP_ID" \
        --arg pp_id "$price_point_id" \
        --argjson attrs "$attributes" \
        '. + [{
            "type": "inAppPurchasePrices",
            "id": $id,
            "attributes": $attrs,
            "relationships": {
                "inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": $iap_id}},
                "inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": $pp_id}}
            }
        }]')
}

# Process prices from a JSON object and add entries for each territory
# Arguments: prices_json, start_date, end_date, label
process_prices() {
    local prices_json="$1"
    local start_date="$2"
    local end_date="$3"
    local label="$4"
    local count=0

    echo -e "\n${BLUE}Processing ${label}...${NC}"

    for territory in $(echo "$prices_json" | jq -r 'keys[]'); do
        local target_price=$(echo "$prices_json" | jq -r --arg t "$territory" '.[$t]')

        local price_point_id=$(find_price_point_id "$territory" "$target_price")
        if [[ $? -ne 0 ]]; then
            exit 1
        fi

        add_price_entry "$price_point_id" "$start_date" "$end_date"
        count=$((count + 1))
    done

    echo -e "  ${GREEN}${count} territories${NC}"
}

# ============================================================================
# Main Script
# ============================================================================

# Use environment variables for IAP config
echo -e "${GREEN}IAP ID:${NC} $IAP_ID"
echo -e "${GREEN}Base Territory:${NC} $IAP_BASE_TERRITORY"

# Read and parse all config entries
echo -e "${BLUE}Reading ${#CONFIG_ENTRIES[@]} config file(s)...${NC}"

# Build array of configs with their start_dates for sorting
CONFIGS_JSON="[]"
for entry in "${CONFIG_ENTRIES[@]}"; do
    start_date="${entry%%:*}"
    config_file="${entry#*:}"
    echo -e "  Loading: $config_file (start: $start_date)"

    config_content=$(cat "$config_file")

    # Convert "null" string to actual null for JSON, add start_date and source file
    if [[ "$start_date" == "null" ]]; then
        CONFIGS_JSON=$(echo "$CONFIGS_JSON" | jq --arg file "$config_file" --argjson config "$config_content" \
            '. + [($config + {_source_file: $file, _start_date: null})]')
    else
        CONFIGS_JSON=$(echo "$CONFIGS_JSON" | jq --arg file "$config_file" --arg start "$start_date" --argjson config "$config_content" \
            '. + [($config + {_source_file: $file, _start_date: $start})]')
    fi
done

# Sort configs by start_date (null first, then chronologically)
CONFIGS_JSON=$(echo "$CONFIGS_JSON" | jq 'sort_by(._start_date // "")')

echo -e "${GREEN}Config files (sorted by start_date):${NC}"
echo "$CONFIGS_JSON" | jq -r '.[] | "  \(._start_date // "null") - \(._source_file)"'

# Collect all territories from all config files
ALL_TERRITORIES=$(echo "$CONFIGS_JSON" | jq -r '[.[].prices | keys] | add | unique | join(",")')
TERRITORY_COUNT=$(echo "$CONFIGS_JSON" | jq '[.[].prices | keys] | add | unique | length')
echo -e "${GREEN}Territories:${NC} $TERRITORY_COUNT total"

# Fetch price points for all territories (with pagination)
echo -e "\n${BLUE}Fetching price points from App Store Connect...${NC}"
PRICE_POINTS_DATA="[]"
NEXT_URL="/v2/inAppPurchases/${IAP_ID}/pricePoints?filter[territory]=${ALL_TERRITORIES}&include=territory&limit=8000"
PAGE=1

while [[ -n "$NEXT_URL" ]]; do
    echo -e "  Fetching page $PAGE..."
    PRICE_POINTS_RESPONSE=$(api_request "GET" "$NEXT_URL")

    # Check for errors
    if echo "$PRICE_POINTS_RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
        echo -e "${RED}API Error:${NC}"
        echo "$PRICE_POINTS_RESPONSE" | jq '.errors'
        exit 1
    fi

    # Append data from this page
    PAGE_DATA=$(echo "$PRICE_POINTS_RESPONSE" | jq '.data')
    PRICE_POINTS_DATA=$(echo "$PRICE_POINTS_DATA $PAGE_DATA" | jq -s 'add')

    # Check for next page
    NEXT_URL=$(echo "$PRICE_POINTS_RESPONSE" | jq -r '.links.next // empty')
    if [[ -n "$NEXT_URL" ]]; then
        NEXT_URL=$(echo "$NEXT_URL" | sed 's|https://api.appstoreconnect.apple.com||')
    fi
    PAGE=$((PAGE + 1))
done

PRICE_POINTS_COUNT=$(echo "$PRICE_POINTS_DATA" | jq 'length')
echo -e "${GREEN}Found $PRICE_POINTS_COUNT price points${NC}"

# Build lookup index for O(1) price point lookups (exact match only)
echo -e "${BLUE}Building price index...${NC}"
PRICE_LOOKUP_INDEX=$(echo "$PRICE_POINTS_DATA" | jq '
  reduce .[] as $item ({};
    ($item.relationships.territory.data.id) as $territory |
    ($item.attributes.customerPrice) as $price |
    . + { ($territory + "_" + $price): $item.id }
  )
')

# Initialize payload arrays
MANUAL_PRICES_DATA="[]"
INCLUDED_ARRAY="[]"
PRICE_COUNTER=0

# Process each config file in order (already sorted by start_date)
# Each interval's end_date is the next interval's start_date (except the last one)
CONFIG_COUNT=$(echo "$CONFIGS_JSON" | jq 'length')
for ((i=0; i<CONFIG_COUNT; i++)); do
    CONFIG=$(echo "$CONFIGS_JSON" | jq ".[$i]")
    SOURCE_FILE=$(echo "$CONFIG" | jq -r '._source_file')
    START_DATE=$(echo "$CONFIG" | jq -r '._start_date // empty')
    PRICES=$(echo "$CONFIG" | jq '.prices')

    # Get end_date from next config's start_date (empty for last config)
    END_DATE=""
    if [[ $((i + 1)) -lt $CONFIG_COUNT ]]; then
        END_DATE=$(echo "$CONFIGS_JSON" | jq -r ".[$((i + 1))]._start_date // empty")
    fi

    if [[ -n "$START_DATE" ]]; then
        if [[ -n "$END_DATE" ]]; then
            LABEL="$SOURCE_FILE ($START_DATE to $END_DATE)"
        else
            LABEL="$SOURCE_FILE (from $START_DATE)"
        fi
        process_prices "$PRICES" "$START_DATE" "$END_DATE" "$LABEL"
    else
        if [[ -n "$END_DATE" ]]; then
            LABEL="$SOURCE_FILE (until $END_DATE)"
        else
            LABEL="$SOURCE_FILE (immediate)"
        fi
        process_prices "$PRICES" "null" "$END_DATE" "$LABEL"
    fi
done

# Build the final request payload
REQUEST_PAYLOAD=$(jq -n \
    --arg iap_id "$IAP_ID" \
    --arg base_territory "$IAP_BASE_TERRITORY" \
    --argjson manual_prices "$MANUAL_PRICES_DATA" \
    --argjson included "$INCLUDED_ARRAY" \
    '{
        "data": {
            "type": "inAppPurchasePriceSchedules",
            "relationships": {
                "inAppPurchase": {"data": {"type": "inAppPurchases", "id": $iap_id}},
                "baseTerritory": {"data": {"type": "territories", "id": $base_territory}},
                "manualPrices": {"data": $manual_prices}
            }
        },
        "included": $included
    }')

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "\n${YELLOW}DRY RUN - No changes made${NC}"
    exit 0
fi

# Make the API request
echo -e "\n${BLUE}Creating price schedule...${NC}"
RESPONSE=$(api_request "POST" "/v1/inAppPurchasePriceSchedules" "$REQUEST_PAYLOAD")

# Check for errors
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    echo -e "${RED}API Error:${NC}"
    echo "$RESPONSE" | jq '.errors'
    exit 1
fi

echo -e "${GREEN}Success! Price schedule created.${NC}"
