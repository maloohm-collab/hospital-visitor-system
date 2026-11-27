#!/usr/bin/env bash
set -euo pipefail

# IBM Plex Sans Arabic is distributed under the SIL Open Font License.
# Pin the Google Fonts repository revision so APK builds are reproducible.
FONT_REVISION="5026800714d07231937d92eb4cceabf06e05d74e"
FONT_BASE="https://raw.githubusercontent.com/google/fonts/${FONT_REVISION}/ofl/ibmplexsansarabic"
FONT_DIR="assets/fonts"

mkdir -p "${FONT_DIR}"
for weight in Regular Medium SemiBold Bold; do
  file="IBMPlexSansArabic-${weight}.ttf"
  curl --fail --location --retry 3 --silent --show-error \
    "${FONT_BASE}/${file}" \
    --output "${FONT_DIR}/${file}"
  test -s "${FONT_DIR}/${file}"
done

curl --fail --location --retry 3 --silent --show-error \
  "${FONT_BASE}/OFL.txt" \
  --output "${FONT_DIR}/OFL.txt"
test -s "${FONT_DIR}/OFL.txt"

echo "IBM Plex Sans Arabic (Regular, Medium, SemiBold, Bold) downloaded successfully."
